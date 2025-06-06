%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2009-2025. All Rights Reserved.
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

%%%-------------------------------------------------------------------
%%% File: ct_error_SUITE
%%%
%%% Description: 
%%% Test various errors in Common Test suites.
%%%
%%% The suites used for the test are located in the data directory.
%%%-------------------------------------------------------------------
-module(ct_hooks_SUITE).

-compile([export_all, nowarn_export_all]).

-include_lib("common_test/include/ct.hrl").
-include_lib("common_test/include/ct_event.hrl").
-include_lib("kernel/src/logger_internal.hrl").

-define(eh, ct_test_support_eh).
-define(cth_event3(CALLBACK, SUITE, VAR1),
        {?eh, cth, {'_', CALLBACK,
                    [SUITE, VAR1, '_']}}).
-define(cth_event4(CALLBACK, SUITE, VAR1, VAR2),
        {?eh, cth, {'_', CALLBACK,
                    [SUITE, VAR1, VAR2, '_']}}).
-define(cth_event5(CALLBACK, SUITE, VAR1, VAR2, VAR3),
        {?eh, cth, {'_', CALLBACK,
                    [SUITE, VAR1, VAR2, VAR3, '_']}}).
%%--------------------------------------------------------------------
%% TEST SERVER CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Description: Since Common Test starts another Test Server
%% instance, the tests need to be performed on a separate node (or
%% there will be clashes with logging processes etc).
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    DataDir = ?config(data_dir, Config),
    TestDir = filename:join(DataDir,"cth/tests/"),
    CTHs = filelib:wildcard(filename:join(TestDir,"*_cth.erl")),
    io:format("CTHs: ~p",[CTHs]),
    [io:format("Compiling ~p: ~p",
	    [FileName,compile:file(FileName,[{outdir,TestDir},debug_info])]) ||
	FileName <- CTHs],
    ct_test_support:init_per_suite([{path_dirs,[TestDir]} | Config]).

end_per_suite(Config) ->
    ct_test_support:end_per_suite(Config).

init_per_testcase(TestCase, Config) ->
    ct_test_support:init_per_testcase(TestCase, Config).


end_per_testcase(cth_log_formatter = TestCase, Config) ->
    ct_test_support:ct_rpc(
      {logger,set_handler_config,
       [default, formatter,
        {?DEFAULT_FORMATTER,?DEFAULT_FORMAT_CONFIG}]}, Config),
    ct_test_support:end_per_testcase(TestCase, Config);
end_per_testcase(TestCase, Config) ->
    ct_test_support:end_per_testcase(TestCase, Config).


suite() ->
    [{timetrap,{minutes,1}}].

all() ->
    all(suite).

all(suite) ->
    lists:reverse(
      [
       crash_groups, crash_all, bad_return_groups, bad_return_all,
       illegal_values_groups, illegal_values_all, alter_groups, alter_all,
       alter_all_to_skip, alter_all_from_skip,
       one_cth, two_cth, faulty_cth_no_init, faulty_cth_id_no_init,
       faulty_cth_exit_in_init, faulty_cth_exit_in_id,
       faulty_cth_exit_in_init_scope_suite, minimal_cth,
       minimal_and_maximal_cth, faulty_cth_undef,
       scope_per_suite_cth, scope_per_group_cth, scope_suite_cth,
       scope_suite_group_only_cth,
       scope_per_suite_state_cth, scope_per_group_state_cth,
       scope_suite_state_cth,
       fail_pre_suite_cth, double_fail_pre_suite_cth,
       fail_post_suite_cth, skip_pre_suite_cth, skip_pre_end_cth,
       skip_pre_init_tc_cth, fail_post_init_tc_cth,
       skip_post_suite_cth, recover_post_suite_cth, update_config_cth,
       update_config_cth2,
       ct_hooks_order_test_cth, ct_hooks_order_config_suite_cth,
       ct_hooks_order_config_ips_cth,
       state_update_cth, update_result_cth, options_cth, same_id_cth,
       fail_n_skip_with_minimal_cth, prio_cth, no_config,
       no_init_suite_config, no_init_config, no_end_config,
       failed_sequence, repeat_force_stop, config_clash,
       callbacks_on_skip, fallback, data_dir,
       {group, cth_log_redirect}
      ]
    ).

groups() ->
    [
     {cth_log_redirect, [], [cth_log_unexpect, cth_log_formatter,
                             cth_log, cth_log_mode_replace]}
    ].


%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%%-----------------------------------------------------------------
%%% 
one_cth(Config) when is_list(Config) ->
    do_test(one_empty_cth, "ct_cth_empty_SUITE.erl",[empty_cth], Config).

two_cth(Config) when is_list(Config) ->
    do_test(two_empty_cth, "ct_cth_empty_SUITE.erl",[empty_cth,empty_cth],
	    Config).

faulty_cth_no_init(Config) when is_list(Config) ->
    do_test(faulty_cth_no_init, "ct_cth_empty_SUITE.erl",[askjhdkljashdkaj],
	    Config,{error,"Failed to start CTH, see the "
		   "CT Log for details"}).

faulty_cth_id_no_init(Config) when is_list(Config) ->
    do_test(faulty_cth_id_no_init, "ct_cth_empty_SUITE.erl",[id_no_init_cth],
	    Config,{error,"Failed to start CTH, see the "
		   "CT Log for details"}).

minimal_cth(Config) when is_list(Config) ->
    do_test(minimal_cth, "ct_cth_empty_SUITE.erl",[minimal_cth],Config).

minimal_and_maximal_cth(Config) when is_list(Config) ->
    do_test(minimal_and_maximal_cth, "ct_cth_empty_SUITE.erl",
	    [minimal_cth, empty_cth],Config).

faulty_cth_undef(Config) when is_list(Config) ->
    do_test(faulty_cth_undef, "ct_cth_empty_SUITE.erl",
	    [undef_cth],Config).

faulty_cth_exit_in_init_scope_suite(Config) when is_list(Config) ->
    do_test(faulty_cth_exit_in_init_scope_suite,
	    "ct_exit_in_init_scope_suite_cth_SUITE.erl",
	    [],Config).

faulty_cth_exit_in_init(Config) when is_list(Config) ->
    do_test(faulty_cth_exit_in_init, "ct_cth_empty_SUITE.erl",
	    [crash_init_cth], Config,
	    {error,"Failed to start CTH, see the "
	     "CT Log for details"}).

faulty_cth_exit_in_id(Config) when is_list(Config) ->
    do_test(faulty_cth_exit_in_id, "ct_cth_empty_SUITE.erl",
	    [crash_id_cth], Config,
	    {error,"Failed to start CTH, see the "
	     "CT Log for details"}).

scope_per_suite_cth(Config) when is_list(Config) ->
    do_test(scope_per_suite_cth, "ct_scope_per_suite_cth_SUITE.erl",
	    [],Config).

scope_suite_cth(Config) when is_list(Config) ->
    do_test(scope_suite_cth, "ct_scope_suite_cth_SUITE.erl",
	    [],Config).

scope_suite_group_only_cth(Config) when is_list(Config) ->
    do_test(scope_suite_group_only_cth,
            "ct_scope_suite_group_only_cth_SUITE.erl",
	    [],Config,ok,2,[{group,g1}]).

scope_per_group_cth(Config) when is_list(Config) ->
    do_test(scope_per_group_cth, "ct_scope_per_group_cth_SUITE.erl",
	    [],Config).

scope_per_suite_state_cth(Config) when is_list(Config) ->
    do_test(scope_per_suite_state_cth, "ct_scope_per_suite_state_cth_SUITE.erl",
	    [],Config).

scope_suite_state_cth(Config) when is_list(Config) ->
    do_test(scope_suite_state_cth, "ct_scope_suite_state_cth_SUITE.erl",
	    [],Config).

scope_per_group_state_cth(Config) when is_list(Config) ->
    do_test(scope_per_group_state_cth, "ct_scope_per_group_state_cth_SUITE.erl",
	    [],Config).

fail_pre_suite_cth(Config) when is_list(Config) ->
    do_test(fail_pre_suite_cth, "ct_cth_empty_SUITE.erl",
	    [fail_pre_suite_cth],Config).

double_fail_pre_suite_cth(Config) when is_list(Config) ->
    do_test(double_fail_pre_suite_cth, "{ct_scope_suite_crash_in_cth_SUITE.erl,"
	    "ct_scope_suite_cth_SUITE.erl}",
	    [],Config).

fail_post_suite_cth(Config) when is_list(Config) ->
    do_test(fail_post_suite_cth, "ct_cth_empty_SUITE.erl",
	    [fail_post_suite_cth],Config).

skip_pre_suite_cth(Config) when is_list(Config) ->
    do_test(skip_pre_suite_cth, "ct_cth_empty_SUITE.erl",
	    [skip_pre_suite_cth],Config).

skip_pre_end_cth(Config) when is_list(Config) ->
    do_test(skip_pre_end_cth, "ct_scope_per_group_cth_SUITE.erl",
	    [skip_pre_end_cth],Config).

skip_post_suite_cth(Config) when is_list(Config) ->
    do_test(skip_post_suite_cth, "ct_cth_empty_SUITE.erl",
	    [skip_post_suite_cth],Config).

skip_pre_init_tc_cth(Config) ->
    do_test(skip_pre_init_tc_cth, "ct_cth_empty_SUITE.erl",
	    [skip_pre_init_tc_cth],Config).

fail_post_init_tc_cth(Config) ->
    do_test(fail_post_init_tc_cth, "ct_fail_init_tc_SUITE.erl",
	    [fail_post_init_tc_cth],Config).

recover_post_suite_cth(Config) when is_list(Config) ->
    do_test(recover_post_suite_cth, "ct_cth_fail_per_suite_SUITE.erl",
	    [recover_post_suite_cth],Config).

update_config_cth(Config) when is_list(Config) ->
    do_test(update_config_cth, "ct_update_config_SUITE.erl",
	    [update_config_cth],Config).
%% no init/end_per_testcase functions in suite
update_config_cth2(Config) when is_list(Config) ->
    do_test(update_config_cth2, "ct_update_config_SUITE2.erl",
	    [update_config_cth],Config).

ct_hooks_order_test_cth(Config) when is_list(Config) ->
    do_test(ct_hooks_order_test_cth, "ct_hooks_order_test_SUITE.erl",
	    [ct_hooks_order_a_cth, ct_hooks_order_b_cth],Config).

ct_hooks_order_config_suite_cth(Config) when is_list(Config) ->
    do_test(ct_hooks_order_config_suite_cth, "ct_hooks_order_config_suite_SUITE.erl",
	    [ct_hooks_order_a_cth, ct_hooks_order_b_cth],Config).

ct_hooks_order_config_ips_cth(Config) when is_list(Config) ->
    do_test(ct_hooks_order_config_ips_cth, "ct_hooks_order_config_ips_SUITE.erl",
	    [ct_hooks_order_a_cth, ct_hooks_order_b_cth],Config).

state_update_cth(Config) when is_list(Config) ->
    do_test(state_update_cth, "ct_cth_fail_one_skip_one_SUITE.erl",
	    [state_update_cth,state_update_cth],Config).

update_result_cth(Config) ->
    do_test(update_result_cth, "ct_cth_update_result_post_end_tc_SUITE.erl",
            [update_result_post_end_tc_cth],Config).

options_cth(Config) when is_list(Config) ->
    do_test(options_cth, "ct_cth_empty_SUITE.erl",
	    [{empty_cth,[test]}],Config).

same_id_cth(Config) when is_list(Config) ->
    do_test(same_id_cth, "ct_cth_empty_SUITE.erl",
	    [same_id_cth,same_id_cth],Config).

fail_n_skip_with_minimal_cth(Config) when is_list(Config) ->
    do_test(fail_n_skip_with_minimal_cth, "ct_cth_fail_one_skip_one_SUITE.erl",
	    [minimal_terminate_cth],Config).

prio_cth(Config) when is_list(Config) ->
    do_test(prio_cth, "ct_cth_prio_SUITE.erl",
	    [{empty_cth,[1000],1000},{empty_cth,[900],900},
	     {prio_cth,[1100,100],100},{prio_cth,[1100]}],Config).

no_config(Config) when is_list(Config) ->
    do_test(no_config, "ct_no_config_SUITE.erl",
	    [verify_config_cth],Config).

no_init_suite_config(Config) when is_list(Config) ->
    do_test(no_init_suite_config, "ct_no_init_suite_config_SUITE.erl",
            [empty_cth],Config).

no_init_config(Config) when is_list(Config) ->
    do_test(no_init_config, "ct_no_init_config_SUITE.erl",[empty_cth],Config).

no_end_config(Config) when is_list(Config) ->
    do_test(no_end_config, "ct_no_end_config_SUITE.erl",[empty_cth],Config).

data_dir(Config) when is_list(Config) ->
    do_test(data_dir, "ct_data_dir_SUITE.erl",
	    [verify_data_dir_cth],Config).

cth_log(Config) when is_list(Config) ->
    %% test that cth_log_redirect writes properly to
    %% html I/O log
    verify_cth_log_output(Config, [], []).

cth_log_formatter(Config) when is_list(Config) ->
    %% test that cth_log_redirect writes properly to
    %% html I/O log using the formatter
    ct:timetrap({minutes,10}),
    ct_test_support:ct_rpc({logger,set_handler_config,[default, formatter,
                              {logger_formatter,#{ template => [level,":",msg,"\n"] }}]},
                           Config),
    StartOpts = do_test(cth_log_formatter, "cth_log_formatter_SUITE.erl", [], Config),
    Logdir = proplists:get_value(logdir, StartOpts),
    TCLogs =
	filelib:wildcard(
	  filename:join(Logdir,
			"ct_run*/cth.tests*/run*/cth_log_formatter_suite.tc*.html")),
    lists:foreach(
      fun(TCLog) ->
	      {ok,Bin} = file:read_file(TCLog),
	      Ts = string:lexemes(binary_to_list(Bin),[$\n]),
	      Matches = lists:foldl(fun("error:"++_,  {E,N,L}) ->
					    {E+1,N,L};
				       ("notice:"++_,  {E,N,L}) ->
					    {E,N+1,L};
				       ("Logger"++_,  {E,N,L}) ->
					    {E,N,L+1};
				       (_, N) -> N
				    end, {0,0,0}, Ts),
	      ct:pal("~p ({Error,Notice,Log}) matches in ~tp",
                     [Matches,TCLog]),
              MatchList = tuple_to_list(Matches),
              case [N || N <- MatchList, N<1] of
                  [] -> ok;
                  _ -> exit({missing_io,TCLog})
	      end
      end, TCLogs),
    ok.

cth_log_unexpect(Config) when is_list(Config) ->
    %% test that cth_log_redirect writes properly to
    %% unexpected I/O log
    ct:timetrap({minutes,10}),
    StartOpts = do_test(cth_log_unexpect, "cth_log_unexpect_SUITE.erl", [], Config),
    Logdir = proplists:get_value(logdir, StartOpts),
    UnexpIoLogs =
	filelib:wildcard(
	  filename:join(Logdir,
			"ct_run*/cth.tests*/run*/unexpected_io.log.html")),
    lists:foreach(
      fun(UnexpIoLog) ->
	      {ok,Bin} = file:read_file(UnexpIoLog),
	      Ts = string:lexemes(binary_to_list(Bin),[$\n]),
	      Matches = lists:foldl(fun("=ERROR"++_,  {E,I,L}) ->
					    {E+1,I,L};
				       ("=INFO"++_,  {E,I,L}) ->
					    {E,I+1,L};
				       ("Logger"++_,  {E,I,L}) ->
					    {E,I,L+1};
				       (_, N) -> N
				    end, {0,0,0}, Ts),
	      ct:pal("~p ({Error,Info,Log}) matches in ~tp",
                     [Matches,UnexpIoLog]),
              MatchList = tuple_to_list(Matches),
              case [N || N <- MatchList, N<3] of
                  [] -> ok;
                  _ -> exit({missing_unexpected_io,UnexpIoLog})
	      end
      end, UnexpIoLogs),
    ok.

cth_log_mode_replace(Config) when is_list(Config) ->
    %% test that cth_log_redirect writes properly to
    %% html I/O log when replace mode is used
    verify_cth_log_output(Config, [{cth_log_redirect, [{mode, replace}]}],
                          [{enable_builtin_hooks, false}]).

%% OTP-10599 adds the Suite argument as first argument to all hook
%% callbacks that did not have a Suite argument from before. This test
%% checks that ct_hooks will fall back to old versions of callbacks if
%% new versions are not exported.
fallback(Config) ->
    do_test(fallback, "all_hook_callbacks_SUITE.erl",[fallback_cth], Config).

%% Test that expected callbacks, and only those, are called when tests
%% are skipped in different ways
callbacks_on_skip(Config) ->
    do_test(callbacks_on_skip, {spec,"skip.spec"},[skip_cth], Config).

%% Test that expected callbacks, and only those, are called when tests
%% are skipped due to failed sequence
failed_sequence(Config) ->
    do_test(failed_sequence, "seq_SUITE.erl", [skip_cth], Config).

%% Test that expected callbacks, and only those, are called when tests
%% are skipped due to {force_stop,skip_rest} option
repeat_force_stop(Config) ->
    do_test(repeat_force_stop, "repeat_SUITE.erl", [skip_cth], Config, ok, 2,
            [{force_stop,skip_rest},{duration,"000009"}]).

%% Test that expected callbacks, and only those, are called when a test
%% fails due to clash in config alias names
config_clash(Config) ->
    do_test(config_clash, "config_clash_SUITE.erl", [skip_cth], Config).

%% Test post_groups and post_all hook callbacks, introduced by OTP-14746
alter_groups(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,
                         [{post_groups_return,[{new_group,[tc1,tc2]}]},
                          {post_all_return,[{group,new_group}]}],Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

alter_all(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{post_all_return,[tc2]}],Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

alter_all_from_skip(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{all_return,{skip,"skipped by all/0"}},
                                         {post_all_return,[tc2]}],Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

alter_all_to_skip(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,
                         [{post_all_return,{skip,"skipped by post_all/3"}}],
                         Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

bad_return_groups(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{post_groups_return,not_a_list}],
                         Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

bad_return_all(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{post_all_return,not_a_list}],
                         Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

illegal_values_groups(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,
                         [{post_groups_return,[{new_group,[this_test_does_not_exist]},
                                          this_is_not_a_group_def]}],
                         Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

illegal_values_all(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,
                         [{post_all_return,[{group,this_group_does_not_exist},
                                       {this_is_not_a_valid_term}]}],
                         Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

crash_groups(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{post_groups_return,crash}],Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

crash_all(Config) ->
    CfgFile = gen_config(?FUNCTION_NAME,[{post_all_return,crash}],Config),
    do_test(?FUNCTION_NAME, "all_and_groups_SUITE.erl", [all_and_groups_cth],
            Config, ok, 2, [{config,CfgFile}]).

%%%-----------------------------------------------------------------
%%% HELP FUNCTIONS
%%%-----------------------------------------------------------------

do_test(Tag, WTT, CTHs, Config) ->
    do_test(Tag, WTT, CTHs, Config, ok).
do_test(Tag, WTT, CTHs, Config, {error,_} = Res) ->
    do_test(Tag, WTT, CTHs, Config, Res, 1,[]);
do_test(Tag, WTT, CTHs, Config, Res) ->
    do_test(Tag, WTT, CTHs, Config, Res, 2,[]).

do_test(Tag, WhatToTest, CTHs, Config, Res, EC, ExtraOpts) when is_list(WhatToTest) ->
    do_test(Tag, {suite,WhatToTest}, CTHs, Config, Res, EC, ExtraOpts);
do_test(Tag, {WhatTag,Wildcard}, CTHs, Config, Res, EC, ExtraOpts) ->
    DataDir = ?config(data_dir, Config),
    Files = filelib:wildcard(
               filename:join([DataDir,"cth/tests",Wildcard])),
    {Opts,ERPid} =
        setup([{WhatTag,Files},{ct_hooks,CTHs},{label,Tag}|ExtraOpts], Config),

    Res = ct_test_support:run(Opts, Config),
    Events = ct_test_support:get_events(ERPid, Config),

    ct_test_support:log_events(Tag,
			       reformat(Events, ?eh),
			       ?config(priv_dir, Config),
			       Opts),

    TestEvents = events_to_check(Tag, EC),
    ok = ct_test_support:verify_events(TestEvents, Events, Config),
    Opts.

setup(Test, Config) ->
    Opts0 = ct_test_support:get_opts(Config),
    Level = ?config(trace_level, Config),
    EvHArgs = [{cbm,ct_test_support},{trace_level,Level}],
    Opts = Opts0 ++ [{event_handler,{?eh,EvHArgs}}|Test],
    ERPid = ct_test_support:start_event_receiver(Config),
    {Opts,ERPid}.

reformat(Events, EH) ->
    ct_test_support:reformat(Events, EH).
%reformat(Events, _EH) ->
%    Events.

gen_config(Name,KeyVals,Config) ->
    PrivDir = ?config(priv_dir,Config),
    File = filename:join(PrivDir,atom_to_list(Name)++".cfg"),
    ok = file:write_file(File,[io_lib:format("~p.~n",[{Key,Value}])
                               || {Key,Value} <- KeyVals]),
    File.

verify_cth_log_output(Config, CTHooks, ExtraOpts) ->
    ct:timetrap({minutes,10}),
    StartOpts = do_test(cth_log, "cth_log_SUITE.erl", CTHooks, Config, ok, 2, ExtraOpts),
    Logdir = proplists:get_value(logdir, StartOpts),
    TCLogs =
	filelib:wildcard(
	  filename:join(Logdir,
			"ct_run*/cth.tests*/run*/cth_log_suite.tc*.html")),
    lists:foreach(
      fun(TCLog) ->
	      {ok,Bin} = file:read_file(TCLog),
	      Ts = string:lexemes(binary_to_list(Bin),[$\n]),
	      Matches = lists:foldl(fun("=ERROR"++_,  {E,I,N,L}) ->
					    {E+1,I,N,L};
				       ("=INFO"++_,  {E,I,N,L}) ->
					    {E,I+1,N,L};
				       ("=NOTICE"++_,  {E,I,N,L}) ->
					    {E,I,N+1,L};
				       ("Logger"++_,  {E,I,N,L}) ->
					    {E,I,N,L+1};
				       (_, N) -> N
				    end, {0,0,0,0}, Ts),
	      ct:pal("~p ({Error,Info,Notice,Log}) matches in ~tp",
                     [Matches,TCLog]),
              MatchList = tuple_to_list(Matches),
              case [N || N <- MatchList, N<1] of
                  [] -> ok;
                  _ -> exit({missing_io,TCLog})
	      end
      end, TCLogs),
    ok.


%%%-----------------------------------------------------------------
%%% TEST EVENTS
%%%-----------------------------------------------------------------
events_to_check(Test) ->
    %% 2 tests (ct:run_test + script_start) is default
    events_to_check(Test, 2).

events_to_check(_, 0) ->
    [];
events_to_check(Test, N) ->
    test_events(Test) ++ events_to_check(Test, N-1).

test_events(one_empty_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     %% check that post_groups and post_all comes after init when hook
     %% is installed with start flag/option.
     {?eh,cth,{empty_cth,post_groups,[ct_cth_empty_SUITE,[]]}},
     {?eh,cth,{empty_cth,post_all,[ct_cth_empty_SUITE,[test_case],[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},
     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist','_',[]]}},
     {?eh,cth,{empty_cth,pre_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(two_empty_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',ok,[]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(faulty_cth_no_init) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(faulty_cth_id_no_init) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',id,[[]]}},
     {negative,{?eh,tc_start,'_'},
      {?eh,test_done,{'DEF','STOP_TIME'}}},
     {?eh,stop_logging,[]}
    ];

test_events(minimal_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {negative,{?eh,cth,{'_',id,['_',[]]}},
      {?eh,cth,{'_',init,['_',[]]}}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(minimal_and_maximal_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',id,[[]]}},
     {negative,{?eh,cth,{'_',id,['_',[]]}},
      {?eh,cth,{'_',init,['_',[]]}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(faulty_cth_undef) ->
    FailReasonStr = "undef_cth:pre_init_per_suite/3 CTH call failed",
    FailReason = {ct_cth_empty_SUITE,init_per_suite,
		  {failed,FailReasonStr}},
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,
		  {failed, {error,FailReasonStr}}}},
     {?eh,cth,{'_',on_tc_fail,'_'}},

     {?eh,tc_auto_skip,{ct_cth_empty_SUITE,test_case,
			{failed, FailReason}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},

     {?eh,tc_auto_skip,{ct_cth_empty_SUITE,end_per_suite,
			{failed, FailReason}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},

     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(faulty_cth_exit_in_init_scope_suite) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{'_',init_per_suite}},
     {?eh,cth,{empty_cth,init,['_',[]]}},
     {?eh,tc_done,
      {ct_exit_in_init_scope_suite_cth_SUITE,init_per_suite,
       {failed,
	{error,
	 "Failed to start CTH, see the CT Log for details"}}}},
     {?eh,tc_auto_skip,
      {ct_exit_in_init_scope_suite_cth_SUITE,test_case,
       {failed,
	{ct_exit_in_init_scope_suite_cth_SUITE,init_per_suite,
	 {failed,
	  "Failed to start CTH, see the CT Log for details"}}}}},
     {?eh,tc_auto_skip,
      {ct_exit_in_init_scope_suite_cth_SUITE,end_per_suite,
       {failed,
	{ct_exit_in_init_scope_suite_cth_SUITE,init_per_suite,
	 {failed,
	  "Failed to start CTH, see the CT Log for details"}}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}];

test_events(faulty_cth_exit_in_init) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,['_',[]]}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}];

test_events(faulty_cth_exit_in_id) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {negative, {?eh,tc_start,'_'},
      {?eh,test_done,{'DEF','STOP_TIME'}}},
     {?eh,stop_logging,[]}];

test_events(scope_per_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{ct_scope_per_suite_cth_SUITE,init_per_suite}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_scope_per_suite_cth_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_scope_per_suite_cth_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_scope_per_suite_cth_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_per_suite_cth_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_scope_per_suite_cth_SUITE,test_case,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_scope_per_suite_cth_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_scope_per_suite_cth_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,
	       [ct_scope_per_suite_cth_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_scope_per_suite_cth_SUITE,'$proplist','_',[]]}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,tc_done,{ct_scope_per_suite_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     %% check that post_groups and post_all comes before init when hook
     %% is installed in suite/0
     %% And there should be no terminate after these, since init is
     %% not yet called.
     {?eh,cth,{'_',post_groups,['_',[]]}},
     {negative,
      {?eh,cth,{'_',terminate,['_']}},
      {?eh,cth,{'_',post_all,['_','_',[]]}}},
     {negative,
      {?eh,cth,{'_',terminate,['_']}},
      {?eh,tc_start,{ct_scope_suite_cth_SUITE,init_per_suite}}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_scope_suite_cth_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_scope_suite_cth_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_scope_suite_cth_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_scope_suite_cth_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_suite_cth_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_scope_suite_cth_SUITE,test_case,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_scope_suite_cth_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_scope_suite_cth_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_scope_suite_cth_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_scope_suite_cth_SUITE,'$proplist','_',[]]}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,tc_done,{ct_scope_suite_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_suite_group_only_cth) ->
    Suite = ct_scope_suite_group_only_cth_SUITE,
    CTH = empty_cth,
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,start_info,{1,1,1}},
     %% check that post_groups and post_all comes before init when hook
     %% is installed in suite/0
     {?eh,cth,{CTH,post_groups,['_',['_']]}},
     {negative,
      {?eh,cth,{CTH,post_all,['_','_','_']}},
      {?eh,tc_start,{Suite,init_per_suite}}},
     {?eh,cth,{CTH,id,[[]]}},
     {?eh,cth,{CTH,init,['_',[]]}},
     {?eh,cth,{CTH,pre_init_per_suite,[Suite,'$proplist',mystate]}},
     {?eh,cth,{CTH,post_init_per_suite,[Suite,'$proplist','$proplist',mystate]}},
     {?eh,tc_done,{Suite,init_per_suite,ok}},

     {?eh,tc_start,{Suite,end_per_suite}},
     {?eh,cth,{CTH,pre_end_per_suite,[Suite,'$proplist',mystate]}},
     {?eh,cth,{CTH,post_end_per_suite,[Suite,'$proplist','_',mystate]}},
     {?eh,cth,{CTH,terminate,[mystate]}},
     {?eh,tc_done,{Suite,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_per_group_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{ct_scope_per_group_cth_SUITE,init_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_cth_SUITE,init_per_suite,ok}},

     [{?eh,tc_start,{ct_scope_per_group_cth_SUITE,{init_per_group,group1,[]}}},
      {?eh,cth,{'_',id,[[]]}},
      {?eh,cth,{'_',init,['_',[]]}},
      {?eh,cth,{'_',post_init_per_group,[ct_scope_per_group_cth_SUITE,group1, '$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,{init_per_group,group1,[]},ok}},

      {?eh,tc_start,{ct_scope_per_group_cth_SUITE,test_case}},
      {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_per_group_cth_SUITE,test_case,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_testcase,[ct_scope_per_group_cth_SUITE,test_case,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,test_case,ok}},

      {?eh,tc_start,{ct_scope_per_group_cth_SUITE,{end_per_group,group1,[]}}},
      {?eh,cth,{'_',pre_end_per_group,[ct_scope_per_group_cth_SUITE,group1,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_group,[ct_scope_per_group_cth_SUITE,group1,'$proplist','_',[]]}},
      {?eh,cth,{'_',terminate,[[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,{end_per_group,group1,[]},ok}}],

     {?eh,tc_start,{ct_scope_per_group_cth_SUITE,end_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_per_suite_state_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{ct_scope_per_suite_state_cth_SUITE,init_per_suite}},
     {?eh,cth,{'_',id,[[test]]}},
     {?eh,cth,{'_',init,['_',[test]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_scope_per_suite_state_cth_SUITE,'$proplist','$proplist',[test]]}},
     {?eh,tc_done,{ct_scope_per_suite_state_cth_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_scope_per_suite_state_cth_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_per_suite_state_cth_SUITE,test_case,'$proplist',[test]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_scope_per_suite_state_cth_SUITE,test_case,'$proplist',ok,[test]]}},
     {?eh,tc_done,{ct_scope_per_suite_state_cth_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_scope_per_suite_state_cth_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,
	       [ct_scope_per_suite_state_cth_SUITE,'$proplist',[test]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_scope_per_suite_state_cth_SUITE,'$proplist','_',[test]]}},
     {?eh,cth,{'_',terminate,[[test]]}},
     {?eh,tc_done,{ct_scope_per_suite_state_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_suite_state_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',post_groups,['_',[]]}},
     {?eh,cth,{'_',post_all,['_','_',[]]}},
     {?eh,tc_start,{ct_scope_suite_state_cth_SUITE,init_per_suite}},
     {?eh,cth,{'_',id,[[test]]}},
     {?eh,cth,{'_',init,['_',[test]]}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_scope_suite_state_cth_SUITE,'$proplist',[test]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_scope_suite_state_cth_SUITE,'$proplist','$proplist',[test]]}},
     {?eh,tc_done,{ct_scope_suite_state_cth_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_scope_suite_state_cth_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_suite_state_cth_SUITE,test_case,'$proplist',[test]]}},
     {?eh,cth,{'_',post_end_per_testcase,[ct_scope_suite_state_cth_SUITE,test_case,'$proplist',ok,[test]]}},
     {?eh,tc_done,{ct_scope_suite_state_cth_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_scope_suite_state_cth_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_scope_suite_state_cth_SUITE,'$proplist',[test]]}},
     {?eh,cth,{'_',post_end_per_suite,[ct_scope_suite_state_cth_SUITE,'$proplist','_',[test]]}},
     {?eh,cth,{'_',terminate,[[test]]}},
     {?eh,tc_done,{ct_scope_suite_state_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(scope_per_group_state_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{ct_scope_per_group_state_cth_SUITE,init_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_state_cth_SUITE,init_per_suite,ok}},

     [{?eh,tc_start,{ct_scope_per_group_state_cth_SUITE,{init_per_group,group1,[]}}},
      {?eh,cth,{'_',id,[[test]]}},
      {?eh,cth,{'_',init,['_',[test]]}},
      {?eh,cth,{'_',post_init_per_group,[ct_scope_per_group_state_cth_SUITE,group1,'$proplist','$proplist',[test]]}},
      {?eh,tc_done,{ct_scope_per_group_state_cth_SUITE,{init_per_group,group1,[]},ok}},

      {?eh,tc_start,{ct_scope_per_group_state_cth_SUITE,test_case}},
      {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_per_group_state_cth_SUITE,test_case,'$proplist',[test]]}},
      {?eh,cth,{'_',post_end_per_testcase,[ct_scope_per_group_state_cth_SUITE,test_case,'$proplist',ok,[test]]}},
      {?eh,tc_done,{ct_scope_per_group_state_cth_SUITE,test_case,ok}},

      {?eh,tc_start,{ct_scope_per_group_state_cth_SUITE,{end_per_group,group1,[]}}},
      {?eh,cth,{'_',pre_end_per_group,[ct_scope_per_group_state_cth_SUITE,group1,'$proplist',[test]]}},
      {?eh,cth,{'_',post_end_per_group,[ct_scope_per_group_state_cth_SUITE,group1,'$proplist','_',[test]]}},
      {?eh,cth,{'_',terminate,[[test]]}},
      {?eh,tc_done,{ct_scope_per_group_state_cth_SUITE,{end_per_group,group1,[]},ok}}],

     {?eh,tc_start,{ct_scope_per_group_state_cth_SUITE,end_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_state_cth_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(fail_pre_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},

     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist',
					{fail,"Test failure"},[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,
                   {failed, {error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,
	       [ct_cth_empty_SUITE,init_per_suite,"Test failure",[]]}},


     {?eh,tc_auto_skip,{ct_cth_empty_SUITE,test_case,
                        {failed,{ct_cth_empty_SUITE,init_per_suite,
				 {failed,"Test failure"}}}}},
     {?eh,cth,{'_',on_tc_skip,
	       [ct_cth_empty_SUITE,test_case, {tc_auto_skip,
			    {failed, {ct_cth_empty_SUITE, init_per_suite,
				     {failed, "Test failure"}}}},[]]}},


     {?eh,tc_auto_skip, {ct_cth_empty_SUITE, end_per_suite,
                         {failed, {ct_cth_empty_SUITE, init_per_suite,
				   {failed, "Test failure"}}}}},
     {?eh,cth,{'_',on_tc_skip,
	       [ct_cth_empty_SUITE,end_per_suite, {tc_auto_skip,
				{failed, {ct_cth_empty_SUITE, init_per_suite,
					  {failed, "Test failure"}}}},[]]}},


     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth, {'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(double_fail_pre_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{'_',init_per_suite}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth,{'_',pre_init_per_suite,['_','$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,['_','$proplist',
					{fail,"Test failure"},[]]}},
     {?eh,cth, {empty_cth,terminate,[[]]}},

     {?eh,tc_start,{'_',init_per_suite}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth, {empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(fail_post_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,
		   {failed,{error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,[ct_cth_empty_SUITE,init_per_suite, "Test failure", []]}},

     {?eh,tc_auto_skip,{ct_cth_empty_SUITE,test_case,
                        {failed,{ct_cth_empty_SUITE,init_per_suite,
				 {failed,"Test failure"}}}}},
     {?eh,cth,{'_',on_tc_skip,[ct_cth_empty_SUITE,test_case,{tc_auto_skip,'_'},[]]}},

     {?eh,tc_auto_skip, {ct_cth_empty_SUITE, end_per_suite,
                         {failed, {ct_cth_empty_SUITE, init_per_suite,
				   {failed, "Test failure"}}}}},
     {?eh,cth,{'_',on_tc_skip,[ct_cth_empty_SUITE,end_per_suite,{tc_auto_skip,'_'},[]]}},

     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth, {'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(skip_pre_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist',{skip,"Test skip"},[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,{skipped,"Test skip"}}},
     {?eh,cth,{'_',on_tc_skip,
	       [ct_cth_empty_SUITE,init_per_suite,{tc_user_skip,"Test skip"},[]]}},

     {?eh,tc_user_skip,{ct_cth_empty_SUITE,test_case,"Test skip"}},
     {?eh,cth,{'_',on_tc_skip,[ct_cth_empty_SUITE,test_case,{tc_user_skip,"Test skip"},[]]}},

     {?eh,tc_user_skip, {ct_cth_empty_SUITE, end_per_suite,"Test skip"}},

     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth, {'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(skip_pre_end_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{ct_scope_per_group_cth_SUITE,init_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_cth_SUITE,init_per_suite,ok}},

     [{?eh,tc_start,{ct_scope_per_group_cth_SUITE,{init_per_group,group1,[]}}},
      {?eh,cth,{'_',id,[[]]}},
      {?eh,cth,{'_',init,['_',[]]}},
      {?eh,cth,{'_',post_init_per_group,[ct_scope_per_group_cth_SUITE,group1,'$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,{init_per_group,group1,[]},ok}},

      {?eh,tc_start,{ct_scope_per_group_cth_SUITE,test_case}},
      {?eh,cth,{'_',pre_init_per_testcase,[ct_scope_per_group_cth_SUITE,test_case,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_testcase,[ct_scope_per_group_cth_SUITE,test_case,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,test_case,ok}},

      {?eh,tc_start,{ct_scope_per_group_cth_SUITE,{end_per_group,group1,[]}}},
      {?eh,cth,{'_',pre_end_per_group,[ct_scope_per_group_cth_SUITE,group1,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_group,[ct_scope_per_group_cth_SUITE,group1,'$proplist','_',[]]}},
      {?eh,tc_done,{ct_scope_per_group_cth_SUITE,{end_per_group,group1,[]},
		    {skipped,"Test skip"}}}],
      {?eh,cth,{'_',on_tc_skip,[ct_scope_per_group_cth_SUITE,
                                {end_per_group,group1},
				{tc_user_skip,"Test skip"},
				[]]}},
     {?eh,tc_start,{ct_scope_per_group_cth_SUITE,end_per_suite}},
     {?eh,tc_done,{ct_scope_per_group_cth_SUITE,end_per_suite,
		   {skipped,"Test skip"}}},
     {?eh,cth,{'_',on_tc_skip,[ct_scope_per_group_cth_SUITE,
                               end_per_suite,
			       {tc_user_skip,"Test skip"},
			       []]}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(skip_post_suite_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},

     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{'_',post_init_per_suite,[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,{skipped,"Test skip"}}},
     {?eh,cth,{'_',on_tc_skip,
	       [ct_cth_empty_SUITE,init_per_suite,{tc_user_skip,"Test skip"},[]]}},

     {?eh,tc_user_skip,{ct_cth_empty_SUITE,test_case,"Test skip"}},
     {?eh,cth,{'_',on_tc_skip,[ct_cth_empty_SUITE,test_case,{tc_user_skip,"Test skip"},[]]}},

     {?eh,tc_user_skip, {ct_cth_empty_SUITE, end_per_suite,"Test skip"}},

     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(skip_pre_init_tc_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,['_',[]]}},
     {?eh,start_info,{1,1,1}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
               [ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},
     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
               [ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_testcase,
               [ct_cth_empty_SUITE,test_case,'$proplist',
                {skip,"Skipped in pre_init_per_testcase"},
                []]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,
                   {skipped,"Skipped in pre_init_per_testcase"}}},
     {?eh,cth,{empty_cth,on_tc_skip,
               [ct_cth_empty_SUITE,test_case,
                {tc_user_skip,"Skipped in pre_init_per_testcase"},
                []]}},
     {?eh,test_stats,{0,0,{1,0}}},
     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
               [ct_cth_empty_SUITE,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(fail_post_init_tc_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,['_',[]]}},
     {?eh,start_info,{1,1,1}},
     {?eh,tc_start,{ct_fail_init_tc_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,[ct_fail_init_tc_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
               [ct_fail_init_tc_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_fail_init_tc_SUITE,init_per_suite,ok}},
     {?eh,tc_start,{ct_fail_init_tc_SUITE,test_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
               [ct_fail_init_tc_SUITE,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_testcase,
               [ct_fail_init_tc_SUITE,test_case,'$proplist',
                {skip,
                 {failed,
                  {ct_fail_init_tc_SUITE,init_per_testcase,
                   {{test_case_failed,"Failed in init_per_testcase"},'_'}}}},
                []]}},
     {?eh,tc_done,{ct_fail_init_tc_SUITE,test_case,
                   {failed,"Changed skip to fail in post_init_per_testcase"}}},
     {?eh,cth,{empty_cth,on_tc_fail,
               [ct_fail_init_tc_SUITE,test_case,
                "Changed skip to fail in post_init_per_testcase",
                []]}},
     {?eh,test_stats,{0,1,{0,0}}},
     {?eh,tc_start,{ct_fail_init_tc_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,[ct_fail_init_tc_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
               [ct_fail_init_tc_SUITE,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_fail_init_tc_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(recover_post_suite_cth) ->
    Suite = ct_cth_fail_per_suite_SUITE,
    [
     {?eh,start_logging,'_'},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{Suite,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[Suite,'$proplist','$proplist']}},
     {?eh,cth,{'_',post_init_per_suite,[Suite,contains([tc_status]),
					{'EXIT',{'_','_'}},[]]}},
     {?eh,tc_done,{Suite,init_per_suite,ok}},

     {?eh,tc_start,{Suite,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,
	       [Suite,test_case, not_contains([tc_status]),[]]}},
     {?eh,cth,{'_',post_end_per_testcase,
	       [Suite,test_case, contains([tc_status]),'_',[]]}},
     {?eh,tc_done,{Suite,test_case,ok}},

     {?eh,tc_start,{Suite,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,
	       [Suite,not_contains([tc_status]),[]]}},
     {?eh,cth,{'_',post_end_per_suite,
	       [Suite,not_contains([tc_status]),'_',[]]}},
     {?eh,tc_done,{Suite,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(update_config_cth) ->
    Suite = ct_update_config_SUITE,
    TestCaseEvents =
        fun(Case, Result) ->
                [
                 {?eh,tc_start,{Suite,Case}},
                 {?eh,cth,{'_',pre_init_per_testcase,
                           [Suite,
                            Case,contains(
                                        [post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            []]}},
                 {?eh,cth,{'_',post_init_per_testcase,
                           [Suite,
                            Case,contains(
                                        [init_per_testcase,
                                         pre_init_per_testcase,
                                         post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            ok,[]]}},
                 {?eh,cth,{'_',pre_end_per_testcase,
                           [Suite,
                            Case,contains(
                                        [post_init_per_testcase,
                                         init_per_testcase,
                                         pre_init_per_testcase,
                                         post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            []]}},
                 {?eh,cth,{'_',post_end_per_testcase,
                           [Suite,
                            Case,contains(
                                        [pre_end_per_testcase,
                                         post_init_per_testcase,
                                         init_per_testcase,
                                         pre_init_per_testcase,
                                         post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            Result,[]]}},
                 {?eh,tc_done,{Suite,Case,ok}}
                ]
        end,
    update_config_cth_test_events(TestCaseEvents, Suite);
test_events(update_config_cth2) ->
    Suite = ct_update_config_SUITE2,
    TestCaseEvents =
        fun(Case, Result) ->
                {PreEndPerTestcaseHookEventAdd, PostEndPerTestcaseEventAdd} =
                    %% Case below is unexpected thing which needs clarification
                    %% test_case_timetrap should behave the same
                    case lists:member(Case, [test_case_timetrap]) of
                        true ->
                            {[], []};
                        _ ->
                            {
                             [{?eh,cth,{'_',pre_end_per_testcase,
                                        [Suite,
                                         Case,contains(
                                                [post_init_per_testcase,
                                                 %% init_per_testcase,
                                                 pre_init_per_testcase,
                                                 post_init_per_group,
                                                 init_per_group,
                                                 pre_init_per_group,
                                                 post_init_per_suite,
                                                 init_per_suite,
                                                 pre_init_per_suite]),
                                         []]}}], [pre_end_per_testcase]}
                    end,
                [
                 {?eh,tc_start,{Suite,Case}},
                 {?eh,cth,{'_',pre_init_per_testcase,
                           [Suite,
                            Case,contains(
                                        [post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            []]}},
                 {?eh,cth,{'_',post_init_per_testcase,
                           [Suite,
                            Case,contains(
                                        [
                                         %% init_per_testcase,
                                         pre_init_per_testcase,
                                         post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite
                                        ]),
                            ok,[]]}}] ++
                    PreEndPerTestcaseHookEventAdd ++
                 [{?eh,cth,{'_',post_end_per_testcase,
                           [Suite,
                            Case,contains(PostEndPerTestcaseEventAdd ++
                                        [post_init_per_testcase,
                                         %% init_per_testcase,
                                         pre_init_per_testcase,
                                         post_init_per_group,
                                         init_per_group,
                                         pre_init_per_group,
                                         post_init_per_suite,
                                         init_per_suite,
                                         pre_init_per_suite]),
                            Result,[]]}},
                 {?eh,tc_done,{Suite,Case,ok}}
                ]
        end,
    update_config_cth_test_events(TestCaseEvents, Suite);
test_events(ct_hooks_order_test_cth) ->
    Suite = ct_hooks_order_test_SUITE,
    Recipe =
        [{pre_ips_1, [], []},
         {pre_ips_2, [pre_ips_a], []},
         {post_ips_1, [ips, pre_ips_b], pre_ips_2},
         {post_ips_2, [post_ips_a], post_ips_1},
         {pre_ipg_1, [post_ips_b], post_ips_2},
         {pre_ipg_2, [pre_ipg_a], pre_ipg_1},
         {post_ipg_1, [ipg, pre_ipg_b], pre_ipg_2},
         {post_ipg_2, [post_ipg_a], post_ipg_1},
         {pre_ipt_1, [post_ipg_b], post_ipg_2},
         {pre_ipt_2, [pre_ipt_a], pre_ipt_1},
         {post_ipt_1, [ipt, pre_ipt_b], pre_ipt_2},
         {post_ipt_2, [post_ipt_a], post_ipt_1},

         %% "Test centric" (default mode) end functions
         %% Pivot point (testcase) after which hook order is reversed (B hook executed as 1st)
         {pre_ept_1, [post_ipt_b], post_ipt_2},
         {pre_ept_2, [pre_ept_b], pre_ept_1},
         {post_ept_1, [pre_ept_a], pre_ept_2},
         {post_ept_2, [post_ept_b], post_ept_1},
         {pre_epg_1, [], pre_ipt_1},
         {pre_epg_2, [pre_epg_b], pre_epg_1},
         {post_epg_1, [pre_epg_a], pre_epg_2},
         {post_epg_2, [post_epg_b], post_epg_1},
         {pre_eps_1, [], post_ips_2},
         {pre_eps_2, [pre_eps_b], pre_eps_1},
         {post_eps_1, [pre_eps_a], pre_eps_2},
         {post_eps_2, [post_eps_b], post_eps_1}
        ],
    hooks_order_events_helper(Suite, Recipe);
test_events(TC) when TC == ct_hooks_order_config_suite_cth;
                     TC == ct_hooks_order_config_ips_cth ->
    Suite = case TC of
                ct_hooks_order_config_suite_cth ->
                    ct_hooks_order_config_suite_SUITE;
                _ ->
                    ct_hooks_order_config_ips_SUITE
            end,
    Recipe =
        [{pre_ips_1, [], []},
         {pre_ips_2, [pre_ips_a], []},
         %% "Config centric" post functions have reversed execution order (B hook executed 1st)
         {post_ips_1, [ips, pre_ips_b], pre_ips_2},
         {post_ips_2, [post_ips_b], post_ips_1},

         {pre_ipg_1, [post_ips_a], post_ips_2},
         {pre_ipg_2, [pre_ipg_a], pre_ipg_1},
         {post_ipg_1, [ipg, pre_ipg_b], pre_ipg_2},
         {post_ipg_2, [post_ipg_b], post_ipg_1},

         {pre_ipt_1, [post_ipg_a], post_ipg_2},
         {pre_ipt_2, [pre_ipt_a], pre_ipt_1},
         {post_ipt_1, [ipt, pre_ipt_b], pre_ipt_2},
         {post_ipt_2, [post_ipt_b], post_ipt_1},

         {pre_ept_1, [post_ipt_a], post_ipt_2},
         {pre_ept_2, [pre_ept_a], pre_ept_1},
         {post_ept_1, [pre_ept_b], pre_ept_2},
         {post_ept_2, [post_ept_b], post_ept_1},

         {pre_epg_1, [], pre_ipt_1},
         {pre_epg_2, [pre_epg_a], pre_epg_1},
         {post_epg_1, [pre_epg_b], pre_epg_2},
         {post_epg_2, [post_epg_b], post_epg_1},

         {pre_eps_1, [], post_ips_2},
         {pre_eps_2, [pre_eps_a], pre_eps_1},
         {post_eps_1, [pre_eps_b], pre_eps_2},
         {post_eps_2, [post_eps_b], post_eps_1}
        ],
    hooks_order_events_helper(Suite, Recipe);
test_events(state_update_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{'_',init_per_suite}},

     {?eh,tc_done,{'_',end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[contains(
				[post_end_per_suite,pre_end_per_suite,
				 post_end_per_group,pre_end_per_group,
				 {not_in_order,
				  [post_end_per_testcase,pre_init_per_testcase,
				   on_tc_skip,post_end_per_testcase,
				   pre_init_per_testcase,on_tc_fail,
				   post_end_per_testcase,pre_init_per_testcase]
				 },
				 post_init_per_group,pre_init_per_group,
				 post_init_per_suite,pre_init_per_suite,
				 init])]}},
     {?eh,cth,{'_',terminate,[contains(
				[post_end_per_suite,pre_end_per_suite,
				 post_end_per_group,pre_end_per_group,
				 {not_in_order,
				  [post_end_per_testcase,pre_init_per_testcase,
				   on_tc_skip,post_end_per_testcase,
				   pre_init_per_testcase,on_tc_fail,
				   post_end_per_testcase,pre_init_per_testcase]
				 },
				 post_init_per_group,pre_init_per_group,
				 post_init_per_suite,pre_init_per_suite,
				 init]
			       )]}},
     {?eh,stop_logging,[]}
    ];

test_events(update_result_cth) ->
    Suite = ct_cth_update_result_post_end_tc_SUITE,
    [
     {?eh,start_logging,'_'},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{Suite,init_per_suite}},
     {?eh,tc_done,{Suite,init_per_suite,ok}},

     {?eh,tc_start,{Suite,tc_ok_to_fail}},
     {?eh,cth,{'_',post_end_per_testcase,[Suite,tc_ok_to_fail,'_',ok,[]]}},
     {?eh,tc_done,{Suite,tc_ok_to_fail,{failed,{error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,'_'}},
     {?eh,test_stats,{0,1,{0,0}}},

     {?eh,tc_start,{Suite,tc_ok_to_skip}},
     {?eh,cth,{'_',post_end_per_testcase,[Suite,tc_ok_to_skip,'_',ok,[]]}},
     {?eh,tc_done,{Suite,tc_ok_to_skip,{skipped,"Test skipped"}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},
     {?eh,test_stats,{0,1,{1,0}}},

     {?eh,tc_start,{Suite,tc_fail_to_ok}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,tc_fail_to_ok,'_',
                {error,{test_case_failed,"should be changed to ok"}},[]]}},
     {?eh,tc_done,{Suite,tc_fail_to_ok,ok}},
     {?eh,test_stats,{1,1,{1,0}}},

     {?eh,tc_start,{Suite,tc_fail_to_skip}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,tc_fail_to_skip,'_',
                {error,{test_case_failed,"should be changed to skip"}},[]]}},
     {?eh,tc_done,{Suite,tc_fail_to_skip,{skipped,"Test skipped"}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},
     {?eh,test_stats,{1,1,{2,0}}},

     {?eh,tc_start,{Suite,tc_timetrap_to_ok}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,tc_timetrap_to_ok,'_',{timetrap_timeout,3000},[]]}},
     {?eh,tc_done,{Suite,tc_timetrap_to_ok,ok}},
     {?eh,test_stats,{2,1,{2,0}}},

     {?eh,tc_start,{Suite,tc_timetrap_to_skip}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,tc_timetrap_to_skip,'_',{timetrap_timeout,3000},[]]}},
     {?eh,tc_done,{Suite,tc_timetrap_to_skip,{skipped,"Test skipped"}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},
     {?eh,test_stats,{2,1,{3,0}}},

     {?eh,tc_start,{Suite,tc_skip_to_fail}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,tc_skip_to_fail,'_',
                {skip,"should be changed to fail"},[]]}},
     {?eh,tc_done,{Suite,tc_skip_to_fail,{failed,{error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,'_'}},
     {?eh,test_stats,{2,2,{3,0}}},

     {?eh,tc_start,{Suite,end_fail_to_fail}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,end_fail_to_fail,'_',
                {failed,
                 {Suite,end_per_testcase,
                  {'EXIT',{test_case_failed,"change result when end fails"}}}},[]]}},
     {?eh,tc_done,{Suite,end_fail_to_fail,{failed,{error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,'_'}},
     {?eh,test_stats,{2,3,{3,0}}},

     {?eh,tc_start,{Suite,end_fail_to_skip}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,end_fail_to_skip,'_',
                {failed,
                 {Suite,end_per_testcase,
                  {'EXIT',{test_case_failed,"change result when end fails"}}}},[]]}},
     {?eh,tc_done,{Suite,end_fail_to_skip,{skipped,"Test skipped"}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},
     {?eh,test_stats,{2,3,{4,0}}},

     {?eh,tc_start,{Suite,end_timetrap_to_fail}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,end_timetrap_to_fail,'_',
                {failed,{Suite,end_per_testcase,{timetrap_timeout,3000}}},[]]}},
     {?eh,tc_done,{Suite,end_timetrap_to_fail,{failed,{error,"Test failure"}}}},
     {?eh,cth,{'_',on_tc_fail,'_'}},
     {?eh,test_stats,{2,4,{4,0}}},

     {?eh,tc_start,{Suite,end_timetrap_to_skip}},
     {?eh,cth,{'_',post_end_per_testcase,
               [Suite,end_timetrap_to_skip,'_',
                {failed,{Suite,end_per_testcase,{timetrap_timeout,3000}}},[]]}},
     {?eh,tc_done,{Suite,end_timetrap_to_skip,{skipped,"Test skipped"}}},
     {?eh,cth,{'_',on_tc_skip,'_'}},
     {?eh,test_stats,{2,4,{5,0}}},

     {?eh,tc_start,{Suite,end_per_suite}},
     {?eh,tc_done,{Suite,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(options_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,['_',[test]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_cth_empty_SUITE,'$proplist',[test]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_cth_empty_SUITE,'$proplist','$proplist',[test]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[test]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist','_',[test]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_cth_empty_SUITE,'$proplist',[test]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[test]]}},
     {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[test]]}},
     {?eh,stop_logging,[]}
    ];

test_events(same_id_cth) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',id,[[]]}},
     {?eh,cth,{'_',init,[same_id_cth,[]]}},
     {?eh,tc_start,{ct_cth_empty_SUITE,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {negative,
       {?eh,cth,{'_',pre_init_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
      {?eh,cth,{'_',post_init_per_suite,
		[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}}},
     {negative,
      {?eh,cth,{'_',post_init_per_suite,
		[ct_cth_empty_SUITE,'$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_cth_empty_SUITE,init_per_suite,ok}}},

     {?eh,tc_start,{ct_cth_empty_SUITE,test_case}},
     {?eh,cth,{'_',pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
     {negative,
      {?eh,cth,{'_',pre_init_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',ok,[]]}}},
     {negative,
      {?eh,cth,{'_',post_end_per_testcase,[ct_cth_empty_SUITE,test_case,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_cth_empty_SUITE,test_case,ok}}},

     {?eh,tc_start,{ct_cth_empty_SUITE,end_per_suite}},
     {?eh,cth,{'_',pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
     {negative,
      {?eh,cth,{'_',pre_end_per_suite,[ct_cth_empty_SUITE,'$proplist',[]]}},
      {?eh,cth,{'_',post_end_per_suite,[ct_cth_empty_SUITE,'$proplist','_',[]]}}},
     {negative,
      {?eh,cth,{'_',post_end_per_suite,
		[ct_cth_empty_SUITE,'$proplist','_',[]]}},
      {?eh,tc_done,{ct_cth_empty_SUITE,end_per_suite,ok}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(fail_n_skip_with_minimal_cth) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},
     {?eh,tc_start,{'_',init_per_suite}},

     {parallel,
      [{?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,{init_per_group,
						      group1,[parallel]}}},
       {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,{init_per_group,
						     group1,[parallel]},ok}},
       {parallel,
	[{?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,{init_per_group,
							group2,[parallel]}}},
	 {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,{init_per_group,
						       group2,[parallel]},ok}},
	 %% Verify that 'skip' as well as 'skipped' works
	 {?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,test_case2}},
	 {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,test_case2,{skipped,"skip it"}}},
	 {?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,test_case3}},
	 {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,test_case3,{skipped,"skip it"}}},
	 {?eh,cth,{empty_cth,on_tc_skip,[ct_cth_fail_one_skip_one_SUITE,
                                         {test_case2,group2},
					 {tc_user_skip,"skip it"},
					 []]}},
	 {?eh,cth,{empty_cth,on_tc_skip,[ct_cth_fail_one_skip_one_SUITE,
                                         {test_case3,group2},
					 {tc_user_skip,"skip it"},
					 []]}},
	 {?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,{end_per_group,
							group2,[parallel]}}},
	 {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,{end_per_group,group2,
						       [parallel]},ok}}]},
       {?eh,tc_start,{ct_cth_fail_one_skip_one_SUITE,{end_per_group,
						      group1,[parallel]}}},
       {?eh,tc_done,{ct_cth_fail_one_skip_one_SUITE,{end_per_group,
						     group1,[parallel]},ok}}]},

     {?eh,tc_done,{'_',end_per_suite,ok}},
     {?eh,cth,{'_',terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(prio_cth) ->
    GenPre = fun(Func,States) when Func==pre_init_per_suite;
                                   Func==pre_end_per_suite ->
		     [{?eh,cth,{'_',Func,['_','_',State]}} ||
                         State <- States];
                (Func,States) ->
		     [{?eh,cth,{'_',Func,['_','_','_',State]}} ||
			 State <- States]
	     end,

    GenPost = fun(Func,States) when Func==post_init_per_suite;
                                    Func==post_end_per_suite ->
		      [{?eh,cth,{'_',Func,['_','_','_',State]}} ||
			  State <- States];
                 (Func,States) ->
		      [{?eh,cth,{'_',Func,['_','_','_','_',State]}} ||
			  State <- States]

              end,

    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}}] ++

	[{?eh,tc_start,{ct_cth_prio_SUITE,init_per_suite}}] ++
	GenPre(pre_init_per_suite,
	       [[1100,100],[800],[900],[1000],[1200,1050],[1100],[1200]]) ++
	GenPost(post_init_per_suite,
		[[1100,100],[600,200],[600,600],[700],[800],[900],[1000],
		 [1200,1050],[1100],[1200]]) ++
	[{?eh,tc_done,{ct_cth_prio_SUITE,init_per_suite,ok}},


	 [{?eh,tc_start,{ct_cth_prio_SUITE,{init_per_group,'_',[]}}}] ++
	     GenPre(pre_init_per_group,
		    [[1100,100],[600,200],[600,600],[700],[800],
		     [900],[1000],[1200,1050],[1100],[1200]]) ++
	     GenPost(post_init_per_group,
		     [[1100,100],[600,200],[600,600],[600],[700],[800],
		      [900],[900,900],[500,900],[1000],[1200,1050],
		      [1100],[1200]]) ++
	     [{?eh,tc_done,{ct_cth_prio_SUITE,{init_per_group,'_',[]},ok}}] ++

	     [{?eh,tc_start,{ct_cth_prio_SUITE,test_case}}] ++
	     GenPre(pre_init_per_testcase,
		    [[1100,100],[600,200],[600,600],[600],[700],[800],
		     [900],[900,900],[500,900],[1000],[1200,1050],
		     [1100],[1200]]) ++
	     GenPost(post_end_per_testcase,
		     lists:reverse(
		       [[1100,100],[600,200],[600,600],[600],[700],[800],
			[900],[900,900],[500,900],[1000],[1200,1050],
			[1100],[1200]])) ++
	     [{?eh,tc_done,{ct_cth_prio_SUITE,test_case,ok}},

	      {?eh,tc_start,{ct_cth_prio_SUITE,{end_per_group,'_',[]}}}] ++
	     GenPre(pre_end_per_group,
		    lists:reverse(
		      [[1100,100],[600,200],[600,600],[600],[700],[800],
		       [900],[900,900],[500,900],[1000],[1200,1050],
		       [1100],[1200]])) ++
	     GenPost(post_end_per_group,
		     lists:reverse(
		       [[1100,100],[600,200],[600,600],[600],[700],[800],
			[900],[900,900],[500,900],[1000],[1200,1050],
			[1100],[1200]])) ++
	     [{?eh,tc_done,{ct_cth_prio_SUITE,{end_per_group,'_',[]},ok}}],

	 {?eh,tc_start,{ct_cth_prio_SUITE,end_per_suite}}] ++
	GenPre(pre_end_per_suite,
	       lists:reverse(
		 [[1100,100],[600,200],[600,600],[700],[800],[900],[1000],
		  [1200,1050],[1100],[1200]])) ++
	GenPost(post_end_per_suite,
		lists:reverse(
		  [[1100,100],[600,200],[600,600],[700],[800],[900],[1000],
		   [1200,1050],[1100],[1200]])) ++
	[{?eh,tc_done,{ct_cth_prio_SUITE,end_per_suite,ok}},
	 {?eh,test_done,{'DEF','STOP_TIME'}},
	 {?eh,stop_logging,[]}];

test_events(no_config) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,[verify_config_cth,[]]}},
     {?eh,start_info,{1,1,2}},
     {?eh,tc_start,{ct_framework,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_no_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_no_config_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_framework,init_per_suite,ok}},
     {?eh,tc_start,{ct_no_config_SUITE,test_case_1}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
	       [ct_no_config_SUITE,test_case_1,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,
	       [ct_no_config_SUITE,test_case_1,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_no_config_SUITE,test_case_1,ok}},
     {?eh,test_stats,{1,0,{0,0}}},
     [{?eh,tc_start,{ct_framework,{init_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_init_per_group,
		[ct_no_config_SUITE,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_init_per_group,
		[ct_no_config_SUITE,test_group,'$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_framework,
		    {init_per_group,test_group,'$proplist'},ok}},
      {?eh,tc_start,{ct_no_config_SUITE,test_case_2}},
      {?eh,cth,{empty_cth,pre_init_per_testcase,
		[ct_no_config_SUITE,test_case_2,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_testcase,
		[ct_no_config_SUITE,test_case_2,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_no_config_SUITE,test_case_2,ok}},
      {?eh,test_stats,{2,0,{0,0}}},
      {?eh,tc_start,{ct_framework,{end_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_end_per_group,
		[ct_no_config_SUITE,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_group,
		[ct_no_config_SUITE,test_group,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_framework,{end_per_group,test_group,'$proplist'},ok}}],
     {?eh,tc_start,{ct_framework,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_no_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
	       [ct_no_config_SUITE,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_framework,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(no_init_suite_config) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,start_info,{1,1,1}},
     {?eh,tc_start,{ct_no_init_suite_config_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_no_init_suite_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_no_init_suite_config_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_no_init_suite_config_SUITE,init_per_suite,
                   {failed,{error,{undef,'_'}}}}},
     {?eh,cth,{empty_cth,on_tc_fail,[ct_no_init_suite_config_SUITE,
                                     init_per_suite,
                                     {undef,'_'},[]]}},
      {?eh,tc_auto_skip,{ct_no_init_suite_config_SUITE,test_case,
                         {failed,{ct_no_init_suite_config_SUITE,init_per_suite,
                                  {'EXIT',{undef,'_'}}}}}},
     {?eh,cth,{empty_cth,on_tc_skip,
               [ct_no_init_suite_config_SUITE,
                test_case,
                {tc_auto_skip,
                 {failed,{ct_no_init_suite_config_SUITE,init_per_suite,
                          {'EXIT',{undef,'_'}}}}},
                []]}},
     {?eh,test_stats,{0,0,{0,1}}},
     {?eh,tc_auto_skip,{ct_no_init_suite_config_SUITE,end_per_suite,
                        {failed,{ct_no_init_suite_config_SUITE,init_per_suite,
                                 {'EXIT',{undef,'_'}}}}}},
     {?eh,cth,{empty_cth,on_tc_skip,
               [ct_no_init_suite_config_SUITE,
                end_per_suite,
                {tc_auto_skip,
                 {failed,{ct_no_init_suite_config_SUITE,init_per_suite,
                          {'EXIT',{undef,'_'}}}}},
                []]}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(no_init_config) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,start_info,{1,1,2}},
     {?eh,tc_start,{ct_no_init_config_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_no_init_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_no_init_config_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_no_init_config_SUITE,init_per_suite,ok}},
     {?eh,tc_start,{ct_no_init_config_SUITE,test_case_1}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
	       [ct_no_init_config_SUITE,test_case_1,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,
	       [ct_no_init_config_SUITE,test_case_1,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_no_init_config_SUITE,test_case_1,ok}},
     {?eh,test_stats,{1,0,{0,0}}},
     [{?eh,tc_start,{ct_no_init_config_SUITE,{init_per_group,test_group,[]}}},
      {?eh,cth,{empty_cth,pre_init_per_group,
		[ct_no_init_config_SUITE,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_init_per_group,
		[ct_no_init_config_SUITE,test_group,'$proplist','_',[]]}},
      {?eh,tc_done,{ct_no_init_config_SUITE,{init_per_group,test_group,[]},
                    {failed,{error,{undef,'_'}}}}},
      {?eh,cth,{empty_cth,on_tc_fail,[ct_no_init_config_SUITE,
                                      {init_per_group,test_group},
                                      {undef,'_'},[]]}},
      {?eh,tc_auto_skip,{ct_no_init_config_SUITE,{test_case_2,test_group},
                         {failed,{ct_no_init_config_SUITE,init_per_group,
                                  {'EXIT',{undef,'_'}}}}}},
      {?eh,cth,{empty_cth,on_tc_skip,[ct_no_init_config_SUITE,
                                      {test_case_2,test_group},
                                      {tc_auto_skip,
                                       {failed,
                                        {ct_no_init_config_SUITE,init_per_group,
                                         {'EXIT',{undef,'_'}}}}},
                                       []]}},
      {?eh,test_stats,{1,0,{0,1}}},
      {?eh,tc_auto_skip,{ct_no_init_config_SUITE,{end_per_group,test_group},
                         {failed,{ct_no_init_config_SUITE,init_per_group,
                                  {'EXIT',{undef,'_'}}}}}},
      {?eh,cth,{empty_cth,on_tc_skip,[ct_no_init_config_SUITE,
                                      {end_per_group,test_group},
                                      {tc_auto_skip,
                                       {failed,
                                        {ct_no_init_config_SUITE,init_per_group,
                                         {'EXIT',{undef,'_'}}}}},
                                       []]}}],
     {?eh,tc_start,{ct_no_init_config_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_no_init_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
	       [ct_no_init_config_SUITE,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_no_init_config_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(no_end_config) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,start_info,{1,1,2}},
     {?eh,tc_start,{ct_no_end_config_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_no_end_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_no_end_config_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{ct_no_end_config_SUITE,init_per_suite,ok}},
     {?eh,tc_start,{ct_no_end_config_SUITE,test_case_1}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
	       [ct_no_end_config_SUITE,test_case_1,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,
	       [ct_no_end_config_SUITE,test_case_1,'$proplist',ok,[]]}},
     {?eh,tc_done,{ct_no_end_config_SUITE,test_case_1,ok}},
     {?eh,test_stats,{1,0,{0,0}}},
     [{?eh,tc_start,{ct_no_end_config_SUITE,
                     {init_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_init_per_group,
		[ct_no_end_config_SUITE,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_init_per_group,
		[ct_no_end_config_SUITE,test_group,'$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_no_end_config_SUITE,
		    {init_per_group,test_group,'$proplist'},ok}},
      {?eh,tc_start,{ct_no_end_config_SUITE,test_case_2}},
      {?eh,cth,{empty_cth,pre_init_per_testcase,
		[ct_no_end_config_SUITE,test_case_2,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_testcase,
		[ct_no_end_config_SUITE,test_case_2,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_no_end_config_SUITE,test_case_2,ok}},
      {?eh,test_stats,{2,0,{0,0}}},
      {?eh,tc_start,{ct_no_end_config_SUITE,
                     {end_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_end_per_group,
		[ct_no_end_config_SUITE,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_group,
		[ct_no_end_config_SUITE,test_group,'$proplist','_',[]]}},
      {?eh,tc_done,{ct_no_end_config_SUITE,{end_per_group,test_group,[]},
                    {failed,{error,{undef,'_'}}}}},
      {?eh,cth,{empty_cth,on_tc_fail,[ct_no_end_config_SUITE,
                                      {end_per_group,test_group},
                                      {undef,'_'},[]]}}],
     {?eh,tc_start,{ct_no_end_config_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_no_end_config_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
	       [ct_no_end_config_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{ct_no_end_config_SUITE,end_per_suite,
                   {failed,{error,{undef,'_'}}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(data_dir) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,init,[verify_data_dir_cth,[]]}},
     {?eh,start_info,{1,1,2}},
     {?eh,tc_start,{ct_framework,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [ct_data_dir_SUITE,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [ct_data_dir_SUITE,'$proplist','$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,tc_done,{ct_framework,init_per_suite,ok}},
     {?eh,tc_start,{ct_data_dir_SUITE,test_case_1}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
	       [ct_data_dir_SUITE,test_case_1,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,
	       [ct_data_dir_SUITE,test_case_1,'$proplist',ok,[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,tc_done,{ct_data_dir_SUITE,test_case_1,ok}},
     {?eh,test_stats,{1,0,{0,0}}},
     [{?eh,tc_start,{ct_framework,{init_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_init_per_group,
		[ct_data_dir_SUITE,test_group,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,cth,{empty_cth,post_init_per_group,
		[ct_data_dir_SUITE,test_group,'$proplist','$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,tc_done,{ct_framework,
		    {init_per_group,test_group,'$proplist'},ok}},
      {?eh,tc_start,{ct_data_dir_SUITE,test_case_2}},
      {?eh,cth,{empty_cth,pre_init_per_testcase,
		[ct_data_dir_SUITE,test_case_2,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,cth,{empty_cth,post_end_per_testcase,
		[ct_data_dir_SUITE,test_case_2,'$proplist',ok,[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,tc_done,{ct_data_dir_SUITE,test_case_2,ok}},
      {?eh,test_stats,{2,0,{0,0}}},
      {?eh,tc_start,{ct_framework,{end_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_end_per_group,
		[ct_data_dir_SUITE,test_group,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,cth,{empty_cth,post_end_per_group,
		[ct_data_dir_SUITE,test_group,'$proplist',ok,[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
      {?eh,tc_done,{ct_framework,{end_per_group,test_group,'$proplist'},ok}}],
     {?eh,tc_start,{ct_framework,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [ct_data_dir_SUITE,'$proplist',[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
	       [ct_data_dir_SUITE,'$proplist',ok,[{data_dir_name,"ct_data_dir_SUITE_data"}]]}},
     {?eh,tc_done,{ct_framework,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(cth_log) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{cth_log_SUITE,init_per_suite}},

     {?eh,tc_start,{ct_framework,{init_per_group,g1,
                                  [{suite,cth_log_SUITE}]}}},
     {?eh,tc_done,{ct_framework,{init_per_group,g1,
                                 [{suite,cth_log_SUITE}]},ok}},
     {?eh,test_stats,{30,0,{0,0}}},
     {?eh,tc_start,{ct_framework,{end_per_group,g1,
                                  [{suite,cth_log_SUITE}]}}},
     {?eh,tc_done,{ct_framework,{end_per_group,g1,
                                 [{suite,cth_log_SUITE}]},ok}},

     {?eh,tc_done,{cth_log_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(cth_log_formatter) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{cth_log_formatter_SUITE,init_per_suite}},

     {?eh,tc_start,{ct_framework,{init_per_group,g1,
                                  [{suite,cth_log_formatter_SUITE}]}}},
     {?eh,tc_done,{ct_framework,{init_per_group,g1,
                                 [{suite,cth_log_formatter_SUITE}]},ok}},
     {?eh,test_stats,{30,0,{0,0}}},
     {?eh,tc_start,{ct_framework,{end_per_group,g1,
                                  [{suite,cth_log_formatter_SUITE}]}}},
     {?eh,tc_done,{ct_framework,{end_per_group,g1,
                                 [{suite,cth_log_formatter_SUITE}]},ok}},

     {?eh,tc_done,{cth_log_formatter_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(cth_log_unexpect) ->
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,tc_start,{cth_log_unexpect_SUITE,init_per_suite}},

     {parallel,
      [{?eh,tc_start,{ct_framework,{init_per_group,g1,
				    [{suite,cth_log_unexpect_SUITE},parallel]}}},
       {?eh,tc_done,{ct_framework,{init_per_group,g1,
				   [{suite,cth_log_unexpect_SUITE},parallel]},ok}},
       {?eh,test_stats,{30,0,{0,0}}},
       {?eh,tc_start,{ct_framework,{end_per_group,g1,
				    [{suite,cth_log_unexpect_SUITE},parallel]}}},
       {?eh,tc_done,{ct_framework,{end_per_group,g1,
				   [{suite,cth_log_unexpect_SUITE},parallel]},ok}}]},

     {?eh,tc_done,{cth_log_unexpect_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ];

test_events(fallback) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,tc_start,{all_hook_callbacks_SUITE,init_per_suite}},
     {?eh,cth,{empty_cth,pre_init_per_suite,
	       [all_hook_callbacks_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_suite,
	       [all_hook_callbacks_SUITE,'$proplist','$proplist',[]]}},
     {?eh,tc_done,{all_hook_callbacks_SUITE,init_per_suite,ok}},

     [{?eh,tc_start,{ct_framework,{init_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_init_per_group,
		[fallback_nosuite,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_init_per_group,
		[fallback_nosuite,test_group,'$proplist','$proplist',[]]}},
      {?eh,tc_done,{ct_framework,
		    {init_per_group,test_group,'$proplist'},ok}},
      {?eh,tc_start,{all_hook_callbacks_SUITE,test_case}},
      {?eh,cth,{empty_cth,pre_init_per_testcase,
		[fallback_nosuite,test_case,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_testcase,
		[fallback_nosuite,test_case,'$proplist',ok,[]]}},
      {?eh,tc_done,{all_hook_callbacks_SUITE,test_case,ok}},
      {?eh,test_stats,{1,0,{0,0}}},
      {?eh,tc_start,{ct_framework,{end_per_group,test_group,'$proplist'}}},
      {?eh,cth,{empty_cth,pre_end_per_group,
		[fallback_nosuite,test_group,'$proplist',[]]}},
      {?eh,cth,{empty_cth,post_end_per_group,
		[fallback_nosuite,test_group,'$proplist',ok,[]]}},
      {?eh,tc_done,{ct_framework,{end_per_group,test_group,'$proplist'},ok}}],
     {?eh,tc_start,{all_hook_callbacks_SUITE,test_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
               [fallback_nosuite,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_testcase,
               [fallback_nosuite,test_case,'$proplist','_',[]]}},
     {?eh,cth,{empty_cth,pre_end_per_testcase,
               [fallback_nosuite,test_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_testcase,
               [fallback_nosuite,test_case,'$proplist','_',[]]}},
     {?eh,tc_done,{all_hook_callbacks_SUITE,test_case,ok}},
     {?eh,test_stats,{2,0,{0,0}}},
     {?eh,tc_start,{all_hook_callbacks_SUITE,skip_case}},
     {?eh,cth,{empty_cth,pre_init_per_testcase,
               [fallback_nosuite,skip_case,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_init_per_testcase,
               [fallback_nosuite,skip_case,'$proplist',
                {skip,"Skipped in init_per_testcase/2"},[]]}},
     {?eh,tc_done,{all_hook_callbacks_SUITE,skip_case,
                   {skipped,"Skipped in init_per_testcase/2"}}},
     {?eh,cth,{empty_cth,on_tc_skip,
               [fallback_nosuite,skip_case,
                {tc_user_skip,"Skipped in init_per_testcase/2"},
                []]}},
     {?eh,test_stats,{2,0,{1,0}}},
     {?eh,tc_start,{all_hook_callbacks_SUITE,end_per_suite}},
     {?eh,cth,{empty_cth,pre_end_per_suite,
	       [all_hook_callbacks_SUITE,'$proplist',[]]}},
     {?eh,cth,{empty_cth,post_end_per_suite,
               [all_hook_callbacks_SUITE,'$proplist','_',[]]}},
     {?eh,tc_done,{all_hook_callbacks_SUITE,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(callbacks_on_skip) ->
    %% skip_cth.erl will send a 'cth_error' event if a hook is
    %% erroneously called. Therefore, all Events are changed to
    %% {negative,{?eh,cth_error,'_'},Event}
    %% at the end of this function.
    Events =
        [
         {?eh,start_logging,{'DEF','RUNDIR'}},
         {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
         {?eh,cth,{empty_cth,id,[[]]}},
         {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
         {?eh,start_info,{6,6,15}},

         %% all_hook_callbacks_SUITE is skipped in spec
         %% Only the on_tc_skip callback shall be called
         {?eh,tc_user_skip,{all_hook_callbacks_SUITE,all,"Skipped in spec"}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [all_hook_callbacks_SUITE,all,
                    {tc_user_skip,"Skipped in spec"},
                    []]}},
         {?eh,test_stats,{0,0,{1,0}}},

         %% skip_init_SUITE is skipped in its init_per_suite function
         %% No group- or testcase-functions shall be called.
         {?eh,tc_start,{skip_init_SUITE,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,
                   [skip_init_SUITE,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [skip_init_SUITE,
                    '$proplist',
                    {skip,"Skipped in init_per_suite/1"},
                    []]}},
         {?eh,tc_done,{skip_init_SUITE,init_per_suite,
                       {skipped,"Skipped in init_per_suite/1"}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_init_SUITE,init_per_suite,
                    {tc_user_skip,"Skipped in init_per_suite/1"},
                    []]}},
         {?eh,tc_user_skip,{skip_init_SUITE,test_case,"Skipped in init_per_suite/1"}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_init_SUITE,test_case,
                    {tc_user_skip,"Skipped in init_per_suite/1"},
                    []]}},
         {?eh,test_stats,{0,0,{2,0}}},
         {?eh,tc_user_skip,{skip_init_SUITE,end_per_suite,
                            "Skipped in init_per_suite/1"}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_init_SUITE,end_per_suite,
                    {tc_user_skip,"Skipped in init_per_suite/1"},
                    []]}},

         %% skip_req_SUITE is auto-skipped since a 'require' statement
         %% returned by suite/0 is not fulfilled.
         %% No group- or testcase-functions shall be called.
         {?eh,tc_start,{skip_req_SUITE,init_per_suite}},
         {?eh,tc_done,{skip_req_SUITE,init_per_suite,
                       {auto_skipped,{require_failed_in_suite0,
                                      {not_available,whatever}}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_req_SUITE,init_per_suite,
                    {tc_auto_skip,{require_failed_in_suite0,
                                   {not_available,whatever}}},
                    []]}},
         {?eh,tc_auto_skip,{skip_req_SUITE,test_case,{require_failed_in_suite0,
                                                      {not_available,whatever}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_req_SUITE,test_case,
                    {tc_auto_skip,{require_failed_in_suite0,
                                   {not_available,whatever}}},
                    []]}},
         {?eh,test_stats,{0,0,{2,1}}},
         {?eh,tc_auto_skip,{skip_req_SUITE,end_per_suite,
                            {require_failed_in_suite0,
                             {not_available,whatever}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_req_SUITE,end_per_suite,
                    {tc_auto_skip,{require_failed_in_suite0,
                                   {not_available,whatever}}},
                    []]}},

         %% skip_fail_SUITE is auto-skipped since the suite/0 function
         %% returns a faluty format.
         %% No group- or testcase-functions shall be called.
         {?eh,tc_start,{skip_fail_SUITE,init_per_suite}},
         {?eh,tc_done,{skip_fail_SUITE,init_per_suite,
                       {failed,{error,{suite0_failed,bad_return_value}}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_fail_SUITE,init_per_suite,
                    {tc_auto_skip,
                     {failed,{error,{suite0_failed,bad_return_value}}}},
                    []]}},
         {?eh,tc_auto_skip,{skip_fail_SUITE,test_case,
                            {failed,{error,{suite0_failed,bad_return_value}}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_fail_SUITE,test_case,
                    {tc_auto_skip,
                     {failed,{error,{suite0_failed,bad_return_value}}}},
                    []]}},
         {?eh,test_stats,{0,0,{2,2}}},
         {?eh,tc_auto_skip,{skip_fail_SUITE,end_per_suite,
                            {failed,{error,{suite0_failed,bad_return_value}}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_fail_SUITE,end_per_suite,
                    {tc_auto_skip,
                     {failed,{error,{suite0_failed,bad_return_value}}}},
                    []]}},

         %% skip_group_SUITE
         {?eh,tc_start,{skip_group_SUITE,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,
                   [skip_group_SUITE,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [skip_group_SUITE,
                    '$proplist',
                    '_',
                    []]}},
         {?eh,tc_done,{skip_group_SUITE,init_per_suite,ok}},

         %% test_group_1 - auto_skip due to require failed
         [{?eh,tc_start,{skip_group_SUITE,{init_per_group,test_group_1,[]}}},
          {?eh,tc_done,
           {skip_group_SUITE,{init_per_group,test_group_1,[]},
            {auto_skipped,{require_failed,{not_available,whatever}}}}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {init_per_group,test_group_1},
                     {tc_auto_skip,{require_failed,{not_available,whatever}}},
                     []]}},
          {?eh,tc_auto_skip,{skip_group_SUITE,{test_case,test_group_1},
                             {require_failed,{not_available,whatever}}}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {test_case,test_group_1},
                     {tc_auto_skip,{require_failed,{not_available,whatever}}},
                     []]}},
          {?eh,test_stats,{0,0,{2,3}}},
          {?eh,tc_auto_skip,{skip_group_SUITE,{end_per_group,test_group_1},
                             {require_failed,{not_available,whatever}}}}],
         %% The following appears to be outside of the group, but
         %% that's only an implementation detail in
         %% ct_test_support.erl - it does not know about events from
         %% test suite specific hooks and regards the group ended with
         %% the above tc_auto_skip-event for end_per_group.
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_group_SUITE,
                    {end_per_group,test_group_1},
                    {tc_auto_skip,{require_failed,{not_available,whatever}}},
                    []]}},

         %% test_group_2 - auto_skip due to failed return from group/1
         [{?eh,tc_start,{skip_group_SUITE,{init_per_group,test_group_2,[]}}},
          {?eh,tc_done,
           {skip_group_SUITE,{init_per_group,test_group_2,[]},
            {auto_skipped,{group0_failed,bad_return_value}}}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {init_per_group,test_group_2},
                     {tc_auto_skip,{group0_failed,bad_return_value}},
                     []]}},
          {?eh,tc_auto_skip,{skip_group_SUITE,{test_case,test_group_2},
                             {group0_failed,bad_return_value}}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {test_case,test_group_2},
                     {tc_auto_skip,{group0_failed,bad_return_value}},
                     []]}},
          {?eh,test_stats,{0,0,{2,4}}},
          {?eh,tc_auto_skip,{skip_group_SUITE,{end_per_group,test_group_2},
                             {group0_failed,bad_return_value}}}],
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_group_SUITE,
                    {end_per_group,test_group_2},
                    {tc_auto_skip,{group0_failed,bad_return_value}},
                    []]}},
         %% test_group_3 - user_skip in init_per_group/2
         [{?eh,tc_start,
           {skip_group_SUITE,{init_per_group,test_group_3,[]}}},
          {?eh,cth,{empty_cth,pre_init_per_group,
                    [skip_group_SUITE,test_group_3,'$proplist',[]]}},
          {?eh,cth,{empty_cth,post_init_per_group,
                    [skip_group_SUITE,test_group_3,'$proplist',
                     {skip,"Skipped in init_per_group/2"},
                     []]}},
          {?eh,tc_done,{skip_group_SUITE,
                        {init_per_group,test_group_3,[]},
                        {skipped,"Skipped in init_per_group/2"}}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {init_per_group,test_group_3},
                     {tc_user_skip,"Skipped in init_per_group/2"},
                     []]}},
          {?eh,tc_user_skip,{skip_group_SUITE,
                             {test_case,test_group_3},
                             "Skipped in init_per_group/2"}},
          {?eh,cth,{empty_cth,on_tc_skip,
                    [skip_group_SUITE,
                     {test_case,test_group_3},
                     {tc_user_skip,"Skipped in init_per_group/2"},
                     []]}},
          {?eh,test_stats,{0,0,{3,4}}},
          {?eh,tc_user_skip,{skip_group_SUITE,
                             {end_per_group,test_group_3},
                             "Skipped in init_per_group/2"}}],
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_group_SUITE,
                    {end_per_group,test_group_3},
                    {tc_user_skip,"Skipped in init_per_group/2"},
                    []]}},

         {?eh,tc_start,{skip_group_SUITE,end_per_suite}},
         {?eh,cth,{empty_cth,pre_end_per_suite,
                   [skip_group_SUITE,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_end_per_suite,
                   [skip_group_SUITE,
                    '$proplist',
                    ok,[]]}},
         {?eh,tc_done,{skip_group_SUITE,end_per_suite,ok}},


         %% skip_case_SUITE has 4 test cases which are all skipped in
         %% different ways
         {?eh,tc_start,{skip_case_SUITE,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,
                   [skip_case_SUITE,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [skip_case_SUITE,
                    '$proplist',
                    '_',
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,init_per_suite,ok}},

         %% Skip in spec -> only on_tc_skip shall be called
         {?eh,tc_user_skip,{skip_case_SUITE,skip_in_spec,"Skipped in spec"}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,skip_in_spec,
                    {tc_user_skip,"Skipped in spec"},
                    []]}},
         {?eh,test_stats,{0,0,{4,4}}},

         %% Skip in init_per_testcase -> pre/post_end_per_testcase
         %% shall not be called
         {?eh,tc_start,{skip_case_SUITE,skip_in_init}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,skip_in_init,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,skip_in_init,
                    '$proplist',
                    {skip,"Skipped in init_per_testcase/2"},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,skip_in_init,
                       {skipped,"Skipped in init_per_testcase/2"}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,skip_in_init,
                    {tc_user_skip,"Skipped in init_per_testcase/2"},
                    []]}},
         {?eh,test_stats,{0,0,{5,4}}},

         %% Fail in init_per_testcase -> pre/post_end_per_testcase
         %% shall not be called
         {?eh,tc_start,{skip_case_SUITE,fail_in_init}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,fail_in_init,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,fail_in_init,
                    '$proplist',
                    {skip,{failed,'_'}},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,fail_in_init,
                       {auto_skipped,{failed,'_'}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,fail_in_init,
                    {tc_auto_skip,{failed,'_'}},
                    []]}},
         {?eh,test_stats,{0,0,{5,5}}},

         %% Exit in init_per_testcase -> pre/post_end_per_testcase
         %% shall not be called
         {?eh,tc_start,{skip_case_SUITE,exit_in_init}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,exit_in_init,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,exit_in_init,
                    '$proplist',
                    {skip,{failed,'_'}},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,exit_in_init,
                       {auto_skipped,{failed,'_'}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,exit_in_init,
                    {tc_auto_skip,{failed,'_'}},
                    []]}},
         {?eh,test_stats,{0,0,{5,6}}},

         %% Fail in end_per_testcase -> all hooks shall be called and
         %% test shall succeed.
         {?eh,tc_start,{skip_case_SUITE,fail_in_end}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,fail_in_end,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,fail_in_end,
                    '$proplist',
                    ok,
                    []]}},
         {?eh,cth,{empty_cth,pre_end_per_testcase,
                   [skip_case_SUITE,fail_in_end,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_end_per_testcase,
                   [skip_case_SUITE,fail_in_end,
                    '$proplist',
                    {failed,
                     {skip_case_SUITE,end_per_testcase,
                      {'EXIT',
                       {test_case_failed,"Failed in end_per_testcase/2"}}}},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,fail_in_end,
                       {failed,
                        {skip_case_SUITE,end_per_testcase,
                         {'EXIT',
                          {test_case_failed,"Failed in end_per_testcase/2"}}}}}},
         {?eh,test_stats,{1,0,{5,6}}},

         %% Exit in end_per_testcase -> all hooks shall be called and
         %% test shall succeed.
         {?eh,tc_start,{skip_case_SUITE,exit_in_end}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,exit_in_end,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,exit_in_end,
                    '$proplist',
                    ok,
                    []]}},
         {?eh,cth,{empty_cth,pre_end_per_testcase,
                   [skip_case_SUITE,exit_in_end,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_end_per_testcase,
                   [skip_case_SUITE,exit_in_end,
                    '$proplist',
                    {failed,
                     {skip_case_SUITE,end_per_testcase,
                      {'EXIT',"Exit in end_per_testcase/2"}}},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,exit_in_end,
                       {failed,
                        {skip_case_SUITE,end_per_testcase,
                         {'EXIT',"Exit in end_per_testcase/2"}}}}},
         {?eh,test_stats,{2,0,{5,6}}},

         %% Skip in testcase function -> all callbacks shall be called
         {?eh,tc_start,{skip_case_SUITE,skip_in_case}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [skip_case_SUITE,skip_in_case,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [skip_case_SUITE,skip_in_case,
                    '$proplist',
                    ok,[]]}},
         {?eh,cth,{empty_cth,pre_end_per_testcase,
                   [skip_case_SUITE,skip_in_case,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_end_per_testcase,
                   [skip_case_SUITE,skip_in_case,
                    '$proplist',
                    {skip,"Skipped in test case function"},
                    []]}},
         {?eh,tc_done,{skip_case_SUITE,skip_in_case,
                       {skipped,"Skipped in test case function"}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,skip_in_case,
                    {tc_user_skip,"Skipped in test case function"},
                    []]}},
         {?eh,test_stats,{2,0,{6,6}}},

         %% Auto skip due to failed 'require' -> only the on_tc_skip
         %% callback shall be called
         {?eh,tc_start,{skip_case_SUITE,req_auto_skip}},
         {?eh,tc_done,{skip_case_SUITE,req_auto_skip,
                       {auto_skipped,{require_failed,{not_available,whatever}}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,req_auto_skip,
                    {tc_auto_skip,{require_failed,{not_available,whatever}}},
                    []]}},
         {?eh,test_stats,{2,0,{6,7}}},

         %% Auto skip due to failed testcase/0 function -> only the
         %% on_tc_skip callback shall be called
         {?eh,tc_start,{skip_case_SUITE,fail_auto_skip}},
         {?eh,tc_done,{skip_case_SUITE,fail_auto_skip,
                       {auto_skipped,{testcase0_failed,bad_return_value}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [skip_case_SUITE,fail_auto_skip,
                    {tc_auto_skip,{testcase0_failed,bad_return_value}},
                    []]}},
         {?eh,test_stats,{2,0,{6,8}}},

         {?eh,tc_start,{skip_case_SUITE,end_per_suite}},
         {?eh,cth,{empty_cth,pre_end_per_suite,
                   [skip_case_SUITE,
                    '$proplist',
                    []]}},
         {?eh,cth,{empty_cth,post_end_per_suite,
                   [skip_case_SUITE,
                    '$proplist',
                    ok,[]]}},
         {?eh,tc_done,{skip_case_SUITE,end_per_suite,ok}},
         {?eh,test_done,{'DEF','STOP_TIME'}},
         {?eh,cth,{empty_cth,terminate,[[]]}},
         {?eh,stop_logging,[]}
        ],
    %% Make sure no 'cth_error' events are received!
    [{negative,{?eh,cth_error,'_'},E} || E <- Events];

test_events(failed_sequence) ->
    %% skip_cth.erl will send a 'cth_error' event if a hook is
    %% erroneously called. Therefore, all Events are changed to
    %% {negative,{?eh,cth_error,'_'},Event}
    %% at the end of this function.
    Events =
        [
         {?eh,start_logging,{'DEF','RUNDIR'}},
         {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
         {?eh,cth,{empty_cth,id,[[]]}},
         {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
         {?eh,start_info,{1,1,2}},
         {?eh,tc_start,{ct_framework,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,[seq_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [seq_SUITE,'$proplist','$proplist',[]]}},
         {?eh,tc_done,{ct_framework,init_per_suite,ok}},
         {?eh,tc_start,{seq_SUITE,test_case_1}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [seq_SUITE,test_case_1,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [seq_SUITE,test_case_1,'$proplist',ok,[]]}},
         {?eh,cth,{empty_cth,pre_end_per_testcase,
                   [seq_SUITE,test_case_1,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_end_per_testcase,
                   [seq_SUITE,test_case_1,'$proplist',
                    {error,failed_on_purpose},[]]}},
         {?eh,tc_done,{seq_SUITE,test_case_1,{failed,{error,failed_on_purpose}}}},
         {?eh,cth,{empty_cth,on_tc_fail,
                   [seq_SUITE,test_case_1,failed_on_purpose,[]]}},
         {?eh,test_stats,{0,1,{0,0}}},
         {?eh,tc_start,{seq_SUITE,test_case_2}},
         {?eh,tc_done,{seq_SUITE,test_case_2,
                       {auto_skipped,{sequence_failed,seq1,test_case_1}}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [seq_SUITE,test_case_2,
                    {tc_auto_skip,{sequence_failed,seq1,test_case_1}},
                    []]}},
         {?eh,test_stats,{0,1,{0,1}}},
         {?eh,tc_start,{ct_framework,end_per_suite}},
         {?eh,cth,{empty_cth,pre_end_per_suite,[seq_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_end_per_suite,[seq_SUITE,'$proplist',ok,[]]}},
         {?eh,tc_done,{ct_framework,end_per_suite,ok}},
         {?eh,test_done,{'DEF','STOP_TIME'}},
         {?eh,cth,{empty_cth,terminate,[[]]}},
         {?eh,stop_logging,[]}
        ],
    %% Make sure no 'cth_error' events are received!
    [{negative,{?eh,cth_error,'_'},E} || E <- Events];

test_events(repeat_force_stop) ->
    %% skip_cth.erl will send a 'cth_error' event if a hook is
    %% erroneously called. Therefore, all Events are changed to
    %% {negative,{?eh,cth_error,'_'},Event}
    %% at the end of this function.
    Events=
        [
         {?eh,start_logging,{'DEF','RUNDIR'}},
         {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
         {?eh,cth,{empty_cth,id,[[]]}},
         {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
         {?eh,start_info,{1,1,2}},
         {?eh,tc_start,{ct_framework,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,[repeat_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [repeat_SUITE,'$proplist','$proplist',[]]}},
         {?eh,tc_done,{ct_framework,init_per_suite,ok}},
         {?eh,tc_start,{repeat_SUITE,test_case_1}},
         {?eh,cth,{empty_cth,pre_init_per_testcase,
                   [repeat_SUITE,test_case_1,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_init_per_testcase,
                   [repeat_SUITE,test_case_1,'$proplist',ok,[]]}},
         {?eh,cth,{empty_cth,pre_end_per_testcase,
                   [repeat_SUITE,test_case_1,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_end_per_testcase,
                   [repeat_SUITE,test_case_1,'$proplist',ok,[]]}},
         {?eh,tc_done,{repeat_SUITE,test_case_1,ok}},
         {?eh,test_stats,{1,0,{0,0}}},
         {?eh,tc_start,{repeat_SUITE,test_case_2}},
         {?eh,tc_done,{repeat_SUITE,test_case_2,
                       {auto_skipped,
                        "Repeated test stopped by force_stop option"}}},
         {?eh,cth,{empty_cth,on_tc_skip,
                   [repeat_SUITE,test_case_2,
                    {tc_auto_skip,"Repeated test stopped by force_stop option"},
                    []]}},
         {?eh,test_stats,{1,0,{0,1}}},
         {?eh,tc_start,{ct_framework,end_per_suite}},
         {?eh,cth,{empty_cth,pre_end_per_suite,[repeat_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_end_per_suite,
                   [repeat_SUITE,'$proplist',ok,[]]}},
         {?eh,tc_done,{ct_framework,end_per_suite,ok}},
         {?eh,test_done,{'DEF','STOP_TIME'}},
         {?eh,cth,{empty_cth,terminate,[[]]}},
         {?eh,stop_logging,[]}
        ],
    %% Make sure no 'cth_error' events are received!
    [{negative,{?eh,cth_error,'_'},E} || E <- Events];

test_events(config_clash) ->
    %% skip_cth.erl will send a 'cth_error' event if a hook is
    %% erroneously called. Therefore, all Events are changed to
    %% {negative,{?eh,cth_error,'_'},Event}
    %% at the end of this function.
    Events =
        [
         {?eh,start_logging,{'DEF','RUNDIR'}},
         {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
         {?eh,cth,{empty_cth,id,[[]]}},
         {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
         {?eh,start_info,{1,1,1}},
         {?eh,tc_start,{ct_framework,init_per_suite}},
         {?eh,cth,{empty_cth,pre_init_per_suite,
                   [config_clash_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_init_per_suite,
                   [config_clash_SUITE,'$proplist','$proplist',[]]}},
         {?eh,tc_done,{ct_framework,init_per_suite,ok}},
         {?eh,tc_start,{config_clash_SUITE,test_case_1}},
         {?eh,tc_done,{config_clash_SUITE,test_case_1,
                       {failed,{error,{config_name_already_in_use,[aa]}}}}},
         {?eh,cth,{empty_cth,on_tc_fail,
                   [config_clash_SUITE,test_case_1,
                    {config_name_already_in_use,[aa]},
                    []]}},
         {?eh,test_stats,{0,1,{0,0}}},
         {?eh,tc_start,{ct_framework,end_per_suite}},
         {?eh,cth,{empty_cth,pre_end_per_suite,
                   [config_clash_SUITE,'$proplist',[]]}},
         {?eh,cth,{empty_cth,post_end_per_suite,
                   [config_clash_SUITE,'$proplist',ok,[]]}},
         {?eh,tc_done,{ct_framework,end_per_suite,ok}},
         {?eh,test_done,{'DEF','STOP_TIME'}},
         {?eh,cth,{empty_cth,terminate,[[]]}},
         {?eh,stop_logging,[]}
    ],
    %% Make sure no 'cth_error' events are received!
    [{negative,{?eh,cth_error,'_'},E} || E <- Events];

test_events(alter_groups) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,
                                      [{new_group,[tc1,tc2]}]]}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[{group,new_group}],
                                   [{new_group,[tc1,tc2]}]]}},
     {?eh,start_info,{1,1,2}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,
                                      [{new_group,[tc1,tc2]}]]}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[{group,new_group}],
                                   [{new_group,[tc1,tc2]}]]}},
     {?eh,tc_start,{all_and_groups_SUITE,{init_per_group,new_group,[]}}},
     {?eh,tc_done,{all_and_groups_SUITE,
                   {init_per_group,new_group,'$proplist'},ok}},
     {?eh,tc_start,{all_and_groups_SUITE,tc1}},
     {?eh,tc_done,{all_and_groups_SUITE,tc1,ok}},
     {?eh,tc_start,{all_and_groups_SUITE,tc2}},
     {?eh,tc_done,{all_and_groups_SUITE,tc2,ok}},
     {?eh,tc_start,{all_and_groups_SUITE,{end_per_group,new_group,[]}}},
     {?eh,tc_done,{all_and_groups_SUITE,
                   {end_per_group,new_group,'$proplist'},ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(alter_all) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,
                                      [{test_group,[tc1]}]]}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[tc2],
                                   [{test_group,[tc1]}]]}},
     {?eh,start_info,{1,1,1}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[tc2],'_']}},
     {?eh,tc_start,{all_and_groups_SUITE,tc2}},
     {?eh,tc_done,{all_and_groups_SUITE,tc2,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(alter_all_from_skip) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,
                                      [{test_group,[tc1]}]]}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[tc2],
                                   [{test_group,[tc1]}]]}},
     {?eh,start_info,{1,1,1}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,[tc2],'_']}},
     {?eh,tc_start,{all_and_groups_SUITE,tc2}},
     {?eh,tc_done,{all_and_groups_SUITE,tc2,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(alter_all_to_skip) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,
                                      [{test_group,[tc1]}]]}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,
                                   {skip,"skipped by post_all/3"},
                                   [{test_group,[tc1]}]]}},
     {?eh,start_info,{1,1,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,
                                   {skip,"skipped by post_all/3"},
                                   '_']}},
     {?eh,tc_user_skip,{all_and_groups_SUITE,all,"skipped by post_all/3"}},
     {?eh,cth,{'_',on_tc_skip,[all_and_groups_SUITE,all,
                               {tc_user_skip,"skipped by post_all/3"},
                               []]}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(illegal_values_groups) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,
               [all_and_groups_SUITE,
                [{new_group,[this_test_does_not_exist]},
                 this_is_not_a_group_def]]}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,
               [all_and_groups_SUITE,
                [{new_group,[this_test_does_not_exist]},
                 this_is_not_a_group_def]]}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,{ct_framework,error_in_suite,{failed,{error,'_'}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(illegal_values_all) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,
               [all_and_groups_SUITE,
                [{group,this_group_does_not_exist},
                 {this_is_not_a_valid_term}],'_']}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,
               [all_and_groups_SUITE,
                [{group,this_group_does_not_exist},
                 {this_is_not_a_valid_term}],'_']}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,
      {ct_framework,error_in_suite,
       {failed,
        {error,'Invalid reference to group this_group_does_not_exist in all_and_groups_SUITE:all/0'}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(bad_return_groups) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,not_a_list]}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,not_a_list]}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,
      {ct_framework,error_in_suite,
       {failed,
        {error,
         {'Bad return value from post_groups/2 hook function',not_a_list}}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(bad_return_all) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,not_a_list,'_']}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,not_a_list,'_']}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,
      {ct_framework,error_in_suite,
       {failed,
        {error,{'Bad return value from post_all/3 hook function',not_a_list}}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(crash_groups) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,crash]}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,crash]}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,{ct_framework,error_in_suite,
                   {failed,
                    {error,"all_and_groups_cth:post_groups/2 CTH call failed"}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(crash_all) ->
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{empty_cth,id,[[]]}},
     {?eh,cth,{empty_cth,init,[{'_','_','_'},[]]}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,crash,'_']}},
     {?eh,start_info,{1,0,0}},
     {?eh,cth,{empty_cth,post_groups,[all_and_groups_SUITE,'_']}},
     {?eh,cth,{empty_cth,post_all,[all_and_groups_SUITE,crash,'_']}},
     {?eh,tc_start,{ct_framework,error_in_suite}},
     {?eh,tc_done,{ct_framework,error_in_suite,
                   {failed,
                    {error,"all_and_groups_cth:post_all/3 CTH call failed"}}}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,cth,{empty_cth,terminate,[[]]}},
     {?eh,stop_logging,[]}
    ];

test_events(ok) ->
    ok.

update_config_cth_test_events(TestCaseEvents, Suite) ->
    MaybeEndPerTestcaseCrashEvents =
        case Suite of
            ct_update_config_SUITE ->
                TestCaseEvents(test_case_timetrap_end_per_testcase_crash,
                               {timetrap_timeout,1000}) ++
                    TestCaseEvents(test_case_badmatch,
                                   {error, {{badmatch,2}, '_'}}) ++
                    TestCaseEvents(test_case_spawn_crash, {'EXIT',bam});
            _ ->
                []
        end,
    [
     {?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},

     {?eh,tc_start,{Suite,init_per_suite}},
     {?eh,cth,{'_',pre_init_per_suite,
	       [Suite,contains([]),[]]}},
     {?eh,cth,{'_',post_init_per_suite,
	       [Suite,
		'$proplist',
		contains(
                  [init_per_suite,
                   pre_init_per_suite]),
		[]]}},
     {?eh,tc_done,{Suite,init_per_suite,ok}},

     {?eh,tc_start,{Suite, {init_per_group,group1,[]}}},
     {?eh,cth,{'_',pre_init_per_group,
	       [Suite,
                group1,contains(
			 [post_init_per_suite,
			  init_per_suite,
			  pre_init_per_suite]),
		[]]}},
     {?eh,cth,{'_',post_init_per_group,
	       [Suite,
                group1,
		contains(
		  [post_init_per_suite,
		   init_per_suite,
		   pre_init_per_suite]),
		contains(
		  [init_per_group,
		   pre_init_per_group,
		   post_init_per_suite,
		   init_per_suite,
		   pre_init_per_suite]),
                []]}},
     {?eh,tc_done,{Suite,{init_per_group,group1,[]},ok}}] ++
        TestCaseEvents(test_case, ok) ++
        TestCaseEvents(test_case_fail,
                       {error,{test_case_failed,because_i_want_failure}}) ++
        TestCaseEvents(test_case_timetrap, {timetrap_timeout,1000}) ++
        MaybeEndPerTestcaseCrashEvents ++
        [{?eh,tc_start,{Suite, {end_per_group,group1,[]}}},
         {?eh,cth,{'_',pre_end_per_group,
                   [Suite,
                    group1,contains(
                             [post_init_per_group,
                              init_per_group,
                              pre_init_per_group,
                              post_init_per_suite,
                              init_per_suite,
                              pre_init_per_suite]),
                    []]}},
         {?eh,cth,{'_',post_end_per_group,
                   [Suite,
                    group1,
                    contains(
                      [pre_end_per_group,
                       post_init_per_group,
                       init_per_group,
                       pre_init_per_group,
                       post_init_per_suite,
                       init_per_suite,
                       pre_init_per_suite]),
                    ok,[]]}},
         {?eh,tc_done,{Suite,{end_per_group,group1,[]},ok}},

         {?eh,tc_start,{Suite,end_per_suite}},
         {?eh,cth,{'_',pre_end_per_suite,
                   [Suite,contains(
                                             [post_init_per_suite,
                                              init_per_suite,
                                              pre_init_per_suite]),
                    []]}},
         {?eh,cth,{'_',post_end_per_suite,
                   [Suite,contains(
                                             [pre_end_per_suite,
                                              post_init_per_suite,
                                              init_per_suite,
                                              pre_init_per_suite]),
                    '_',[]]}},
         {?eh,tc_done,{Suite,end_per_suite,ok}},
         {?eh,test_done,{'DEF','STOP_TIME'}},
         {?eh,cth,{'_',terminate,[contains(
                                    [post_end_per_suite,
                                     pre_end_per_suite,
                                     post_init_per_suite,
                                     init_per_suite,
                                     pre_init_per_suite])]}},
         {?eh,stop_logging,[]}
        ].

%% test events help functions
contains(List) ->
    fun(Proplist) when is_list(Proplist) ->
	    contains(List,Proplist)
    end.

contains([{not_in_order,List}|T],Rest) ->
    contains_parallel(List,Rest),
    contains(T,Rest);
contains([{Ele,Pos}|T] = L,[H|T2]) ->
    case element(Pos,H) of
	Ele ->
	    contains(T,T2);
	_ ->
	    contains(L,T2)
    end;
contains([Ele|T],[{Ele,_}|T2])->
    contains(T,T2);
contains([Ele|T],[Ele|T2])->
    contains(T,T2);
contains(List,[_|T]) ->
    contains(List,T);
contains([],_) ->
    match.

contains_parallel([Key | T], Elems) ->
    contains([Key],Elems),
    contains_parallel(T,Elems);
contains_parallel([],_Elems) ->
    match.

not_contains(List) ->
    fun(Proplist) when is_list(Proplist) ->
	    [] = [Ele || {Ele,_} <- Proplist,
			 Test <- List,
			 Test =:= Ele]
    end.

hooks_order_events_helper(Suite, Recipe) ->
    BuildSettingsMap =
        fun F([{NewKey, Addition, []} | T], Acc) ->
                F(T, Acc#{NewKey => Addition});
            F([{NewKey, Addition, RefKey} | T], Acc) ->
                V = fun(Key, Map) -> maps:get(Key, Map) end,
                F(T, Acc#{NewKey => Addition ++ V(RefKey, Acc)});
            F([], Acc) ->
                Acc
        end,
    ExpectedExeSeq = BuildSettingsMap(Recipe, #{}),
    Print = fun(Key, Map) ->
                        io_lib:format("~n~10s || ~s",
                          [atom_to_list(Key),
                           [io_lib:format("~s|", [I])||
                               I <- lists:reverse(maps:get(Key, Map))]])
            end,
    ExpectedExeSeqStr = [Print(Key, ExpectedExeSeq) || {Key, _, _} <- Recipe],
    ct:log("~n~nLegend: ips - init_per_suite, ipg - init_per_group, "
           "ipt - init_per_testcase~n~n"
           "SLOT       || EXPECTED EXECUTION SEQUENCE~n"
           "-----------++----------------------------~s", [ExpectedExeSeqStr]),
    M = ExpectedExeSeq,
    V = fun(Key, Map) -> maps:get(Key, Map) end,
    [{?eh,start_logging,{'DEF','RUNDIR'}},
     {?eh,test_start,{'DEF',{'START_TIME','LOGDIR'}}},
     {?eh,cth,{'_',init,['_',[]]}},

     {?eh,tc_start,{Suite,init_per_suite}},
     ?cth_event3(pre_init_per_suite, Suite, contains(V(pre_ips_1, M))),
     ?cth_event3(pre_init_per_suite, Suite, contains(V(pre_ips_2, M))),
     ?cth_event4(post_init_per_suite, Suite, '$proplist', contains(V(post_ips_1, M))),
     ?cth_event4(post_init_per_suite, Suite, '$proplist', contains(V(post_ips_2, M))),
     {?eh,tc_done,{Suite,init_per_suite,ok}},
     {?eh,tc_start,{Suite, {init_per_group,group1,[]}}},
     ?cth_event4(pre_init_per_group, Suite, group1, contains(V(pre_ipg_1, M))),
     ?cth_event4(pre_init_per_group, Suite, group1, contains(V(pre_ipg_2, M))),
     ?cth_event5(post_init_per_group, Suite, group1,
                 '$proplist', contains(V(post_ipg_1, M))),
     ?cth_event5(post_init_per_group, Suite, group1,
                 '$proplist', contains(V(post_ipg_2, M))),
     {?eh,tc_done,{Suite,{init_per_group,group1,[]},ok}},

     {?eh,tc_start,{Suite,test_case}},
     ?cth_event4(pre_init_per_testcase, Suite, test_case, contains(V(pre_ipt_1, M))),
     ?cth_event4(pre_init_per_testcase, Suite, test_case, contains(V(pre_ipt_2, M))),
     ?cth_event5(post_init_per_testcase, Suite, test_case,
                 contains(V(post_ipt_1, M)), ok),
     ?cth_event5(post_init_per_testcase, Suite, test_case,
                 '$proplist', contains(V(post_ipt_2, M))),
     ?cth_event4(pre_end_per_testcase, Suite, test_case, contains(V(pre_ept_1, M))),
     ?cth_event4(pre_end_per_testcase, Suite, test_case, contains(V(pre_ept_2, M))),
     ?cth_event5(post_end_per_testcase, Suite, test_case,
                 contains(V(post_ept_1, M)), ok),
     ?cth_event5(post_end_per_testcase, Suite, test_case,
                '$proplist', contains(V(post_ept_2, M))),
     {?eh,tc_done,{Suite,test_case,ok}},

     {?eh,tc_start,{Suite, {end_per_group,group1,[]}}},
     ?cth_event4(pre_end_per_group, Suite, group1, contains(V(pre_epg_1, M))),
     ?cth_event4(pre_end_per_group, Suite, group1, contains(V(pre_epg_2, M))),
     ?cth_event5(post_end_per_group, Suite, group1,
                 contains(V(post_epg_1, M)), ok),
     ?cth_event5(post_end_per_group, Suite, group1,
                '$proplist', contains(V(post_epg_2, M))),
     {?eh,tc_done,{Suite,{end_per_group,group1,[]},ok}},

     {?eh,tc_start,{Suite,end_per_suite}},
     ?cth_event3(pre_end_per_suite, Suite, contains(V(pre_eps_1, M))),
     ?cth_event3(pre_end_per_suite, Suite, contains(V(pre_eps_2, M))),
     ?cth_event4(post_end_per_suite, Suite,
                 contains(V(post_eps_1, M)),
                 ok),
     ?cth_event4(post_end_per_suite, Suite, '$proplist', contains(V(post_eps_1, M))),
     {?eh,tc_done,{Suite,end_per_suite,ok}},
     {?eh,test_done,{'DEF','STOP_TIME'}},
     {?eh,stop_logging,[]}
    ].
