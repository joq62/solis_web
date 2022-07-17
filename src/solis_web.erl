%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : resource discovery accroding to OPT in Action 
%%% This service discovery is adapted to 
%%% Type = application 
%%% Instance ={ip_addr,{IP_addr,Port}}|{erlang_node,{ErlNode}}
%%% 1
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(solis_web). 

-behaviour(gen_server). 

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
-define(SERVER,?MODULE).
-define(CheckIntervall,1*1000).
-define(IntervalReadSolis,5).
%% External exports
-export([
	 check_time/1,
	 wanted_temp/1,
	 temp/1,
	 door/1,
	 motion/1
	]).






-export([
	 websocket_init/1,
	 websocket_handle/1,
	 websocket_info/1
	]).

-export([
	 appl_start/1,
	 ping/0,

	 start/0,
	 stop/0
	]).


-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
		web_socket_pid,
		clock,
		temp_indoor,
		switch_lamps,
		switch_tv	        	
	       }).

%% ====================================================================
%% External functions
%% ====================================================================
appl_start([])->
    
    application:start(?MODULE).

%% ====================================================================
%% Server functions
%% ====================================================================
%% Gen server functions

start()-> gen_server:start_link({local, ?SERVER}, ?SERVER, [], []).
stop()-> gen_server:call(?SERVER, {stop},infinity).

%% ====================================================================
%% Application handling
%% ====================================================================

%% ====================================================================
%% Support functions
%% ====================================================================
wanted_temp(T)-> 
    gen_server:call(?SERVER, {wanted_temp,T},infinity).

temp(T)-> 
    gen_server:call(?SERVER, {temp,T},infinity).
door(T)-> 
    gen_server:call(?SERVER, {door,T},infinity).
motion(T)-> 
    gen_server:call(?SERVER, {motion,T},infinity).
%% Websocket server functions

websocket_init(S)->
    gen_server:call(?SERVER, {websocket_init,S},infinity).
websocket_handle(Msg)->
    gen_server:call(?SERVER, {websocket_handle,Msg},infinity).
websocket_info(Msg)->
    gen_server:call(?SERVER, {websocket_info,Msg},infinity).

%% 
%% @doc:check if service is running
%% @param: non
%% @returns:{pong,node,module}|{badrpc,Reason}
%%
-spec ping()-> {atom(),node(),module()}|{atom(),term()}.
ping()-> 
    gen_server:call(?SERVER, {ping},infinity).


check_time(Status)->
    gen_server:cast(?SERVER, {check_time,Status}).
    
%% ====================================================================
%% Gen Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
    
    web_init:start(),
    
    {ok, #state{
	    clock="Ok there you go!",
	    temp_indoor=undefined_temp,
	    switch_lamps=undefined_lamps,
	    switch_tv=undefined_tv}}.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({websocket_init,WebSocketPid},_From,State) ->
    io:format("init websocket ~p~n",[{?MODULE,?LINE,WebSocketPid}]),
    {Reply,NewState}=format_text(init,State#state{web_socket_pid=WebSocketPid}),
    spawn(fun()->do_check_time(?IntervalReadSolis,"temp_undef","lamps_undef","tv_undef") end),
    {reply, Reply,NewState};

handle_call({websocket_handle,{text, Text}},_From,State) ->
    io:format("websocket_handle ~p~n",[{Text,?MODULE,?LINE}]),
    Reply=ok,
    {reply, Reply, State};

handle_call({ping},_From, State) ->
    Reply=pong,
    {reply, Reply, State};

handle_call({stopped},_From, State) ->
    Reply=ok,
    {reply, Reply, State}; 


handle_call({not_implemented},_From, State) ->
    Reply=not_implemented,
    {reply, Reply, State};

handle_call({stop}, _From, State) ->
    {stop, normal, shutdown_ok, State};

handle_call(Request, From, State) ->
    io:format("unmatched signal  ~p~n",[{Request,?MODULE,?LINE}]),
    %rpc:cast(node(),log,log,[?Log_ticket("unmatched call",[Request, From])]),
    Reply = {ticket,"unmatched call",Request, From},
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast({check_time,{N,Clock,Temp,Lamps,Tv}}, State) ->
    NewState=State#state{clock=Clock,
			 temp_indoor=Temp,
			 switch_lamps=Lamps,
			 switch_tv=Tv},
     {{ok,Type,M,F,A},_}=format_text(NewState),
    State#state.web_socket_pid!{ok,Type,M,F,A},
    spawn(fun()->do_check_time(N,Temp,Lamps,Tv) end),
    {noreply, NewState};

handle_cast(Msg, State) ->
    io:format("unmatched match cast ~p~n",[{?MODULE,?LINE,Msg}]),
    {noreply, State}.
%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({gun_response,_X1,_X2,_X3,_X4,_X5}, State) ->
    {noreply, State};

handle_info({gun_up,_,_}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    io:format("unmatched match info ~p~n",[{?MODULE,?LINE,Info}]),
    {noreply, State}.
%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

-define(TestNode,'solis_test@c100').


do_check_time(N,Temp,Lamps,Tv)->
    timer:sleep(?CheckIntervall),
    
    {H,M,S}=time(),
    Clock=integer_to_list(H)++":"++integer_to_list(M)++":"++integer_to_list(S),
    if 
	N==0->
	    NewN=?IntervalReadSolis,
	    case sd:get(solis) of
		[]->
		    NewTemp=Temp,
		    NewLamps=Lamps,
		    NewTv=Tv;
		[{SolisNode,_}|_]->
		    NewTemp=rpc:call(SolisNode,solis,temp,["indoor"],2000),
		    case rpc:call(SolisNode,lamps,are_on,[],2000) of
			{badrpc,_}->
			    NewLamps=Lamps;
			false->
			    NewLamps="OFF";
			true->
			    NewLamps="ON"
		    end,
		    case rpc:call(SolisNode,tv,is_on,[],2000) of
			{badrpc,_}->
			    NewTv=Tv;
			false->
			    NewTv="OFF";
			true->
			    NewTv="ON"
		    end
	    end;
	   % io:format("read solis ~n");
	true->
	    NewN=N-1,
	    NewTemp=Temp,
	    NewLamps=Lamps,
	    NewTv=Tv
    end,
    
    rpc:cast(node(),?MODULE,check_time,[{NewN,Clock,NewTemp,NewLamps,NewTv}]).


%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
format_text(init,State)->
    format_text(State).


format_text(NewState)->
    Type=text,
    M=io_lib,
    F=format,
    Clock=NewState#state.clock,
    Temp=NewState#state.temp_indoor,
    Lamps=NewState#state.switch_lamps,
    Tv=NewState#state.switch_tv,
    
    A=["~s~s ~s~s ~s~s ~s", [Clock,",",Temp,",",Lamps,",",Tv]],
    {{ok,Type,M,F,A},NewState}.

		  
