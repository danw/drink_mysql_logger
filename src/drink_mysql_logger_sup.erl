%%%-------------------------------------------------------------------
%%% File    : drink_mysql_logger_sup.erl
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

-module (drink_mysql_logger_sup).
-behaviour (supervisor).

-export ([start/0, start_link/1, init/1]).

start () ->
    start_link([]).

start_link (Args) ->
    supervisor:start_link({local,?MODULE}, ?MODULE, Args).

init ([]) ->
    case get_db_args() of
        {ok, Server, User, Password, Database} ->
            {ok, {{one_for_one, 10, 3},  % One for one restart, shutdown after 10 restarts within 3 seconds
                  [{mysql_conn,
                    {mysql, start_link, [drink_log, Server, undefined, User, Password, Database, undefined]},
                    permanent,
                    100,
                    worker,
                    [mysql]},
                   {drink_mysql_logger,
                    {drink_mysql_logger, start_link, []},
                    permanent,
                    100,
                    worker,
                    [drink_mysql_logger]}]}};
        {error, Reason} -> {error, Reason}
    end.

get_db_args() ->
    case {application:get_env(server), application:get_env(user), application:get_env(database), get_db_pass()} of
        {{ok, Server}, {ok, User}, {ok, Database}, {ok, Pass}} ->
            {ok, Server, User, Pass, Database};
        _ ->
            {error, bad_settings}
    end.

get_db_pass() ->
    DBPassFile = filename:join("etc", "dbpass"),
    case filelib:is_file(DBPassFile) of
        true ->
            case file:read_file(DBPassFile) of
                {ok, Bin} -> {ok, binary_to_list(Bin) -- "\n"};
                _ ->
                    error_logger:error_msg("Unable to read DB Pass file: ~p~n", [DBPassFile]),
                    {error, read_failed}
            end;
        false ->
            error_logger:error_msg("Unable to find DB Pass file: ~p~n", [DBPassFile]),
            {error, pass_not_found}
    end.

