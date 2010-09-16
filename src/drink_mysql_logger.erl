%%%-------------------------------------------------------------------
%%% File    : drink_mysql_logger.erl
%%% Author  : Dan Willemsen <dan@csh.rit.edu>
%%% Purpose : 
%%%
%%%
%%% edrink, Copyright (C) 2008-2010 Dan Willemsen
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%                         
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%-------------------------------------------------------------------

-module (drink_mysql_logger).
-behaviour (gen_server).

-export ([start_link/0]).
-export ([init/1, terminate/2, code_change/3]).
-export ([handle_call/3, handle_cast/2, handle_info/2]).

-include_lib ("drink_log/include/drink_log.hrl").

start_link () ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    mysql:prepare(log_temperature, <<"INSERT INTO temperature_log VALUES (?, ?, ?)">>),
    mysql:prepare(log_money, <<"INSERT INTO money_log VALUES (?, ?, ?, ?, ?, ?)">>),
    mysql:prepare(log_drop, <<"INSERT INTO drop_log VALUES (?, ?, ?, ?, ?)">>),
    dw_events:register_pid(drink, {registered, ?MODULE}),
    {ok, nil}.

terminate (_Reason, _State) ->
    dw_events:unregister_pid(drink),
    ok.

code_change (_OldVsn, State, _Extra) ->
    {ok, State}.

handle_cast (_Request, State) -> {noreply, State}.
handle_call (_Request, _From, State) -> {noreply, State}.

handle_info ({dw_event, drink, Pid, Event = #drop_log{}}, State) ->
    log_drop(Event),
    {noreply, State};
handle_info ({dw_event, drink, Pid, Event = #money_log{}}, State) ->
    log_money(Event),
    {noreply, State};
handle_info ({dw_event, drink, Pid, Event = #temperature{}}, State) ->
    log_temperature(Event),
    {noreply, State};
handle_info (_Info, State) -> {noreply, State}.

log_drop(Drop) ->
    Status = io_lib:format("~w", [Drop#drop_log.status]),
    case catch mysql:execute(drink_log, log_drop, [
                                Drop#drop_log.machine,
                                Drop#drop_log.slot,
                                Drop#drop_log.username,
                                Drop#drop_log.time,
                                Status], undefined) of
        {updated, _MySqlRes} ->
            ok;
        Reason ->
            error_logger:error_msg("Drop Log Error! ~p~n", [Reason]),
            {error, Reason}
    end.

log_money(Money = #money_log{ admin = nil }) -> log_money(Money#money_log{ admin = null });
log_money(Money) ->
    case catch mysql:execute(drink_log, log_money, [
                                Money#money_log.time,
                                Money#money_log.username,
                                Money#money_log.admin,
                                Money#money_log.amount,
                                Money#money_log.direction,
                                Money#money_log.reason], undefined) of
        {updated, _MySqlRes} ->
            ok;
        Reason ->
            error_logger:error_msg("Money Log Error! ~p~n", [Reason]),
            {error, Reason}
    end.

log_temperature(Temperature) ->
    case catch mysql:execute(drink_log, log_temperature, [
                                Temperature#temperature.machine,
                                Temperature#temperature.time,
                                Temperature#temperature.temperature], undefined) of
        {updated, _MySqlRes} ->
            ok;
        Reason ->
            error_logger:error_msg("Temperature Log Error! ~p~n", [Reason]),
            {error, Reason}
    end.

