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
%%
-module(mod_range).
-moduledoc false.
-export([do/1]).
-include("httpd.hrl").
-include("httpd_internal.hrl").
%% do

do(Info) ->
    case Info#mod.method of
	"GET" ->
	    case proplists:get_value(status, Info#mod.data) of
		%% A status code has been generated!
		{_StatusCode,  _PhraseArgs, _Reason} ->
		    {proceed,Info#mod.data};
		%% No status code has been generated!
		undefined ->
		    case proplists:get_value(response, Info#mod.data) of
			%% No response has been generated!
			undefined ->
			    case proplists:get_value("range",
						     Info#mod.parsed_header) of
				undefined ->
				    %Not a range response
				    {proceed,Info#mod.data};
				Range ->
				    %%Control that there weren't a
				    %%if-range field that stopped The
				    %%range request in favor for the
				    %%whole file
				    case proplists:get_value(if_range,
							     Info#mod.data) of
					send_file ->
					    {proceed,Info#mod.data};
					_undefined ->
					    do_get_range(Info,Range)
				    end
			    end; 			
			%% A response has been generated or sent!
			_Response ->
			    {proceed, Info#mod.data}
		    end
	    end;
	%% Not a GET method!
	_ ->
	    {proceed,Info#mod.data}
    end.

do_get_range(Info,Ranges) ->
     Path = mod_alias:path(Info#mod.data, Info#mod.config_db, 
			  Info#mod.request_uri),
    {FileInfo, LastModified} = get_modification_date(Path),
    send_range_response(Path, Info, Ranges, FileInfo, LastModified).


send_range_response(Path, Info, Ranges, FileInfo, LastModified)->
    case parse_ranges(Ranges) of
	error->
	    {proceed,Info#mod.data};
	{multipart,RangeList}->
	    send_multi_range_response(Path, Info, RangeList);
	{Start,Stop}->
	    send_range_response(Path, Info, Start, Stop, FileInfo, 
				LastModified)
    end.
%%More than one range specified
%%Send a multipart response to the user
%
%%An example of an multipart range response

% HTTP/1.1 206 Partial Content
% Date:Wed 15 Nov 1995 04:08:23 GMT
% Last-modified:Wed 14 Nov 1995 04:08:23 GMT 
% Content-type: multipart/byteranges; boundary="SeparatorString" 
%
% --"SeparatorString"
% Content-Type: application/pdf
% Content-Range: bytes 500-600/1010
% .... The data..... 101 bytes
%
% --"SeparatorString"
% Content-Type: application/pdf
% Content-Range: bytes 700-1009/1010
% .... The data.....



send_multi_range_response(Path,Info,RangeList)->
    case file:open(Path, [raw,binary]) of
	{ok, FileDescriptor} ->
	    file:close(FileDescriptor),
	    Suffix = httpd_util:strip_extension_dot(Path),
	    PartMimeType = httpd_util:lookup_mime_default(Info#mod.config_db,
							  Suffix,"text/plain"),
	    {FileInfo,  LastModified} = get_modification_date(Path),
	    case valid_ranges(RangeList,Path,FileInfo) of
		{ValidRanges,true}->
		    %Apache breaks the standard by sending the size
		    %field in the Header.
		    Header = 
			[{code,206},
			 {content_type, "multipart/byteranges;boundary" 
			  "=RangeBoundarySeparator"}, 
			 {etag, httpd_util:create_etag(FileInfo)} | 
			 LastModified],
		    Body = {fun send_multiranges/4,
			    [ValidRanges, Info, PartMimeType, Path]},
		    {proceed,[{response,
			       {response, Header, Body}} | Info#mod.data]};
		_ ->
		    {proceed, [{status, {416, "Range not valid",
					 bad_range_boundaries }}]}
	    end;
	{error, _Reason} ->
	    {proceed,Info#mod.data}
    end.

send_multiranges(ValidRanges,Info,PartMimeType,Path)->    
    case file:open(Path, [raw,binary]) of
	{ok,FileDescriptor} ->
	    lists:foreach(fun(Range)->
				  send_multipart_start(Range,
						       Info,
						       PartMimeType,
						       FileDescriptor)
			  end,ValidRanges),
	    file:close(FileDescriptor),
	    %%Sends an end of the multipart
	    httpd_socket:deliver(Info#mod.socket_type,Info#mod.socket,
				 "\r\n--RangeBoundarySeparator--"),
	    sent;
	_ ->
	    close
    end.
   
send_multipart_start({{Start,End},{StartByte,EndByte,Size}},Info,
		     PartMimeType,FileDescriptor)
  when StartByte < Size ->
    PartHeader=["\r\n--RangeBoundarySeparator\r\n","Content-type: ",
		PartMimeType,"\r\n",
                "Content-Range:bytes=",integer_to_list(StartByte),"-",
		integer_to_list(EndByte),"/",
		integer_to_list(Size),"\r\n\r\n"],
    send_part_start(Info#mod.socket_type, Info#mod.socket, PartHeader,
		    FileDescriptor, Start, End);


send_multipart_start({{Start,End},{StartByte,EndByte,Size}}, Info,
		     PartMimeType, FileDescriptor)->
    PartHeader=["\r\n--RangeBoundarySeparator\r\n","Content-type: ",
		PartMimeType,"\r\n",
                "Content-Range:bytes=",integer_to_list(Size-(StartByte-Size)),
		"-",integer_to_list(EndByte),"/",
		integer_to_list(Size),"\r\n\r\n"],
    send_part_start(Info#mod.socket_type, Info#mod.socket, PartHeader,
		    FileDescriptor, Start, End).

send_part_start(SocketType, Socket, PartHeader, FileDescriptor, Start, End)->
    case httpd_socket:deliver(SocketType, Socket, PartHeader) of
	ok ->
	    send_part_start(SocketType,Socket,FileDescriptor,Start,End);
	_ ->
	    close
    end.    

send_range_response(Path, Info, Start, Stop, FileInfo, LastModified)->
    case file:open(Path, [raw,binary]) of
	{ok, FileDescriptor} ->
	    file:close(FileDescriptor),
	    Suffix = httpd_util:strip_extension_dot(Path),
	    MimeType = httpd_util:lookup_mime_default(Info#mod.config_db,
						      Suffix,"text/plain"),
	    Size = get_range_size(Start,Stop,FileInfo),
	    case valid_range(Start,Stop,FileInfo) of
		{true,StartByte,EndByte,TotByte}->
		    Head =[{code,206},{content_type, MimeType}, 
			   {etag, httpd_util:create_etag(FileInfo)},
			   {content_range,["bytes=",
					   integer_to_list(StartByte),"-",
					   integer_to_list(EndByte),"/",
					   integer_to_list(TotByte)]},
			   {content_length, Size} | LastModified],
		    BodyFunc = fun send_range_body/5,
		    Arg = [Info#mod.socket_type, 
			  Info#mod.socket, Path, Start, Stop], 
		    {proceed,[{response,{response ,Head,  {BodyFunc,Arg}}}|
			      Info#mod.data]};
		{false,Reason} ->
		    {proceed, [{status, {416, Reason, bad_range_boundaries }}]}
	    end;
	{error, _Reason} ->
	    {proceed,Info#mod.data}
    end.


send_range_body(SocketType,Socket,Path,Start,End) ->
    case file:open(Path, [raw,binary]) of
	{ok,FileDescriptor} ->
	    send_part_start(SocketType,Socket,FileDescriptor,Start,End),
	    file:close(FileDescriptor);
	_ ->
	    close
    end.

send_part_start(SocketType,Socket,FileDescriptor,Start,End) ->
    case Start of
	from_end ->
	    file:position(FileDescriptor,{eof,End}),
	    send_body(SocketType,Socket,FileDescriptor);
	from_start ->
	    file:position(FileDescriptor,{bof,End}),
	    send_body(SocketType,Socket,FileDescriptor);
	Byte when is_integer(Byte) ->
	    file:position(FileDescriptor,{bof,Start}),
	    send_part(SocketType,Socket,FileDescriptor,End)
    end,
    sent.


%%This function could replace send_body by calling it with Start=0 end
%%=FileSize But i gues it would be stupid when we look at performance
send_part(SocketType,Socket,FileDescriptor,End)->
    case file:position(FileDescriptor,{cur,0}) of
	{ok,NewPos} ->
	   if 
	       NewPos > End ->
		   ok;
	       true ->
		   Size = get_file_chunk_size(NewPos,End,?FILE_CHUNK_SIZE),
		   case file:read(FileDescriptor,Size) of
		       eof ->
			   ok;
		       {error, _Reason} ->
			   ok;
		       {ok,Binary} ->
			   case httpd_socket:deliver(SocketType,Socket,
						     Binary) of
			       socket_closed ->
				   socket_close;
			       _ ->
				   send_part(SocketType,Socket,
					     FileDescriptor,End)
			   end
		   end
	   end;
	_->
	    ok
    end.

%% validate that the range is in the limits of the file
valid_ranges(RangeList, _Path, FileInfo)->
    lists:mapfoldl(fun({Start,End},Acc)->
			case Acc of 
			    true ->
				case valid_range(Start,End,FileInfo) of
				    {true,StartB,EndB,Size}->
					{{{Start,End},
					  {StartB,EndB,Size}},true};
				    _ ->
					false
				end;
			    _ ->
				{false,false}
			end
		   end,true,RangeList).
				 
			      

valid_range(from_end,End,FileInfo)->
    Size=FileInfo#file_info.size,
    if
	End < Size ->
	    {true,(Size+End),Size-1,Size};
	true ->
	    false
    end;
valid_range(from_start,End,FileInfo)->
  Size=FileInfo#file_info.size,
    if
	End < Size ->
	    {true,End,Size-1,Size};
	true ->
	    false
    end;

valid_range(Start,End,FileInfo) when Start =< End ->
    case FileInfo#file_info.size of
	FileSize when Start< FileSize ->
	    case FileInfo#file_info.size of
		Size when End<Size ->
		    {true,Start,End,FileInfo#file_info.size};
		Size ->
		    {true,Start,Size-1,Size}
	    end;
	_->
	    {false,"The size of the range is negative"}
    end;
		      
valid_range(_Start,_End,_FileInfo)->
    {false,"Range starts out of file boundaries"}.
%% Find the modification date of the file
get_modification_date(Path)->
    case file:read_file_info(Path) of
	{ok, FileInfo0} ->
	    case (catch httpd_util:rfc1123_date(FileInfo0#file_info.mtime)) of
		Date when is_list(Date) ->
		    {FileInfo0, [{last_modified, Date}]};
		_ ->
		    {FileInfo0, []}
	    end;
	_ ->
	    {#file_info{}, []}
    end.

%Calculate the size of the chunk to read
	
get_file_chunk_size(Position, End, DefaultChunkSize) 
  when (Position+DefaultChunkSize) =< End ->
    DefaultChunkSize;
get_file_chunk_size(Position, End, _DefaultChunkSize) ->
    (End-Position) +1.



%Get the size of the range to send. Remember that
%A range is from startbyte up to endbyte which means that
%the number of byte in a range is (StartByte-EndByte)+1

get_range_size(from_end, Stop, _FileInfo)->
    integer_to_list(-1*Stop);

get_range_size(from_start, StartByte, FileInfo) ->
    integer_to_list((((FileInfo#file_info.size)-StartByte)));

get_range_size(StartByte, EndByte, _FileInfo) ->
    integer_to_list((EndByte-StartByte)+1).

parse_ranges("\bytes\=" ++ Ranges)->
    parse_ranges("bytes\=" ++ Ranges);
parse_ranges("bytes\=" ++ Ranges)->
    case string:tokens(Ranges,", ") of
       [Range] ->
	   parse_range(Range);
       [Range1|SplittedRanges]->
	   {multipart,lists:map(fun parse_range/1,[Range1|SplittedRanges])}
    end;
%Bad unit
parse_ranges(Ranges)->
    io:format("Bad Ranges : ~p",[Ranges]),
    error.
%Parse the range  specification from the request to {Start,End}
%Start=End : Numreric string | []

parse_range(Range)->
    format_range(split_range(Range,[],[])).
format_range({[],BytesFromEnd})->
    {from_end,-1*(list_to_integer(BytesFromEnd))};
format_range({StartByte,[]})->    
    {from_start,list_to_integer(StartByte)};
format_range({StartByte,EndByte})->        
    {list_to_integer(StartByte),list_to_integer(EndByte)}.
%Last case return the split range
split_range([],Current,Other)->
    {lists:reverse(Other),lists:reverse(Current)};

split_range([$-|Rest],Current,Other)->
    split_range(Rest,Other,Current);

split_range([N|Rest],Current,End) ->
    split_range(Rest,[N|Current],End).

send_body(SocketType,Socket,FileDescriptor) ->
    case file:read(FileDescriptor,?FILE_CHUNK_SIZE) of
	{ok,Binary} ->
	    case httpd_socket:deliver(SocketType,Socket,Binary) of
		socket_closed ->
		    socket_close;
		_ ->
		    send_body(SocketType,Socket,FileDescriptor)
	    end;
	eof ->
	    eof
    end.
