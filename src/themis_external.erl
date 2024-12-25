-module(themis_external).

-export([
    new/3,
    info/1,
    counter_increment_by/3,
    counter_increment_by_decimal/3,
    match_metric/2,
    match_record/2
]).

new(Name, Type, Access) ->
    ets:new(Name, [Type, Access]).

info(Table) ->
    list_to_tuple(ets:info(Table)).


counter_increment_by(Tab, Key, Increment) when is_integer(Increment), Increment >= 0 ->
    ets:update_counter(Tab, Key, {2, Increment}, {Key, 0, 0.0, <<"">>}).


counter_increment_by_decimal(Tab, Key, Increment) when is_float(Increment), Increment >= 0 ->
    MS = [{{Key, '$1', '$2', '$3'},
    [],
    [{{{Key}, '$1', {'+', '$2', Increment}, '$3'}}]}],
    case ets:select_replace(Tab, MS) of
        0 -> ets:insert(Tab, {Key, 0, Increment, <<"">>});
        1 -> ok
    end.
    
match_metric(Tab, Type) ->
    Pattern = {'_', '_', Type, '_'},
    ets:match_object(Tab, Pattern).
match_record(Tab, Name) ->
    Pattern = {{Name, '_'}, '_', '_', '_'},
    ets:match_object(Tab, Pattern).