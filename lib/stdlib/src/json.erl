%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2024-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%% % @format
%%
-module(json).
-moduledoc(#{since => "OTP 27.0"}).
-moduledoc """
A library for encoding and decoding JSON.

This module implements [EEP68](https://github.com/erlang/eep/blob/master/eeps/eep-0068.md).

Both encoder and decoder fully conform to
[RFC 8259](https://tools.ietf.org/html/rfc8259) and
[ECMA 404](https://ecma-international.org/publications-and-standards/standards/ecma-404/)
standards. The decoder is tested using [JSONTestSuite](https://github.com/nst/JSONTestSuite).
""".

-dialyzer(no_improper_lists).

-export([
    encode/1, encode/2,
    encode_value/2,
    encode_atom/2,
    encode_integer/1,
    encode_float/1,
    encode_list/2,
    encode_map/2,
    encode_map_checked/2,
    encode_key_value_list/2,
    encode_key_value_list_checked/2,
    encode_binary/1,
    encode_binary_escape_all/1
]).
-export_type([encoder/0, encode_value/0]).

-export([
         format/1, format/2, format/3,
         format_value/3,
         format_key_value_list/3,
         format_key_value_list_checked/3
        ]).
-export_type([formatter/0]).

-export([
    decode/1, decode/3, decode_start/3, decode_continue/2
]).
-export_type([
    from_binary_fun/0,
    array_start_fun/0,
    array_push_fun/0,
    array_finish_fun/0,
    object_start_fun/0,
    object_push_fun/0,
    object_finish_fun/0,
    decoders/0,
    decode_value/0,
    continuation_state/0
]).

-compile(warn_missing_spec).

-compile({inline, [
    encode_atom/2,
    encode_integer/1,
    encode_float/1,
    encode_object/1,
    escape/1,
    escape_binary/1,
    escape_all/1,
    utf8t/0,
    utf8s/0,
    utf8s0/0,
    hex_to_int/4,
    string/6
]}).

-include("json.hrl").
-define(UTF8_ACCEPT, 0).
-define(UTF8_REJECT, 12).

%%
%% Encoding implementation
%%

-type encoder() :: fun((dynamic(), encoder()) -> iodata()).

-doc """
Simple JSON value encodeable with `json:encode/1`.
""".
-type encode_value() ::
    integer()
    | float()
    | boolean()
    | null
    | binary()
    | atom()
    | list(encode_value())
    | encode_map(encode_value()).

-type encode_map(Value) :: #{binary() | atom() | integer() => Value}.

-doc """
Generates JSON corresponding to `Term`.

Supports basic data mapping:

| **Erlang**             | **JSON** |
|------------------------|----------|
| `integer() \| float()` | Number   |
| `true \| false `       | Boolean  |
| `null`                 | Null     |
| `binary()`             | String   |
| `atom()`               | String   |
| `list()`               | Array    |
| `#{binary() => _}`     | Object   |
| `#{atom() => _}`       | Object   |
| `#{integer() => _}`    | Object   |

This is equivalent to `encode(Term, fun json:encode_value/2)`.

## Examples

```erlang
> iolist_to_binary(json:encode(#{foo => <<"bar">>})).
<<"{\"foo\":\"bar\"}">>
```
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode(encode_value()) -> iodata().
encode(Term) -> encode(Term, fun do_encode/2).

-doc """
Generates JSON corresponding to `Term`.

Can be customised with the `Encoder` callback.
The callback will be recursively called for all the data
to be encoded and is expected to return the corresponding
encoded JSON as iodata.

Various `encode_*` functions in this module can be used
to help in constructing such callbacks.

## Examples

An encoder that uses a heuristic to differentiate object-like
lists of key-value pairs from plain lists:

```erlang
> encoder([{_, _} | _] = Value, Encode) -> json:encode_key_value_list(Value, Encode);
> encoder(Other, Encode) -> json:encode_value(Other, Encode).
> custom_encode(Value) -> json:encode(Value, fun(Value, Encode) -> encoder(Value, Encode) end).
> iolist_to_binary(custom_encode([{a, []}, {b, 1}])).
<<"{\"a\":[],\"b\":1}">>
```
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode(dynamic(), encoder()) -> iodata().
encode(Term, Encoder) when is_function(Encoder, 2) ->
    Encoder(Term, Encoder).

-doc """
Default encoder used by `json:encode/1`.

Recursively calls `Encode` on all the values in `Value`.
""".
-spec encode_value(dynamic(), encoder()) -> iodata().
-doc(#{since => <<"OTP 27.0">>}).
encode_value(Value, Encode) ->
    do_encode(Value, Encode).

-spec do_encode(dynamic(), encoder()) -> iodata().
do_encode(Value, Encode) when is_atom(Value) ->
    encode_atom(Value, Encode);
do_encode(Value, _Encode) when is_binary(Value) ->
    escape_binary(Value);
do_encode(Value, _Encode) when is_integer(Value) ->
    encode_integer(Value);
do_encode(Value, _Encode) when is_float(Value) ->
    encode_float(Value);
do_encode(Value, Encode) when is_list(Value) ->
    do_encode_list(Value, Encode);
do_encode(Value, Encode) when is_map(Value) ->
    do_encode_map(Value, Encode);
do_encode(Other, _Encode) ->
    error({unsupported_type, Other}).

-doc """
Default encoder for atoms used by `json:encode/1`.

Encodes the atom `null` as JSON `null`,
atoms `true` and `false` as JSON booleans,
and everything else as JSON strings calling the `Encode`
callback with the corresponding binary.
""".
-spec encode_atom(atom(), encoder()) -> iodata().
-doc(#{since => <<"OTP 27.0">>}).
encode_atom(null, _Encode) -> <<"null">>;
encode_atom(true, _Encode) -> <<"true">>;
encode_atom(false, _Encode) -> <<"false">>;
encode_atom(Other, Encode) -> Encode(atom_to_binary(Other, utf8), Encode).

-doc """
Default encoder for integers as JSON numbers used by `json:encode/1`.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_integer(integer()) -> iodata().
encode_integer(Integer) -> integer_to_binary(Integer).

-doc """
Default encoder for floats as JSON numbers used by `json:encode/1`.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_float(float()) -> iodata().
encode_float(Float) -> float_to_binary(Float, [short]).

-doc """
Default encoder for lists as JSON arrays used by `json:encode/1`.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_list(list(), encoder()) -> iodata().
encode_list(List, Encode) when is_list(List) ->
    do_encode_list(List, Encode).

do_encode_list([], _Encode) ->
    <<"[]">>;
do_encode_list([First | Rest], Encode) when is_function(Encode, 2) ->
    [$[, Encode(First, Encode) | list_loop(Rest, Encode)].

list_loop([], _Encode) -> "]";
list_loop([Elem | Rest], Encode) -> [$,, Encode(Elem, Encode) | list_loop(Rest, Encode)].

-doc """
Default encoder for maps as JSON objects used by `json:encode/1`.

Accepts maps with atom, binary, integer, or float keys.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_map(encode_map(dynamic()), encoder()) -> iodata().
encode_map(Map, Encode) when is_map(Map) ->
    do_encode_map(Map, Encode).

do_encode_map(Map, Encode) when is_function(Encode, 2) ->
    encode_object([[$,, key(Key, Encode), $: | Encode(Value, Encode)] || Key := Value <- Map]).

-doc """
Encoder for maps as JSON objects.

Accepts maps with atom, binary, integer, or float keys.
Verifies that no duplicate keys will be produced in the
resulting JSON object.

## Errors

Raises `error({duplicate_key, Key})` if there are duplicates.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_map_checked(map(), encoder()) -> iodata().
encode_map_checked(Map, Encode) ->
    do_encode_checked(maps:to_list(Map), Encode).

-doc """
Encoder for lists of key-value pairs as JSON objects.

Accepts lists with atom, binary, integer, or float keys.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_key_value_list([{term(), term()}], encoder()) -> iodata().
encode_key_value_list(List, Encode) when is_function(Encode, 2) ->
    encode_object([[$,, key(Key, Encode), $: | Encode(Value, Encode)] || {Key, Value} <- List]).

-doc """
Encoder for lists of key-value pairs as JSON objects.

Accepts lists with atom, binary, integer, or float keys.
Verifies that no duplicate keys will be produced in the
resulting JSON object.

## Errors

Raises `error({duplicate_key, Key})` if there are duplicates.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_key_value_list_checked([{term(), term()}], encoder()) -> iodata().
encode_key_value_list_checked(List, Encode) ->
    do_encode_checked(List, Encode).

do_encode_checked(List, Encode) when is_function(Encode, 2) ->
    encode_object(do_encode_checked(List, Encode, #{})).

do_encode_checked([{Key, Value} | Rest], Encode, Visited0) ->
    EncodedKey = iolist_to_binary(key(Key, Encode)),
    case is_map_key(EncodedKey, Visited0) of
        true ->
            error({duplicate_key, Key});
        _ ->
            Visited = Visited0#{EncodedKey => true},
            [[$,, EncodedKey, $: | Encode(Value, Encode)] | do_encode_checked(Rest, Encode, Visited)]
    end;
do_encode_checked([], _, _) ->
    [].

%% Dispatching any value through `Encode` could allow incorrect
%% JSON to be emitted (with keys not being strings). To avoid this,
%% the default encoder only supports binaries, atoms, and numbers.
%% Customisation is possible by overriding how maps are encoded in general.
key(Key, Encode) when is_binary(Key) -> Encode(Key, Encode);
key(Key, Encode) when is_atom(Key) -> Encode(atom_to_binary(Key, utf8), Encode);
key(Key, _Encode) when is_integer(Key) -> [$", encode_integer(Key), $"];
key(Key, _Encode) when is_float(Key) -> [$", encode_float(Key), $"].

encode_object([]) -> <<"{}">>;
encode_object([[_Comma | Entry] | Rest]) -> [${, Entry, Rest, $}].

-doc """
Default encoder for binaries as JSON strings used by `json:encode/1`.

## Errors

* `error(unexpected_end)` if the binary contains incomplete UTF-8 sequences.
* `error({invalid_byte, Byte})` if the binary contains invalid UTF-8 sequences.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_binary(binary()) -> iodata().
encode_binary(Bin) when is_binary(Bin) ->
    escape_binary(Bin).

-doc """
Encoder for binaries as JSON strings producing pure-ASCII JSON.

For any non-ASCII unicode character, a corresponding `\\uXXXX` sequence is used.

## Errors

* `error(unexpected_end)` if the binary contains incomplete UTF-8 sequences.
* `error({invalid_byte, Byte})` if the binary contains invalid UTF-8 sequences.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec encode_binary_escape_all(binary()) -> iodata().
encode_binary_escape_all(Bin) when is_binary(Bin) ->
    escape_all(Bin).

escape_binary(Bin) -> escape_binary_ascii(Bin, [$"], Bin, 0, 0).

escape_binary_ascii(Binary, Acc, Orig, Skip, Len) ->
    case Binary of
        <<B1, B2, B3, B4, B5, B6, B7, B8, Rest/binary>> when ?are_all_ascii_plain(B1, B2, B3, B4, B5, B6, B7, B8) ->
            escape_binary_ascii(Rest, Acc, Orig, Skip, Len + 8);
        Other ->
            escape_binary(Other, Acc, Orig, Skip, Len)
    end.

escape_binary(<<Byte, Rest/binary>>, Acc, Orig, Skip, Len) when ?is_ascii_plain(Byte) ->
    %% we got here because there were either less than 8 bytes left
    %% or we have an escape in the next 8 bytes,
    %% escape_binary_ascii would fail and dispatch here anyway
    escape_binary(Rest, Acc, Orig, Skip, Len + 1);
escape_binary(<<Byte, Rest/binary>>, Acc, Orig, Skip0, Len) when ?is_ascii_escape(Byte) ->
    Escape = escape(Byte),
    Skip = Skip0 + Len + 1,
    case Len of
        0 ->
            escape_binary_ascii(Rest, [Acc | Escape], Orig, Skip, 0);
        _ ->
            Part = binary_part(Orig, Skip0, Len),
            escape_binary_ascii(Rest, [Acc, Part | Escape], Orig, Skip, 0)
    end;
escape_binary(<<Byte, Rest/binary>>, Acc, Orig, Skip, Len) ->
    case element(Byte - 127, utf8s0()) of
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len);
        %% all accept cases are ASCII, already covered above
        State -> escape_binary_utf8(Rest, Acc, Orig, Skip, Len, State)
    end;
escape_binary(_, _Acc, Orig, 0, _Len) ->
    [$", Orig, $"];
escape_binary(_, Acc, _Orig, _Skip, 0) ->
    [Acc, $"];
escape_binary(_, Acc, Orig, Skip, Len) ->
    Part = binary_part(Orig, Skip, Len),
    [Acc, Part, $"].

escape_binary_utf8(<<Byte, Rest/binary>>, Acc, Orig, Skip, Len, State0) ->
    Type = element(Byte + 1, utf8t()),
    case element(State0 + Type, utf8s()) of
        ?UTF8_ACCEPT -> escape_binary_ascii(Rest, Acc, Orig, Skip, Len + 2);
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len + 1);
        State -> escape_binary_utf8(Rest, Acc, Orig, Skip, Len + 1, State)
    end;
escape_binary_utf8(_, _Acc, Orig, Skip, Len, _State) ->
    unexpected_utf8(Orig, Skip + Len + 1).

escape_all(Bin) -> escape_all_ascii(Bin, [$"], Bin, 0, 0).

escape_all_ascii(Binary, Acc, Orig, Skip, Len) ->
    case Binary of
        <<B1, B2, B3, B4, B5, B6, B7, B8, Rest/binary>> when ?are_all_ascii_plain(B1, B2, B3, B4, B5, B6, B7, B8) ->
            escape_all_ascii(Rest, Acc, Orig, Skip, Len + 8);
        Other ->
            escape_all(Other, Acc, Orig, Skip, Len)
    end.

escape_all(<<Byte, Rest/binary>>, Acc, Orig, Skip, Len) when ?is_ascii_plain(Byte) ->
    escape_all(Rest, Acc, Orig, Skip, Len + 1);
escape_all(<<Byte, Rest/bits>>, Acc, Orig, Skip, Len) when ?is_ascii_escape(Byte) ->
    Escape = escape(Byte),
    case Len of
        0 ->
            escape_all(Rest, [Acc | Escape], Orig, Skip + 1, 0);
        _ ->
            Part = binary_part(Orig, Skip, Len),
            escape_all(Rest, [Acc, Part | Escape], Orig, Skip + Len + 1, 0)
    end;
escape_all(<<Char/utf8, Rest/bits>>, Acc, Orig, Skip, 0) ->
    escape_char(Rest, Acc, Orig, Skip, Char);
escape_all(<<Char/utf8, Rest/bits>>, Acc, Orig, Skip, Len) ->
    Part = binary_part(Orig, Skip, Len),
    escape_char(Rest, [Acc | Part], Orig, Skip + Len, Char);
escape_all(<<>>, _Acc, Orig, 0, _Len) ->
    [$", Orig, $"];
escape_all(<<>>, Acc, _Orig, _Skip, 0) ->
    [Acc, $"];
escape_all(<<>>, Acc, Orig, Skip, Len) ->
    Part = binary_part(Orig, Skip, Len),
    [Acc, Part, $"];
escape_all(_Other, _Acc, Orig, Skip, Len) ->
    invalid_byte(Orig, Skip + Len).

escape_char(<<Rest/bits>>, Acc, Orig, Skip, Char) when Char =< 16#FF ->
    Acc1 = [Acc, "\\u00" | integer_to_binary(Char, 16)],
    escape_all(Rest, Acc1, Orig, Skip + 2, 0);
escape_char(<<Rest/bits>>, Acc, Orig, Skip, Char) when Char =< 16#7FF ->
    Acc1 = [Acc, "\\u0" | integer_to_binary(Char, 16)],
    escape_all(Rest, Acc1, Orig, Skip + 2, 0);
escape_char(<<Rest/bits>>, Acc, Orig, Skip, Char) when Char =< 16#FFF ->
    Acc1 = [Acc, "\\u0" | integer_to_binary(Char, 16)],
    escape_all(Rest, Acc1, Orig, Skip + 3, 0);
escape_char(<<Rest/bits>>, Acc, Orig, Skip, Char) when Char =< 16#FFFF ->
    Acc1 = [Acc, "\\u" | integer_to_binary(Char, 16)],
    escape_all(Rest, Acc1, Orig, Skip + 3, 0);
escape_char(<<Rest/bits>>, Acc, Orig, Skip, Char0) ->
    Char = Char0 - 16#10000,
    First = integer_to_binary(16#800 bor (Char bsr 10), 16),
    Second = integer_to_binary(16#C00 bor (Char band 16#3FF), 16),
    Acc1 = [Acc, "\\uD", First, "\\uD" | Second],
    escape_all(Rest, Acc1, Orig, Skip + 4, 0).

-spec escape(byte()) -> binary() | no.
escape($\x00) -> <<"\\u0000">>;
escape($\x01) -> <<"\\u0001">>;
escape($\x02) -> <<"\\u0002">>;
escape($\x03) -> <<"\\u0003">>;
escape($\x04) -> <<"\\u0004">>;
escape($\x05) -> <<"\\u0005">>;
escape($\x06) -> <<"\\u0006">>;
escape($\x07) -> <<"\\u0007">>;
escape($\b) -> <<"\\b">>;
escape($\t) -> <<"\\t">>;
escape($\n) -> <<"\\n">>;
escape($\x0b) -> <<"\\u000B">>;
escape($\f) -> <<"\\f">>;
escape($\r) -> <<"\\r">>;
escape($\x0e) -> <<"\\u000E">>;
escape($\x0f) -> <<"\\u000F">>;
escape($\x10) -> <<"\\u0010">>;
escape($\x11) -> <<"\\u0011">>;
escape($\x12) -> <<"\\u0012">>;
escape($\x13) -> <<"\\u0013">>;
escape($\x14) -> <<"\\u0014">>;
escape($\x15) -> <<"\\u0015">>;
escape($\x16) -> <<"\\u0016">>;
escape($\x17) -> <<"\\u0017">>;
escape($\x18) -> <<"\\u0018">>;
escape($\x19) -> <<"\\u0019">>;
escape($\x1A) -> <<"\\u001A">>;
escape($\x1B) -> <<"\\u001B">>;
escape($\x1C) -> <<"\\u001C">>;
escape($\x1D) -> <<"\\u001D">>;
escape($\x1E) -> <<"\\u001E">>;
escape($\x1F) -> <<"\\u001F">>;
escape($") -> <<"\\\"">>;
escape($\\) -> <<"\\\\">>;
escape(_) -> no.

%% This is an adapted table from "Flexible and Economical UTF-8 Decoding" by Bjoern Hoehrmann.
%% http://bjoern.hoehrmann.de/utf-8/decoder/dfa/

%% Map character to character class
utf8t() ->
    {
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
       10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8
    }.

%% Transition table mapping combination of state & class to next state
utf8s() ->
    {
           12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
        12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
        12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
        12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
        12,36,12,12,12,12,12,12,12,12,12,12
    }.

%% Optimisation for 1st byte direct state lookup,
%% we know starting state is 0 and ASCII bytes were already handled
utf8s0() ->
    {
        12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
        12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
        12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
        12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
        12,12,24,24,24,24,24,24,24,24,24,24,24,24,24,24,
        24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,
        48,36,36,36,36,36,36,36,36,36,36,36,36,60,36,36,
        72,84,84,84,96,12,12,12,12,12,12,12,12,12,12,12
    }.

invalid_byte(Bin, Skip) ->
    Byte = binary:at(Bin, Skip),
    error({invalid_byte, Byte}, none, error_info(Skip)).

error_info(Skip) ->
    [{error_info, #{cause => #{position => Skip},
                    module => erl_stdlib_errors}}].

%%
%% Format implementation
%%

-type formatter() :: fun((Term :: dynamic(), Encoder :: formatter(), State :: map()) -> iodata()).

-doc """
Generates formatted JSON corresponding to `Term`.

Similiar to `encode/1` but with added whitespaces for formatting.

```erlang
> io:put_chars(json:format(#{foo => <<"bar">>, baz => 52})).
{
  "baz": 52,
  "foo": "bar"
}
ok
```
""".

-doc(#{since => ~"OTP 27.1"}).
-spec format(Term :: encode_value()) -> iodata().
format(Term) ->
    Enc = fun format_value/3,
    format(Term, Enc, #{}).

-doc """
Generates formatted JSON corresponding to `Term`.

Equivalent to `format(Term, fun json:format_value/3, Options)` or `format(Term, Encoder, #{})`
""".
-doc(#{since => ~"OTP 27.1"}).

-spec format(Term :: encode_value(), Opts :: map()) -> iodata();
            (Term :: dynamic(), Encoder::formatter()) -> iodata().
format(Term, Options) when is_map(Options) ->
    Enc = fun format_value/3,
    format(Term, Enc, Options);
format(Term, Encoder) when is_function(Encoder, 3) ->
    format(Term, Encoder, #{}).

-doc """
Generates formatted JSON corresponding to `Term`.

Similar to `encode/2`, can be customised with the `Encoder` callback and `Options`.

`Options` can include 'indent' to specify number of spaces per level and 'max' which loosely limits
the width of lists.

The `Encoder` will get a 'State' argument which contains the 'Options' maps merged with other data
when recursing through 'Term'.

`format_value/3` or various `encode_*` functions in this module can be used
to help in constructing such callbacks.

```erlang
> formatter({posix_time, SysTimeSecs}, Encode, State) ->
    TimeStr = calendar:system_time_to_rfc3339(SysTimeSecs, [{offset, "Z"}]),
    json:format_value(unicode:characters_to_binary(TimeStr), Encode, State);
> formatter(Other, Encode, State) -> json:format_value(Other, Encode, State).
>
> Fun = fun(Value, Encode, State) -> formatter(Value, Encode, State) end.
> Options = #{indent => 4}.
> Term = #{id => 1, time => {posix_time, erlang:system_time(seconds)}}.
>
> io:put_chars(json:format(Term, Fun, Options)).
{
    "id": 1,
    "time": "2024-05-23T16:07:48Z"
}
ok
```
""".
-doc(#{since => ~"OTP 27.1"}).

-spec format(Term :: dynamic(), Encoder::formatter(), Options :: map()) -> iodata().
format(Term, Encoder, Options) when is_function(Encoder, 3) ->
    Def = #{level => 0,
            col => 0,
            indent => 2,
            max => 100
           },
    [Encoder(Term, Encoder, maps:merge(Def, Options)),$\n].

-doc """
Default format function used by `json:format/1`.

Recursively calls `Encode` on all the values in `Value`,
and indents objects and lists.
""".
-doc(#{since => ~"OTP 27.1"}).

-spec format_value(Value::dynamic(), Encode::formatter(), State::map()) -> iodata().
format_value(Atom, UserEnc, State) when is_atom(Atom) ->
    json:encode_atom(Atom, fun(Value, Enc) ->  UserEnc(Value, Enc, State) end);
format_value(Bin, _Enc, _State) when is_binary(Bin) ->
    json:encode_binary(Bin);
format_value(Int, _Enc, _State) when is_integer(Int) ->
    json:encode_integer(Int);
format_value(Float, _Enc, _State) when is_float(Float) ->
    json:encode_float(Float);
format_value(List, UserEnc, State) when is_list(List) ->
    format_list(List, UserEnc, State);
format_value(Map, UserEnc, State) when is_map(Map) ->
    %% Ensure order of maps are the same in each export
    OrderedKV = maps:to_list(maps:iterator(Map, ordered)),
    format_key_value_list(OrderedKV, UserEnc, State);
format_value(Other, _Enc, _State) ->
    error({unsupported_type, Other}).

format_list([Head|Rest], UserEnc, #{level := Level, col := Col0, max := Max} = State0) ->
    State1 = State0#{level := Level+1},
    {Len, IndentElement} = indent(State1),
    if is_list(Head);   %% Indent list in lists
       is_map(Head);    %% Indent maps
       is_binary(Head); %% Indent Strings
       Col0 > Max ->    %% Throw in the towel
            State = State1#{col := Len},
            First = UserEnc(Head, UserEnc, State),
            {_, IndLast} = indent(State0),
            [$[, IndentElement, First,
             format_tail(Rest, UserEnc, State, IndentElement, IndentElement),
             IndLast, $] ];
       true ->
            First = UserEnc(Head, UserEnc, State1),
            Col = Col0 + 1 + erlang:iolist_size(First),
            [$[, First,
             format_tail(Rest, UserEnc, State1#{col := Col}, [], IndentElement),
             $] ]
    end;
format_list([], _, _) ->
    <<"[]">>.

format_tail([Head|Tail], Enc, #{max := Max, col := Col0} = State, [], IndentRow)
  when Col0 < Max ->
    EncHead = Enc(Head, Enc, State),
    String = [$,|EncHead],
    Col = Col0 + 1 + erlang:iolist_size(EncHead),
    [String|format_tail(Tail, Enc, State#{col := Col}, [], IndentRow)];
format_tail([Head|Tail], Enc, State, [], IndentRow) ->
    EncHead = Enc(Head, Enc, State),
    String = [[$,|IndentRow]|EncHead],
    Col = erlang:iolist_size(String)-2,
    [String|format_tail(Tail, Enc, State#{col := Col}, [], IndentRow)];
format_tail([Head|Tail], Enc, State, IndentAll, IndentRow) ->
    %% These are handling their own indentation, so optimize away size calculation
    EncHead = Enc(Head, Enc, State),
    String = [[$,|IndentAll]|EncHead],
    [String|format_tail(Tail, Enc, State, IndentAll, IndentRow)];
format_tail([], _, _, _, _) ->
    [].

-doc """
Format function for lists of key-value pairs as JSON objects.

Accepts lists with atom, binary, integer, or float keys.
""".
-doc(#{since => <<"OTP 27.2">>}).

-spec format_key_value_list([{term(), term()}], Encode::formatter(), State::map()) -> iodata().
format_key_value_list(KVList, UserEnc, #{level := Level} = State) ->
    {_,Indent} = indent(State),
    NextState = State#{level := Level+1},
    {KISize, KeyIndent} = indent(NextState),
    EncKeyFun = fun(KeyVal, _Fun) -> UserEnc(KeyVal, UserEnc, NextState) end,
    EntryFun = fun({Key, Value}) ->
                       EncKey = key(Key, EncKeyFun),
                       ValState = NextState#{col := KISize + 2 + erlang:iolist_size(EncKey)},
                       [$, , KeyIndent, EncKey, ": " | UserEnc(Value, UserEnc, ValState)]
               end,
    format_object(lists:map(EntryFun, KVList), Indent).

-doc """
Format function for lists of key-value pairs as JSON objects.

Accepts lists with atom, binary, integer, or float keys.
Verifies that no duplicate keys will be produced in the
resulting JSON object.

## Errors

Raises `error({duplicate_key, Key})` if there are duplicates.
""".
-doc(#{since => <<"OTP 27.2">>}).

-spec format_key_value_list_checked([{term(), term()}], Encoder::formatter(), State::map()) -> iodata().
format_key_value_list_checked(KVList, UserEnc, State) when is_function(UserEnc, 3) ->
    {_,Indent} = indent(State),
    format_object(do_format_checked(KVList, UserEnc, State), Indent).

do_format_checked([], _, _) ->
    [];

do_format_checked(KVList, UserEnc,  #{level := Level} = State) ->
    NextState = State#{level := Level + 1},
    {KISize, KeyIndent} = indent(NextState),
    EncKeyFun = fun(KeyVal, _Fun) -> UserEnc(KeyVal, UserEnc, NextState) end,
    EncListFun =
        fun({Key, Value}, {Acc, Visited0}) ->
                EncKey = iolist_to_binary(key(Key, EncKeyFun)),
                case is_map_key(EncKey, Visited0) of
                    true ->
                        error({duplicate_key, Key});
                    false ->
                        Visited1 = Visited0#{EncKey => true},
                        ValState = NextState#{col := KISize + 2 + erlang:iolist_size(EncKey)},
                        EncEntry = [$, , KeyIndent, EncKey, ": "
                                   | UserEnc(Value, UserEnc, ValState)],
                        {[EncEntry | Acc], Visited1}
                end
        end,
    {EncKVList, _} = lists:foldl(EncListFun, {[], #{}}, KVList),
    lists:reverse(EncKVList).

format_object([], _) -> <<"{}">>;
format_object([[_Comma,KeyIndent|Entry]], Indent) ->
    [_Key,_Colon|Value] = Entry,
    {_, Rest} = string:take(Value, [$\s,$\n]),
    [CP|_] = string:next_codepoint(Rest),
    if CP =:= ${ ->
            [${, KeyIndent, Entry, Indent, $}];
       CP =:= $[ ->
            [${, KeyIndent, Entry, Indent, $}];
       true ->
            ["{ ", Entry, " }"]
    end;
format_object([[_Comma,KeyIndent|Entry] | Rest], Indent) ->
    [${, KeyIndent, Entry, Rest, Indent, $}].

indent(#{level := Level, indent := Indent}) ->
    Steps = Level * Indent,
    {Steps, steps(Steps)}.

steps(0)  -> ~"\n";
steps(2)  -> ~"\n  ";
steps(4)  -> ~"\n    ";
steps(6)  -> ~"\n      ";
steps(8)  -> ~"\n        ";
steps(10) -> ~"\n          ";
steps(12) -> ~"\n            ";
steps(14) -> ~"\n              ";
steps(16) -> ~"\n                ";
steps(18) -> ~"\n                  ";
steps(20) -> ~"\n                    ";
steps(N) ->  ["\n", lists:duplicate(N, " ")].

%%
%% Decoding implementation
%%

-define(ARRAY, array).
-define(OBJECT, object).

-type from_binary_fun() :: fun((binary()) -> dynamic()).
-type array_start_fun() :: fun((Acc :: dynamic()) -> ArrayAcc :: dynamic()).
-type array_push_fun() :: fun((Value :: dynamic(), Acc :: dynamic()) -> NewAcc :: dynamic()).
-type array_finish_fun() :: fun((ArrayAcc :: dynamic(), OldAcc :: dynamic()) -> {dynamic(), dynamic()}).
-type object_start_fun() :: fun((Acc :: dynamic()) -> ObjectAcc :: dynamic()).
-type object_push_fun() :: fun((Key :: dynamic(), Value :: dynamic(), Acc :: dynamic()) -> NewAcc :: dynamic()).
-type object_finish_fun() :: fun((ObjectAcc :: dynamic(), OldAcc :: dynamic()) -> {dynamic(), dynamic()}).

-type decoders() :: #{
    array_start => array_start_fun(),
    array_push => array_push_fun(),
    array_finish => array_finish_fun(),
    object_start => object_start_fun(),
    object_push => object_push_fun(),
    object_finish => object_finish_fun(),
    float => from_binary_fun(),
    integer => from_binary_fun(),
    string => from_binary_fun(),
    null => term()
}.

-record(decode, {
    array_start :: array_start_fun() | undefined,
    array_push :: array_push_fun() | undefined,
    array_finish :: array_finish_fun() | undefined,
    object_start :: object_start_fun() | undefined,
    object_push :: object_push_fun() | undefined,
    object_finish :: object_finish_fun() | undefined,
    float = fun erlang:binary_to_float/1 :: from_binary_fun(),
    integer = fun erlang:binary_to_integer/1 :: from_binary_fun(),
    string :: from_binary_fun() | undefined,
    null = null :: term()
}).

-type acc() :: dynamic().
-type stack() :: [?ARRAY | ?OBJECT | binary() | acc()].
-type decode() :: #decode{}.

-opaque continuation_state() :: tuple().

-type decode_value() ::
    integer()
    | float()
    | boolean()
    | null
    | binary()
    | list(decode_value())
    | #{binary() => decode_value()}.

-doc """
Parses a JSON value from `Binary`.

Supports basic data mapping:

| **JSON** | **Erlang**             |
|----------|------------------------|
| Number   | `integer() \| float()` |
| Boolean  | `true \| false`        |
| Null     | `null`                 |
| String   | `binary()`             |
| Object   | `#{binary() => _}`     |

## Errors

* `error(unexpected_end)` if `Binary` contains incomplete JSON value
* `error({invalid_byte, Byte})` if `Binary` contains unexpected byte or invalid UTF-8 byte
* `error({unexpected_sequence, Bytes})` if `Binary` contains invalid UTF-8 escape

## Example

```erlang
> json:decode(<<"{\"foo\": 1}">>).
#{<<"foo">> => 1}
```
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec decode(binary()) -> decode_value().
decode(Binary) when is_binary(Binary) ->
    case value(Binary, Binary, 0, ok, [], #decode{}) of
        {Result, _Acc, <<>>} ->
            Result;
        {_, _, Rest} ->
            invalid_byte(Rest, 0);
        {continue, {_Bin, _Acc, [], _Decode, {number, Number}}} ->
            Number;
        {continue, {_, _, _, _, {float_error, Token, Skip}}} ->
            unexpected_sequence(Token, Skip);
        {continue, _} ->
            error(unexpected_end)
    end.

-doc """
Parses a JSON value from `Binary`.

Similar to `decode/1` except the decoding process
can be customized with the callbacks specified in
`Decoders`. The callbacks will use the `Acc` value
as the initial accumulator.

Any leftover, unparsed data in `Binary` will be returned.

## Default callbacks

All callbacks are optional. If not provided, they will fall back to
implementations used by the `decode/1` function:

* for `array_start`: `fun(_) -> [] end`
* for `array_push`: `fun(Elem, Acc) -> [Elem | Acc] end`
* for `array_finish`: `fun(Acc, OldAcc) -> {lists:reverse(Acc), OldAcc} end`
* for `object_start`: `fun(_) -> [] end`
* for `object_push`: `fun(Key, Value, Acc) -> [{Key, Value} | Acc] end`
* for `object_finish`: `fun(Acc, OldAcc) -> {maps:from_list(Acc), OldAcc} end`
* for `float`: `fun erlang:binary_to_float/1`
* for `integer`: `fun erlang:binary_to_integer/1`
* for `string`: `fun (Value) -> Value end`
* for `null`: the atom `null`

## Errors

* `error({invalid_byte, Byte})` if `Binary` contains unexpected byte or invalid UTF-8 byte
* `error({unexpected_sequence, Bytes})` if `Binary` contains invalid UTF-8 escape
* `error(unexpected_end)` if `Binary` contains incomplete JSON value

## Example

Decoding object keys as atoms:

```erlang
> Push = fun(Key, Value, Acc) -> [{binary_to_existing_atom(Key), Value} | Acc] end.
> json:decode(<<"{\"foo\": 1}">>, ok, #{object_push => Push}).
{#{foo => 1},ok,<<>>}
```
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec decode(binary(), dynamic(), decoders()) ->
          {Result :: dynamic(), Acc :: dynamic(), binary()}.
decode(Binary, Acc0, Decoders) when is_binary(Binary) ->
    Decode = maps:fold(fun parse_decoder/3, #decode{}, Decoders),
    case value(Binary, Binary, 0, Acc0, [], Decode) of
        {continue, {_Bin, Acc, [], _Decode, {number, Val}}} ->
            {Val, Acc, <<>>};
        {continue, {_, _, _, _, {float_error, Token, Skip}}} ->
            unexpected_sequence(Token, Skip);
        {continue, _} ->
            error(unexpected_end);
        Result ->
            Result
    end.

-doc """
Begin parsing a stream of bytes of a JSON value.

Similar to `decode/3` but returns when a complete JSON value can be parsed or
returns `{continue, State}` for incomplete data,
the `State` can be fed to the `decode_continue/2` function when more data is available.
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec decode_start(binary(), dynamic(), decoders()) ->
          {Result :: dynamic(), Acc :: dynamic(), binary()} | {continue, continuation_state()}.
decode_start(Binary, Acc, Decoders) when is_binary(Binary) ->
    Decode = maps:fold(fun parse_decoder/3, #decode{}, Decoders),
    value(Binary, Binary, 0, Acc, [], Decode).

-doc """
Continue parsing a stream of bytes of a JSON value.

Similar to `decode_start/3`, if the function returns `{continue, State}` and
there is no more data, use `end_of_input` instead of a binary.

```erlang
> {continue, State} = json:decode_start(<<"{\"foo\":">>, ok, #{}).
> json:decode_continue(<<"1}">>, State).
{#{foo => 1},ok,<<>>}
```
```erlang
> {continue, State} = json:decode_start(<<"123">>, ok, #{}).
> json:decode_continue(end_of_input, State).
{123,ok,<<>>}
```
""".
-doc(#{since => <<"OTP 27.0">>}).
-spec decode_continue(binary() | end_of_input, Opaque::term()) ->
          {Result :: dynamic(), Acc :: dynamic(), binary()} | {continue, continuation_state()}.
decode_continue(end_of_input, State) ->
    case State of
        {_, Acc, [], _Decode, {number, Val}} ->
            {Val, Acc, <<>>};
        {_, _, _, _, {float_error, Token, Skip}} ->
            unexpected_sequence(Token, Skip);
        _ ->
            error(unexpected_end)
    end;
decode_continue(Cont, {Rest, Acc, Stack, #decode{} = Decode, FuncData}) when is_binary(Cont) ->
    Binary = <<Rest/binary, Cont/binary>>,
    case FuncData of
        value ->
            value(Binary, Binary, 0, Acc, Stack, Decode);
        {number, _} ->
            value(Binary, Binary, 0, Acc, Stack, Decode);
        {float_error, _Token, _Skip} ->
            value(Binary, Binary, 0, Acc, Stack, Decode);
        {array_push, Val} ->
            array_push(Binary, Binary, 0, Acc, Stack, Decode, Val);
        {object_value, Key} ->
            object_value(Binary, Binary, 0, Acc, Stack, Decode, Key);
        {object_push, Value, Key} ->
            object_push(Binary, Binary, 0, Acc, Stack, Decode, Value, Key);
        object_key ->
            object_key(Binary, Binary, 0, Acc, Stack, Decode)
    end.

parse_decoder(array_start, Fun, Decode) when is_function(Fun, 1) ->
    Decode#decode{array_start = Fun};
parse_decoder(array_push, Fun, Decode) when is_function(Fun, 2) ->
    Decode#decode{array_push = Fun};
parse_decoder(array_finish, Fun, Decode) when is_function(Fun, 2) ->
    Decode#decode{array_finish = Fun};
parse_decoder(object_start, Fun, Decode) when is_function(Fun, 1) ->
    Decode#decode{object_start = Fun};
parse_decoder(object_push, Fun, Decode) when is_function(Fun, 3) ->
    Decode#decode{object_push = Fun};
parse_decoder(object_finish, Fun, Decode) when is_function(Fun, 2) ->
    Decode#decode{object_finish = Fun};
parse_decoder(float, Fun, Decode) when is_function(Fun, 1) ->
    Decode#decode{float = Fun};
parse_decoder(integer, Fun, Decode) when is_function(Fun, 1) ->
    Decode#decode{integer = Fun};
parse_decoder(string, Fun, Decode) when is_function(Fun, 1) ->
    Decode#decode{string = Fun};
parse_decoder(null, Null, Decode) ->
    Decode#decode{null = Null}.

value(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode) when ?is_ws(Byte) ->
    value(Rest, Original, Skip + 1, Acc, Stack, Decode);
value(<<$0, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    number_zero(Rest, Original, Skip, Acc, Stack, Decode, 1);
value(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode) when ?is_1_to_9(Byte) ->
    number(Rest, Original, Skip, Acc, Stack, Decode, 1);
value(<<$-, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    number_minus(Rest, Original, Skip, Acc, Stack, Decode);
value(<<$t, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    true(Rest, Original, Skip, Acc, Stack, Decode);
value(<<$f, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    false(Rest, Original, Skip, Acc, Stack, Decode);
value(<<$n, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    null(Rest, Original, Skip, Acc, Stack, Decode);
value(<<$", Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    string(Rest, Original, Skip + 1, Acc, Stack, Decode);
value(<<$[, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    array_start(Rest, Original, Skip, Acc, Stack, Decode, 1);
value(<<${, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    object_start(Rest, Original, Skip, Acc, Stack, Decode, 1);
value(<<Byte, _/bits>>, Original, Skip, _Acc, _Stack, _Decode) when ?is_ascii_plain(Byte) ->
    %% this clause is effecively the same as the last one, but necessary to
    %% force compiler to emit a jump table dispatch, rather than binary search
    invalid_byte(Original, Skip);
value(_, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 0, 0, value).

true(<<"rue", Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    continue(Rest, Original, Skip+4, Acc, Stack, Decode, true);
true(_Rest, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 1, 3, value).

false(<<"alse", Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    continue(Rest, Original, Skip+5, Acc, Stack, Decode, false);
false(_Rest, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 1, 4, value).

null(<<"ull", Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    continue(Rest, Original, Skip+4, Acc, Stack, Decode, Decode#decode.null);
null(_Rest, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 1, 3, value).

number_minus(<<$0, Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    number_zero(Rest, Original, Skip, Acc, Stack, Decode, 2);
number_minus(<<Num, Rest/bits>>, Original, Skip, Acc, Stack, Decode) when ?is_1_to_9(Num) ->
    number(Rest, Original, Skip, Acc, Stack, Decode, 2);
number_minus(_Rest, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 1, 0, value).

number_zero(<<$., Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) ->
    number_frac(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_zero(<<E, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when E =:= $E; E =:= $e ->
    number_exp_copy(Rest, Original, Skip, Acc, Stack, Decode, Len + 1, <<"0">>);
number_zero(<<>>, Original, Skip, Acc, Stack, Decode, Len) ->
    Value = (Decode#decode.integer)(<<"0">>),
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, {number, Value});
number_zero(Rest, Original, Skip, Acc, Stack, Decode, Len) ->
    Value = (Decode#decode.integer)(<<"0">>),
    continue(Rest, Original, Skip+Len, Acc, Stack, Decode, Value).

number(<<Num, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Num) ->
    number(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number(<<$., Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) ->
    number_frac(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number(<<E, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when E =:= $E; E =:= $e ->
    Prefix = binary_part(Original, Skip, Len),
    number_exp_copy(Rest, Original, Skip, Acc, Stack, Decode, Len + 1, Prefix);
number(<<>>, Original, Skip, Acc, Stack, Decode, Len) ->
    Int = (Decode#decode.integer)(binary_part(Original, Skip, Len)),
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, {number, Int});
number(Rest, Original, Skip, Acc, Stack, Decode, Len) ->
    Int = (Decode#decode.integer)(binary_part(Original, Skip, Len)),
    continue(Rest, Original, Skip+Len, Acc, Stack, Decode, Int).

number_frac(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Byte) ->
    number_frac_cont(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_frac(_, Original, Skip, Acc, Stack, Decode, Len) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value).

number_frac_cont(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Byte) ->
    number_frac_cont(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_frac_cont(<<E, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when E =:= $e; E =:= $E ->
    number_exp(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_frac_cont(Rest, Original, Skip, Acc, Stack, Decode, Len) ->
    Token = binary_part(Original, Skip, Len),
    float_decode(Rest, Original, Skip, Acc, Stack, Decode, Len, Token).

float_decode(<<>>, Original, Skip, Acc, Stack, Decode, Len, Token) ->
    try (Decode#decode.float)(Token) of
        Float -> unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, {number, Float})
    catch
        _:_ -> unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, {float_error, Token, Skip})
    end;
float_decode(<<Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len, Token) ->
    try (Decode#decode.float)(Token) of
        Float ->
            continue(Rest, Original, Skip+Len, Acc, Stack, Decode, Float)
    catch
        _:_ -> unexpected_sequence(Token, Skip)
    end.

number_exp(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_exp(<<Sign, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when Sign =:= $+; Sign =:= $- ->
    number_exp_sign(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_exp(_, Original, Skip, Acc, Stack, Decode, Len) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value).

number_exp_sign(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_exp_sign(_, Original, Skip, Acc, Stack, Decode, Len) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value).

number_exp_cont(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len + 1);
number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len) ->
    Token = binary_part(Original, Skip, Len),
    float_decode(Rest, Original, Skip, Acc, Stack, Decode, Len, Token).

number_exp_copy(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len, Prefix) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len, Prefix, 1);
number_exp_copy(<<Sign, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len, Prefix) when Sign =:= $+; Sign =:= $- ->
    number_exp_sign(Rest, Original, Skip, Acc, Stack, Decode, Len, Prefix, 1);
number_exp_copy(_, Original, Skip, Acc, Stack, Decode, Len, _Prefix) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value).

number_exp_sign(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len, Prefix, ExpLen) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len, Prefix, ExpLen + 1);
number_exp_sign(_, Original, Skip, Acc, Stack, Decode, Len, _Prefix, ExpLen) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len + ExpLen, 0, value).

number_exp_cont(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len, Prefix, ExpLen) when ?is_0_to_9(Byte) ->
    number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len, Prefix, ExpLen + 1);
number_exp_cont(Rest, Original, Skip, Acc, Stack, Decode, Len, Prefix, ExpLen) ->
    Suffix = binary_part(Original, Skip + Len, ExpLen),
    Token = <<Prefix/binary, ".0e", Suffix/binary>>,
    float_decode(Rest, Original, Skip, Acc, Stack, Decode, Len + ExpLen, Token).

string(Binary, Original, Skip, Acc, Stack, Decode) ->
    string_ascii(Binary, Original, Skip, Acc, Stack, Decode, 0).

string_ascii(Binary, Original, Skip, Acc, Stack, Decode, Len) ->
    case Binary of
        <<B1, B2, B3, B4, B5, B6, B7, B8, Rest/binary>> when ?are_all_ascii_plain(B1, B2, B3, B4, B5, B6, B7, B8) ->
            string_ascii(Rest, Original, Skip, Acc, Stack, Decode, Len + 8);
        Other ->
            string(Other, Original, Skip, Acc, Stack, Decode, Len)
    end.

-spec string(binary(), binary(), integer(), acc(), stack(), decode(), integer()) -> dynamic().
string(<<Byte, Rest/bits>>, Orig, Skip, Acc, Stack, Decode, Len) when ?is_ascii_plain(Byte) ->
    string(Rest, Orig, Skip, Acc, Stack, Decode, Len + 1);
string(<<$\\, Rest/bits>>, Orig, Skip, Acc, Stack, Decode, Len) ->
    Part = binary_part(Orig, Skip, Len),
    SAcc = <<>>,
    unescape(Rest, Orig, Skip, Acc, Stack, Decode, Skip-1, Len, <<SAcc/binary, Part/binary>>);
string(<<$", Rest/bits>>, Orig, Skip0, Acc, Stack, Decode, Len) ->
    Value = binary_part(Orig, Skip0, Len),
    Skip = Skip0 + Len + 1,
    case Decode#decode.string of
        undefined -> continue(Rest, Orig, Skip, Acc, Stack, Decode, Value);
        Fun -> continue(Rest, Orig, Skip, Acc, Stack, Decode, Fun(Value))
    end;
string(<<Byte, _/bits>>, Orig, Skip, _Acc, _Stack, _Decode, Len) when ?is_ascii_escape(Byte) ->
    invalid_byte(Orig, Skip + Len);
string(<<Byte, Rest/bytes>>, Orig, Skip, Acc, Stack, Decode, Len) ->
    case element(Byte - 127, utf8s0()) of
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len);
        %% all accept cases are ASCII, already covered above
        State -> string_utf8(Rest, Orig, Skip, Acc, Stack, Decode, Len, State)
    end;
string(_, Orig, Skip, Acc, Stack, Decode, Len) ->
    unexpected(Orig, Skip-1, Acc, Stack, Decode, Len + 1, 0, value).

string_utf8(<<Byte, Rest/binary>>, Orig, Skip, Acc, Stack, Decode, Len, State0) ->
    Type = element(Byte + 1, utf8t()),
    case element(State0 + Type, utf8s()) of
        ?UTF8_ACCEPT -> string_ascii(Rest, Orig, Skip, Acc, Stack, Decode, Len + 2);
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len + 1);
        State -> string_utf8(Rest, Orig, Skip, Acc, Stack, Decode, Len + 1, State)
    end;
string_utf8(_, Orig, Skip, Acc, Stack, Decode, Len, _State0) ->
    unexpected(Orig, Skip-1, Acc, Stack, Decode, Len + 2, 0, value).

string_ascii(Binary, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc) ->
    case Binary of
        <<B1, B2, B3, B4, B5, B6, B7, B8, Rest/binary>> when ?are_all_ascii_plain(B1, B2, B3, B4, B5, B6, B7, B8) ->
            string_ascii(Rest, Original, Skip, Acc, Stack, Decode, Start, Len + 8, SAcc);
        Other ->
            string(Other, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc)
    end.

-spec string(binary(), binary(), integer(), acc(), stack(), decode(), integer(), integer(), binary()) -> dynamic().
string(<<Byte, Rest/bits>>, Orig, Skip, Acc, Stack, Decode, Start, Len, SAcc) when ?is_ascii_plain(Byte) ->
    string(Rest, Orig, Skip, Acc, Stack, Decode, Start, Len + 1, SAcc);
string(<<$\\, Rest/bits>>, Orig, Skip, Acc, Stack, Decode, Start, Len, SAcc) ->
    Part = binary_part(Orig, Skip, Len),
    unescape(Rest, Orig, Skip, Acc, Stack, Decode, Start, Len, <<SAcc/binary, Part/binary>>);
string(<<$", Rest/bits>>, Orig, Skip0, Acc, Stack, Decode, _Start, Len, SAcc) ->
    Part = binary_part(Orig, Skip0, Len),
    Value = <<SAcc/binary, Part/binary>>,
    Skip = Skip0 + Len + 1,
    case Decode#decode.string of
        undefined -> continue(Rest, Orig, Skip, Acc, Stack, Decode, Value);
        Fun -> continue(Rest, Orig, Skip, Acc, Stack, Decode, Fun(Value))
    end;
string(<<Byte, _/bits>>, Orig, Skip, _Acc, _Stack, _Decode, _Start, Len, _SAcc) when ?is_ascii_escape(Byte) ->
    invalid_byte(Orig, Skip + Len);
string(<<Byte, Rest/bytes>>, Orig, Skip, Acc, Stack, Decode, Start, Len, SAcc) ->
    case element(Byte - 127, utf8s0()) of
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len);
        %% all accept cases are ASCII, already covered above
        State -> string_utf8(Rest, Orig, Skip, Acc, Stack, Decode, Start, Len, SAcc, State)
    end;
string(_, Orig, Skip, Acc, Stack, Decode, Start, Len, _SAcc) ->
    Extra = Skip - Start,
    unexpected(Orig, Start, Acc, Stack, Decode, Len+Extra, 0, value).

string_utf8(<<Byte, Rest/binary>>, Orig, Skip, Acc, Stack, Decode, Start, Len, SAcc, State0) ->
    Type = element(Byte + 1, utf8t()),
    case element(State0 + Type, utf8s()) of
        ?UTF8_ACCEPT -> string_ascii(Rest, Orig, Skip, Acc, Stack, Decode, Start, Len + 2, SAcc);
        ?UTF8_REJECT -> invalid_byte(Orig, Skip + Len + 1);
        State -> string_utf8(Rest, Orig, Skip, Acc, Stack, Decode, Start, Len + 1, SAcc, State)
    end;
string_utf8(_, Orig, Skip, Acc, Stack, Decode, Start, Len, _SAcc, _State0) ->
    Extra = Skip - Start,
    unexpected(Orig, Start, Acc, Stack, Decode, Len + 1 + Extra, 0, value).

unescape(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc) ->
    Val =
        case Byte of
            $b -> $\b;
            $f -> $\f;
            $n -> $\n;
            $r -> $\r;
            $t -> $\t;
            $" -> $";
            $\\ -> $\\;
            $/ -> $/;
            $u -> unicode;
            _ -> error
        end,
    case Val of
        unicode -> unescapeu(Rest, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc);
        error -> invalid_byte(Original, Skip+Len+1);
        Int -> string_ascii(Rest, Original, Skip + Len + 2, Acc, Stack, Decode, Start, 0, <<SAcc/binary, Int>>)
    end;
unescape(_, Original, Skip, Acc, Stack, Decode, Start, Len, _SAcc) ->
    Extra = Skip - Start,
    unexpected(Original, Start, Acc, Stack, Decode, Len + 1 + Extra, 0, value).

unescapeu(<<E1, E2, E3, E4, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc) ->
    try hex_to_int(E1, E2, E3, E4) of
        CP when CP >= 16#D800, CP =< 16#DBFF ->
            unescape_surrogate(Rest, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc, CP);
        CP ->
            try <<SAcc/binary, CP/utf8>> of
                SAcc1 -> string_ascii(Rest, Original, Skip + Len + 6, Acc, Stack, Decode, Start, 0, SAcc1)
            catch
                _:_ -> unexpected_sequence(binary_part(Original, Skip + Len, 6), Skip + Len)
            end
    catch
        _:_ ->
            unexpected_sequence(binary_part(Original, Skip + Len, 6), Skip + Len)
    end;
unescapeu(_Rest, Original, Skip, Acc, Stack, Decode, Start, Len, _SAcc) ->
    Extra = Skip - Start,
    unexpected(Original, Start, Acc, Stack, Decode, Len + 2 + Extra, 4, value).

unescape_surrogate(<<"\\u", E1, E2, E3, E4, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Start, Len, SAcc, Hi) ->
    try hex_to_int(E1, E2, E3, E4) of
        Lo when Lo >= 16#DC00, Lo =< 16#DFFF ->
            CP = 16#10000 + ((Hi band 16#3FF) bsl 10) + (Lo band 16#3FF),
            try <<SAcc/binary, CP/utf8>> of
                SAcc1 -> string_ascii(Rest, Original, Skip + Len + 12, Acc, Stack, Decode, Start, 0, SAcc1)
            catch
                _:_ -> unexpected_sequence(binary_part(Original, Skip + Len, 12), Skip + Len)
            end;
        _ ->
            unexpected_sequence(binary_part(Original, Skip + Len, 12), Skip + Len)
    catch
        _:_ -> unexpected_sequence(binary_part(Original, Skip + Len, 12), Skip + Len)
    end;
unescape_surrogate(_Rest, Original, Skip, Acc, Stack, Decode, Start, Len, _SAcc, _Hi) ->
    Extra = Skip - Start,
    unexpected(Original, Start, Acc, Stack, Decode, Len + 6 + Extra, 5, value).

%% erlfmt-ignore
%% this is a macro instead of an inlined function - compiler refused to inline
-define(hex_digit(C), element(C - $0 + 1, {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, n, n, n, n, n, %% 0x30
    n, n, 10,11,12,13,14,15,n, n, n, n, n, n, n, %% 0x40
    n, n, n, n, n, n, n, n, n, n, n, n, n, n, n, %% 0x50
    n, n, n, n, 10,11,12,13,14,15                %% 0x60
})).

-spec hex_to_int(byte(), byte(), byte(), byte()) -> integer().
hex_to_int(H1, H2, H3, H4) ->
    ?hex_digit(H4) + 16 * (?hex_digit(H3) + 16 * (?hex_digit(H2) + 16 * ?hex_digit(H1))).

array_start(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_ws(Byte) ->
    array_start(Rest, Original, Skip, Acc, Stack, Decode, Len+1);
array_start(<<"]", Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) ->
    {Value, NewAcc} =
        case {Decode#decode.array_start, Decode#decode.array_finish} of
            {undefined, undefined} -> {[], Acc};
            {Start, undefined} -> {lists:reverse(Start(Acc)), Acc};
            {undefined, Finish} -> Finish([], Acc);
            {Start, Finish} -> Finish(Start(Acc), Acc)
        end,
    continue(Rest, Original, Skip+Len+1, NewAcc, Stack, Decode, Value);
array_start(<<>>, Original, Skip, Acc, Stack, Decode, Len) ->
    %% Handles empty array [] in continuation mode
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value);
array_start(Rest, Original, Skip, OldAcc, Stack, Decode, Len) ->
    case Decode#decode.array_start of
        undefined -> value(Rest, Original, Skip+Len, [], [?ARRAY, OldAcc | Stack], Decode);
        Fun -> value(Rest, Original, Skip+Len, Fun(OldAcc), [?ARRAY, OldAcc | Stack], Decode)
    end.

array_push(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Value) when ?is_ws(Byte) ->
    array_push(Rest, Original, Skip + 1, Acc, Stack, Decode, Value);
array_push(<<"]", Rest/bits>>, Original, Skip, Acc0, Stack0, Decode, Value) ->
    Acc =
        case Decode#decode.array_push of
            undefined -> [Value | Acc0];
            Push -> Push(Value, Acc0)
        end,
    [_, OldAcc | Stack] = Stack0,
    {ArrayValue, NewAcc} =
        case Decode#decode.array_finish of
            undefined -> {lists:reverse(Acc), OldAcc};
            Finish -> Finish(Acc, OldAcc)
        end,
    continue(Rest, Original, Skip + 1, NewAcc, Stack, Decode, ArrayValue);
array_push(<<$,, Rest/bits>>, Original, Skip0, Acc, Stack, Decode, Value) ->
    Skip = Skip0 + 1,
    case Decode#decode.array_push of
        undefined -> value(Rest, Original, Skip, [Value | Acc], Stack, Decode);
        Fun -> value(Rest, Original, Skip, Fun(Value, Acc), Stack, Decode)
    end;
array_push(_, Original, Skip, Acc, Stack, Decode, Value) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 0, 0, {?FUNCTION_NAME, Value}).


object_start(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) when ?is_ws(Byte) ->
    object_start(Rest, Original, Skip, Acc, Stack, Decode, Len+1);
object_start(<<"}", Rest/bits>>, Original, Skip, Acc, Stack, Decode, Len) ->
    {Value, NewAcc} =
        case {Decode#decode.object_start, Decode#decode.object_finish} of
            {undefined, undefined} -> {#{}, Acc};
            {Start, undefined} -> {maps:from_list(Start(Acc)), Acc};
            {undefined, Finish} -> Finish([], Acc);
            {Start, Finish} -> Finish(Start(Acc), Acc)
        end,
    continue(Rest, Original, Skip+Len+1, NewAcc, Stack, Decode, Value);
object_start(<<$", Rest/bits>>, Original, Skip0, OldAcc, Stack0, Decode, Len) ->
    Stack = [?OBJECT, OldAcc | Stack0],
    Skip = Skip0 + Len + 1,
    case Decode#decode.object_start of
        undefined ->
            string(Rest, Original, Skip, [], Stack, Decode);
        Fun ->
            Acc = Fun(OldAcc),
            string(Rest, Original, Skip, Acc, Stack, Decode)
    end;
object_start(_, Original, Skip, Acc, Stack, Decode, Len) ->
    unexpected(Original, Skip, Acc, Stack, Decode, Len, 0, value).

object_value(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Key) when ?is_ws(Byte) ->
    object_value(Rest, Original, Skip + 1, Acc, Stack, Decode, Key);
object_value(<<$:, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Key) ->
    value(Rest, Original, Skip + 1, Acc, [Key | Stack], Decode);
object_value(_, Original, Skip, Acc, Stack, Decode, Key) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 0, 0, {?FUNCTION_NAME, Key}).

object_push(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode, Value, Key) when ?is_ws(Byte) ->
    object_push(Rest, Original, Skip + 1, Acc, Stack, Decode, Value, Key);
object_push(<<"}", Rest/bits>>, Original, Skip, Acc0, Stack0, Decode, Value, Key) ->
    Acc =
        case Decode#decode.object_push of
            undefined -> [{Key, Value} | Acc0];
            Fun -> Fun(Key, Value, Acc0)
        end,
    [_, OldAcc | Stack] = Stack0,
    {ObjectValue, NewAcc} =
        case Decode#decode.object_finish of
            undefined -> {maps:from_list(Acc), OldAcc};
            Finish -> Finish(Acc, OldAcc)
        end,
    continue(Rest, Original, Skip + 1, NewAcc, Stack, Decode, ObjectValue);
object_push(<<$,, Rest/bits>>, Original, Skip, Acc0, Stack, Decode, Value, Key) ->
    case Decode#decode.object_push of
        undefined -> object_key(Rest, Original, Skip + 1, [{Key, Value} | Acc0], Stack, Decode);
        Fun -> object_key(Rest, Original, Skip + 1, Fun(Key, Value, Acc0), Stack, Decode)
    end;
object_push(_, Original, Skip, Acc, Stack, Decode, Value, Key) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 0, 0, {?FUNCTION_NAME, Value, Key}).

object_key(<<Byte, Rest/bits>>, Original, Skip, Acc, Stack, Decode) when ?is_ws(Byte) ->
    object_key(Rest, Original, Skip + 1, Acc, Stack, Decode);
object_key(<<$", Rest/bits>>, Original, Skip, Acc, Stack, Decode) ->
    string(Rest, Original, Skip + 1, Acc, Stack, Decode);
object_key(_, Original, Skip, Acc, Stack, Decode) ->
    unexpected(Original, Skip, Acc, Stack, Decode, 0, 0, ?FUNCTION_NAME).

continue(<<Rest/bits>>, Original, Skip, Acc, Stack0, Decode, Value) ->
    case Stack0 of
        [] -> terminate(Rest, Original, Skip, Acc, Value);
        [?ARRAY | _] -> array_push(Rest, Original, Skip, Acc, Stack0, Decode, Value);
        [?OBJECT | _] -> object_value(Rest, Original, Skip, Acc, Stack0, Decode, Value);
        [Key | Stack] -> object_push(Rest, Original, Skip, Acc, Stack, Decode, Value, Key)
    end.

terminate(<<Byte, Rest/bits>>, Original, Skip, Acc, Value) when ?is_ws(Byte) ->
    terminate(Rest, Original, Skip, Acc, Value);
terminate(<<>>, _, _Skip, Acc, Value) ->
    {Value, Acc, <<>>};
terminate(<<_/bits>>, Original, Skip, Acc, Value) ->
    <<_:Skip/binary, Rest/binary>> = Original,
    {Value, Acc, Rest}.

-spec unexpected_utf8(binary(), non_neg_integer()) -> no_return().
unexpected_utf8(Original, Skip) when byte_size(Original) =:= Skip ->
    error(unexpected_end);
unexpected_utf8(Original, Skip) ->
    invalid_byte(Original, Skip).

unexpected(Original, Skip, Acc, Stack, Decode, Pos, Len, FuncData) ->
    RequiredSize = Skip+Pos+Len,
    OrigSize = byte_size(Original),
    case OrigSize =< RequiredSize of
        true ->
            <<_:Skip/binary, Rest/binary>> = Original,
            {continue, {Rest, Acc, Stack, Decode, FuncData}};
        false ->
            invalid_byte(Original, Skip+Pos)
    end.

-spec unexpected_sequence(binary(), non_neg_integer()) -> no_return().
unexpected_sequence(Value, Skip) ->
    error({unexpected_sequence, Value}, none, error_info(Skip)).
