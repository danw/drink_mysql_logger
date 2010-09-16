%%%-------------------------------------------------------------------
%%% File    : drink_mysql_log.erl
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

-module (drink_mysql_log).
-export ([initialize/0]).
-export ([get_logs/2, get_logs/3, get_temps/2]).

-include_lib ("drink_log/include/drink_log.hrl").
-include_lib ("drink/include/drink_mnesia.hrl").
-include_lib ("drink/include/user.hrl").

initialize() ->
    mysql:prepare(get_logs, <<"SELECT * FROM (
        SELECT \"money\" as type, m.time as time, m.username, m.admin, m.direction, m.reason, m.amount FROM money_log as m
        union
        SELECT \"drop\" as type, d.time as time, d.username, d.machine, d.slot, d.status, 0 FROM drop_log as d) AS log
        ORDER BY log.time DESC LIMIT ?, ?">>),
    mysql:prepare(get_logs_user, <<"SELECT * FROM (
        SELECT \"money\" as type, m.time as time, m.username as u, m.admin, m.direction, m.reason, m.amount
            FROM money_log as m
        union
        SELECT \"drop\" as type, d.time as time, d.username as u, d.machine, d.slot, d.status, 0
            FROM drop_log as d) AS log
        WHERE u = ? ORDER BY log.time DESC LIMIT ?, ?">>),
    mysql:prepare(get_temps, <<"SELECT * FROM temperature_log WHERE time > ? AND time < ? ORDER BY time ASC">>).

get_logs(UserRef, Index, Count) when is_reference(UserRef), is_integer(Index), is_integer(Count) ->
    case {user_auth:can_admin(UserRef), user_auth:user_info(UserRef)} of
        {false, {ok, UserInfo = #user{}}} ->
            case catch mysql:execute(drink_log, get_logs_user, [UserInfo#user.username, Index, Count], undefined) of
                {error, _MySqlRes} ->
                    {error, mysql};
                {data, MySqlRes} ->
                    {ok, lists:map(fun format_log/1, mysql:get_result_rows(MySqlRes))}
            end;
        {false, {error, Reason}} ->
            {error, Reason};
        {true, _} ->
            get_logs(Index, Count)
    end.

get_logs(Index, Count) when is_integer(Index), is_integer(Count) ->
    case catch mysql:execute(drink_log, get_logs, [Index, Count], undefined) of
        {error, _MySqlRes} ->
            {error, mysql};
        {data, MySqlRes} ->
            {ok, lists:map(fun format_log/1, mysql:get_result_rows(MySqlRes))}
    end.

get_temps(Since, Seconds) when is_tuple(Since), is_integer(Seconds) ->
    Until = calendar:gregorian_seconds_to_datetime(Seconds + calendar:datetime_to_gregorian_seconds(Since)),
    case catch mysql:execute(drink_log, get_temps, [Since, Until], undefined) of
        {error, _MySqlRes} ->
            {error, mysql};
        {data, MySqlRes} ->
            {ok, lists:map(fun format_temp/1, mysql:get_result_rows(MySqlRes))}
    end.

format_log([<<"money">>, {datetime, Time}, User, Admin, Direction, Reason, Amount]) ->
    AdminUser = case Admin of
        undefined ->
            null;
        Else ->
            binary_to_list(Else)
    end,
    #money_log{
        time = Time,
        username = binary_to_list(User),
        admin = AdminUser,
        direction = list_to_atom(binary_to_list(Direction)),
        reason = list_to_atom(binary_to_list(Reason)),
        amount = Amount
    };
format_log([<<"drop">>, {datetime, Time}, User, Machine, Slot, Status, 0]) ->
    #drop_log{
        time = Time,
        username = binary_to_list(User),
        machine = list_to_atom(binary_to_list(Machine)),
        slot = binary_to_list(Slot),
        status = binary_to_list(Status)
    }.

format_temp([Machine, {datetime, Time}, Temp]) ->
    #temperature{
        machine = list_to_atom(binary_to_list(Machine)),
        time = Time,
        temperature = Temp
    }.
