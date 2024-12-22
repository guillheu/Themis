-module(themis_external).

-export([
    new/3,
    info/1,
    counter_increment_by/3,
    counter_increment_by_decimal/3
]).

new(Name, Type, Access) ->
    ets:new(Name, [Type, Access]).

info(Table) ->
    list_to_tuple(ets:info(Table)).


counter_increment_by(Tab, Key, Increment) when is_integer(Increment), Increment >= 0 ->
    try
        ets:update_counter(Tab, Key, {2, Increment}, {Key, 0})
    catch error:badarg ->
        counter_increment_by_decimal(Tab, Key, Increment)
    end.


counter_increment_by_decimal(Tab, Key, Increment) when is_number(Increment), Increment >= 0 ->
    MS = [{{Key, '$1'},
    [],
    [{{Key, {'+', '$1', Increment}}}]}],
    case ets:select_replace(Tab, MS) of
        0 -> ets:insert(Tab, {Key, Increment});
        1 -> ok
    end.
    

