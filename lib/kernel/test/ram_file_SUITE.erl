%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2001-2025. All Rights Reserved.
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
%%

-module(ram_file_SUITE).

-export([all/0, suite/0,groups/0,init_per_suite/1, end_per_suite/1, 
	 init_per_group/2,end_per_group/2,
	 %% init/1, fini/1,
	 init_per_testcase/2, end_per_testcase/2]).
-export([open_modes/1, pread_pwrite/1, position/1,
	 truncate/1, sync/1, get_file_and_size/1,
	 large_file_errors/1, large_file_light/1,
	 large_file_heavy/0, large_file_heavy/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("kernel/include/file.hrl").

-define(FILE_MODULE, file).         % Name of module to test
-define(RAM_FILE_MODULE, ram_file). % Name of module to test

%%--------------------------------------------------------------------------

suite() ->
    [{ct_hooks,[ts_install_cth]},
     {timetrap,{minutes,1}}].

all() -> 
    [open_modes, pread_pwrite, position,
     truncate, sync, get_file_and_size,
     large_file_errors, large_file_light, large_file_heavy].

groups() -> 
    [].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.


init_per_testcase(_Func, Config) ->
    Config.

end_per_testcase(_Func, Config) ->
    Config.

%%--------------------------------------------------------------------------
%% Test suites

%% Test that the basic read, write and binary options works for open/2.
open_modes(Config) when is_list(Config) ->
    Str1 = "The quick brown fox ",
    Str2 = "jumps over a lazy dog ",
    Str  = Str1 ++ Str2,
    Bin1 = list_to_binary(Str1),
    Bin2 = list_to_binary(Str2),
    Bin  = list_to_binary(Str),
    %%
    open_read_write(?FILE_MODULE, Str1, [ram, read, write], Str2),
    open_read(?FILE_MODULE, Str, [ram]),
    open_read_write(?FILE_MODULE, Bin1, [ram, binary, read, write], Bin2),
    open_read(?FILE_MODULE, Bin, [ram, binary, read]),
    %%
    ok.

open_read_write(Module, Data1, Options, Data2) ->
    io:format("~p:open_read_write(~p, ~p, ~p, ~p)~n",
	      [?MODULE, Module, Data1, Options, Data2]),
    %%
    Size1 = sizeof(Data1),
    Size2 = sizeof(Data2),
    Data  = append(Data1, Data2),
    Size  = Size1 + Size2,
    %%
    {ok, Fd}    = Module:open(Data1, Options),
    {ok, Data1} = Module:read(Fd, Size1),
    eof         = Module:read(Fd, 1),
    {ok, Zero}  = Module:read(Fd, 0),
    0           = sizeof(Zero),
    ok          = Module:write(Fd, Data2),
    {ok, 0}     = Module:position(Fd, bof),
    {ok, Data}  = Module:read(Fd, Size),
    eof         = Module:read(Fd, 1),
    {ok, Zero}  = Module:read(Fd, 0),
    ok          = Module:close(Fd),
    %%
    ok.

open_read(Module, Data, Options) ->
    io:format("~p:open_read(~p, ~p, ~p)~n",
	      [?MODULE, Module, Data, Options]),
    %%
    Size = sizeof(Data),
    %%
    {ok, Fd}         = Module:open(Data, Options),
    {ok, Data}       = Module:read(Fd, Size),
    eof              = Module:read(Fd, 1),
    {ok, Zero}       = Module:read(Fd, 0),
    0                = sizeof(Zero),
    {error, ebadf}   = Module:write(Fd, Data),
    {ok, 0}          = Module:position(Fd, bof),
    {ok, Data}       = Module:read(Fd, Size),
    eof              = Module:read(Fd, 1),
    {ok, Zero}       = Module:read(Fd, 0),
    ok               = Module:close(Fd),
    %%
    ok.



%% Test that pread/2,3 and pwrite/2,3 works.
pread_pwrite(Config) when is_list(Config) ->
    Str = "Flygande bäckaziner söka hwila på mjuqa tuvor x",
    Bin = list_to_binary(Str),
    %%
    pread_pwrite_test(?FILE_MODULE, Str, [ram, read, write]),
    pread_pwrite_test(?FILE_MODULE, Bin, [ram, binary, read, write]),
    pread_pwrite_test(?RAM_FILE_MODULE, Str, [read, write]),
    pread_pwrite_test(?RAM_FILE_MODULE, Bin, [binary, read, write]),
    %%
    ok.

pread_pwrite_test(Module, Data, Options) ->
    io:format("~p:pread_pwrite_test(~p, ~p, ~p)~n",
	      [?MODULE, Module, Data, Options]),
    %%
    Size = sizeof(Data),
    %%
    {ok, Fd}         = Module:open([], Options),
    ok               = Module:pwrite(Fd, 0, Data),
    {ok, Data}       = Module:pread(Fd, 0, Size+1),
    eof              = Module:pread(Fd, Size+1, 1),
    {ok, Zero}       = Module:pread(Fd, Size+1, 0),
    0                = sizeof(Zero),
    ok               = Module:pwrite(Fd, [{0, Data}, {Size+17, Data}]),
    {ok, [Data,
	  eof,
	  Data,
	  Zero]}     = Module:pread(Fd, [{Size+17, Size+1},
					 {2*Size+17+1, 1},
					 {0, Size},
					 {2*Size+17+1, 0}]),
    ok               = Module:close(Fd),
    %%
    ok.

%% Test that position/2 works.
position(Config) when is_list(Config) ->
    Str = "Att vara eller icke vara, det är frågan. ",
    Bin = list_to_binary(Str),
    %%
    position_test(?FILE_MODULE, Str, [ram, read]),
    position_test(?FILE_MODULE, Bin, [ram, binary]),
    position_test(?RAM_FILE_MODULE, Str, [read]),
    position_test(?RAM_FILE_MODULE, Bin, [binary, read]),
    %%
    ok.

position_test(Module, Data, Options) ->
    io:format("~p:position_test(~p, ~p, ~p)~n",
	      [?MODULE, Module, Data, Options]),
    %%
    Size = sizeof(Data),
    Size_7 = Size+7,
    %%
    Slice_0_2 = slice(Data, 0, 2),
    Slice_0_3 = slice(Data, 0, 3),
    Slice_2_5 = slice(Data, 2, 5),
    Slice_3_4 = slice(Data, 3, 4),
    Slice_5   = slice(Data, 5, Size),
    %%
    {ok, Fd}          = Module:open(Data, Options),
    %%
    io:format("CUR positions"),
    {ok, Slice_0_2}   = Module:read(Fd, 2),
    {ok, 2}           = Module:position(Fd, cur),
    {ok, Slice_2_5}   = Module:read(Fd, 5),
    {ok, 3}           = Module:position(Fd, {cur, -4}),
    {ok, Slice_3_4}   = Module:read(Fd, 4),
    {ok, 0}           = Module:position(Fd, {cur, -7}),
    {ok, Slice_0_3}   = Module:read(Fd, 3),
    {ok, 0}           = Module:position(Fd, {cur, -3}),
    {error, einval}   = Module:position(Fd, {cur, -1}),
    {ok, 0}           = Module:position(Fd, 0),
    {ok, 2}           = Module:position(Fd, {cur, 2}),
    {ok, Slice_2_5}   = Module:read(Fd, 5),
    {ok, Size_7}      = Module:position(Fd, {cur, Size}),
    {ok, Zero}        = Module:read(Fd, 0),
    0                 = sizeof(Zero),
    eof               = Module:read(Fd, 1),
    %%
    io:format("Absolute and BOF positions"),
    {ok, Size}        = Module:position(Fd, Size),
    eof               = Module:read(Fd, 1),
    {ok, 5}           = Module:position(Fd, 5),
    {ok, Slice_5}     = Module:read(Fd, Size),
    {ok, 2}           = Module:position(Fd, {bof, 2}),
    {ok, Slice_2_5}   = Module:read(Fd, 5),
    {ok, 3}           = Module:position(Fd, 3),
    {ok, Slice_3_4}   = Module:read(Fd, 4),
    {ok, 0}           = Module:position(Fd, bof),
    {ok, Slice_0_2}   = Module:read(Fd, 2),
    {ok, Size_7}      = Module:position(Fd, {bof, Size_7}),
    {ok, Zero}        = Module:read(Fd, 0),
    %%
    io:format("EOF positions"),
    {ok, Size}        = Module:position(Fd, eof),
    eof               = Module:read(Fd, 1),
    {ok, 5}           = Module:position(Fd, {eof, -Size+5}),
    {ok, Slice_5}     = Module:read(Fd, Size),
    {ok, 2}           = Module:position(Fd, {eof, -Size+2}),
    {ok, Slice_2_5}   = Module:read(Fd, 5),
    {ok, 3}           = Module:position(Fd, {eof, -Size+3}),
    {ok, Slice_3_4}   = Module:read(Fd, 4),
    {ok, 0}           = Module:position(Fd, {eof, -Size}),
    {ok, Slice_0_2}   = Module:read(Fd, 2),
    {ok, Size_7}      = Module:position(Fd, {eof, 7}),
    {ok, Zero}        = Module:read(Fd, 0),
    eof               = Module:read(Fd, 1),
    %%
    ok.



%% Test that truncate/1 works.
truncate(Config) when is_list(Config) ->
    Str = "Mån ädlare att lida och fördraga "
	++ "ett bittert ödes stygn av pilar, ",
    Bin = list_to_binary(Str),
    %%
    ok = truncate_test(?FILE_MODULE, Str, [ram, read, write]),
    ok = truncate_test(?FILE_MODULE, Bin, [ram, binary, read, write]),
    ok = truncate_test(?RAM_FILE_MODULE, Str, [read, write]),
    ok = truncate_test(?RAM_FILE_MODULE, Bin, [binary, read, write]),
    %%
    {error, eacces} = truncate_test(?FILE_MODULE, Str, [ram]),
    {error, eacces} = truncate_test(?FILE_MODULE, Bin, [ram, binary, read]),
    {error, eacces} = truncate_test(?RAM_FILE_MODULE, Str, [read]),
    {error, eacces} = truncate_test(?RAM_FILE_MODULE, Bin, [binary, read]),
    %%
    ok.

truncate_test(Module, Data, Options) ->
    io:format("~p:truncate_test(~p, ~p, ~p)~n",
	      [?MODULE, Module, Data, Options]),
    %%
    Size = sizeof(Data),
    Size1 = Size-2,
    Data1 = slice(Data, 0, Size1),
    %%
    {ok, Fd}    = Module:open(Data, Options),
    {ok, Size1} = Module:position(Fd, Size1),
    case Module:truncate(Fd) of
	ok ->
	    {ok, 0}     = Module:position(Fd, 0),
	    {ok, Data1} = Module:read(Fd, Size),
	    ok          = Module:close(Fd),
	    ok;
	Error ->
	    ok      = Module:close(Fd),
	    Error
    end.



%% Test that sync/1 at least does not crash.
sync(Config) when is_list(Config) ->
    Str = "än att ta till vapen mot ett hav av kval. ",
    Bin = list_to_binary(Str),
    %%
    sync_test(?FILE_MODULE, Str, [ram, read, write]),
    sync_test(?FILE_MODULE, Bin, [ram, binary, read, write]),
    sync_test(?RAM_FILE_MODULE, Str, [read, write]),
    sync_test(?RAM_FILE_MODULE, Bin, [binary, read, write]),
    %%
    sync_test(?FILE_MODULE, Str, [ram]),
    sync_test(?FILE_MODULE, Bin, [ram, binary, read]),
    sync_test(?RAM_FILE_MODULE, Str, [read]),
    sync_test(?RAM_FILE_MODULE, Bin, [binary, read]),
    %%
    ok.

sync_test(Module, Data, Options) ->
    io:format("~p:sync_test(~p, ~p, ~p)~n",
	      [?MODULE, Module, Data, Options]),
    %%
    Size = sizeof(Data),
    %%
    {ok, Fd}    = Module:open(Data, Options),
    ok          = Module:sync(Fd),
    {ok, Data}  = Module:read(Fd, Size+1),
    ok.



%% Tests get_file/1 and get_size/1.
get_file_and_size(Config) when is_list(Config) ->
    %% These two strings should not be of equal length.
    Str  = "När högan nord blir snöbetäckt, ",
    Bin  = list_to_binary(Str),
    %%
    ok = get_file_and_size_test(Str, [read, write]),
    ok = get_file_and_size_test(Bin, [binary, read, write]),
    ok = get_file_and_size_test(Str, [read]),
    ok = get_file_and_size_test(Bin, [binary, read]),
    %%
    ok.

get_file_and_size_test(Data, Options) ->
    io:format("~p:get_file_and_size_test(~p, ~p)~n",
	      [?MODULE, Data, Options]),
    %%
    Size  = sizeof(Data),
    %%
    {ok, Fd}        = ?RAM_FILE_MODULE:open(Data, Options),
    {ok, Size}      = ?RAM_FILE_MODULE:get_size(Fd),
    {ok, Data}      = ?RAM_FILE_MODULE:get_file(Fd),
    ok              = ?RAM_FILE_MODULE:close(Fd),
    {error, einval} = ?RAM_FILE_MODULE:get_size(Fd),
    ok.



%% Test error checking of large file offsets.
large_file_errors(Config) when is_list(Config) ->
    TwoGig = 1 bsl 31,
    {ok,Fd}         = ?RAM_FILE_MODULE:open("1234567890", [read,write]),
    {error, einval} = ?FILE_MODULE:read(Fd, TwoGig),
    {error, badarg} = ?FILE_MODULE:read(Fd, -1),
    {error, einval} = ?FILE_MODULE:position(Fd, {bof,TwoGig}),
    {error, einval} = ?FILE_MODULE:position(Fd, {bof,-TwoGig-1}),
    {error, einval} = ?FILE_MODULE:position(Fd, {bof,-1}),
    {error, einval} = ?FILE_MODULE:position(Fd, {cur,TwoGig}),
    {error, einval} = ?FILE_MODULE:position(Fd, {cur,-TwoGig-1}),
    {error, einval} = ?FILE_MODULE:position(Fd, {eof,TwoGig}),
    {error, einval} = ?FILE_MODULE:position(Fd, {eof,-TwoGig-1}),
    {error, einval} = ?FILE_MODULE:pread(Fd, TwoGig, 1),
    {error, einval} = ?FILE_MODULE:pread(Fd, -TwoGig-1, 1),
    {error, einval} = ?FILE_MODULE:pread(Fd, -1, 1),
    {error, einval} = ?FILE_MODULE:pwrite(Fd, TwoGig, "@"),
    {error, einval} = ?FILE_MODULE:pwrite(Fd, -TwoGig-1, "@"),
    {error, einval} = ?FILE_MODULE:pwrite(Fd, -1, "@"),
    {error, einval} = ?FILE_MODULE:pread(Fd, TwoGig, 0),
    {error, einval} = ?FILE_MODULE:pread(Fd, -TwoGig-1, 0),
    {error, einval} = ?FILE_MODULE:pread(Fd, -1, 0),
    ok              = ?FILE_MODULE:close(Fd),
    ok.



%% Test light operations on a \large\ ram_file.
large_file_light(Config) when is_list(Config) ->
    PrivDir = proplists:get_value(priv_dir, Config),
    %% Marker for next test case that is to heavy to run in a suite.
    ok = ?FILE_MODULE:write_file(
	    filename:join(PrivDir, "large_file_light"),
	    <<"TAG">>),
    %%
    Data = "abcdefghijklmnopqrstuvwzyz",
    Size = sizeof(Data),
    Max = (1 bsl 31) - 1,
    Max__1 = Max - 1,
    {ok, Fd}        = ?RAM_FILE_MODULE:open(Data, [read]),
    {ok, Data}      = ?FILE_MODULE:read(Fd, Size+1),
    {ok, Max__1}    = ?FILE_MODULE:position(Fd, {eof, Max-Size-1}),
    eof             = ?FILE_MODULE:read(Fd, 1),
    {ok, Max}       = ?FILE_MODULE:position(Fd, {bof, Max}),
    {ok, Zero}      = ?FILE_MODULE:read(Fd, 0),
    0               = sizeof(Zero),
    eof             = ?FILE_MODULE:read(Fd, 1),
    eof             = ?FILE_MODULE:pread(Fd, Max__1, 1),
    {ok, Zero}      = ?FILE_MODULE:pread(Fd, Max, 0),
    eof             = ?FILE_MODULE:pread(Fd, Max, 1),
    ok.



large_file_heavy() ->
    [{timetrap,{minutes,5}}].

%% Test operations on a maximum size (2 GByte - 1) ram_file.
large_file_heavy(Config) when is_list(Config) ->
    PrivDir = proplists:get_value(priv_dir, Config),
    %% Check previous test case marker.
    case ?FILE_MODULE:read_file_info(
	    filename:join(PrivDir, "large_file_light")) of
	{ok,_} ->
	    {skipped,"Too heavy for casual testing!"};
	_ ->
	    do_large_file_heavy(Config)
    end.

do_large_file_heavy(_Config) ->
    Data = "qwertyuiopasdfghjklzxcvbnm",
    Size = sizeof(Data),
    Max = (1 bsl 31) - 1,
    Max__1 = Max - 1,
    Max__3 = Max - 3,
    {ok, Fd}        = ?RAM_FILE_MODULE:open(Data, [read,write]),
    {ok, Data}      = ?FILE_MODULE:read(Fd, Size+1),
    {ok, Max}       = ?FILE_MODULE:position(Fd, {eof, Max-Size}),
    eof             = ?FILE_MODULE:read(Fd, 1),
    erlang:display({allocating,2,'GByte',please,be,patient,'...'}),
    ok              = ?FILE_MODULE:write(Fd, ""),
    erlang:display({allocating,2,'GByte',succeeded}),
    {ok, Max__1}    = ?FILE_MODULE:position(Fd, {eof, -1}),
    {ok, [0]}       = ?FILE_MODULE:read(Fd, 1),
    {ok, []}        = ?FILE_MODULE:read(Fd, 0),
    eof             = ?FILE_MODULE:read(Fd, 1),
    ok              = ?FILE_MODULE:pwrite(Fd, Max-3, "TAG"),
    {ok, Max}       = ?FILE_MODULE:position(Fd, cur),
    {ok, Max__3}    = ?FILE_MODULE:position(Fd, {eof, -3}),
    {ok, "TAG"}     = ?FILE_MODULE:read(Fd, 3+1),
    {ok, Max__3}    = ?FILE_MODULE:position(Fd, {cur, -3}),
    ok              = ?FILE_MODULE:write(Fd, "tag"),
    {ok, Max}       = ?FILE_MODULE:position(Fd, cur),
    {ok, 0}         = ?FILE_MODULE:position(Fd, bof),
    {ok, "tag"}     = ?FILE_MODULE:pread(Fd, Max__3, 3+1),
    {ok, 0}         = ?FILE_MODULE:position(Fd, cur),
    ok              = ?FILE_MODULE:close(Fd),
    ok.

%%--------------------------------------------------------------------------
%% Utility functions

sizeof(Data) when is_list(Data) ->
    length(Data);
sizeof(Data) when is_binary(Data) ->
    byte_size(Data).

append(Data1, Data2) when is_list(Data1), is_list(Data2) ->    
    Data1 ++ Data2;
append(Data1, Data2) when is_binary(Data1), is_binary(Data2) ->
    list_to_binary([Data1 | Data2]).

slice(Data, Start, Length) when is_list(Data) ->
    lists:sublist(Data, Start+1, Length);
slice(Data, Start, Length) when is_binary(Data) ->
    {_, Bin} = split_binary(Data, Start),
    if
	Length >= byte_size(Bin) ->
	    Bin;
	true ->
	    {B, _} = split_binary(Bin, Length),
	    B
    end.

