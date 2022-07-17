%%%-------------------------------------------------------------------
%% @doc solis_web public API
%% @end
%%%-------------------------------------------------------------------

-module(solis_web_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    solis_web_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
