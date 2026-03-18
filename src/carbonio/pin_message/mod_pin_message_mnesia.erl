-module(mod_pin_message_mnesia).
-behaviour(mod_pin_message_backend).

-include("pin.hrl").

-export([init/2, read/2, write/2, check_message_exists/2, delete/2, get_pin_by_room_id/2]).

-spec init(mongooseim:host_type(), gen_mod:module_opts()) -> ok.
init(HostType, Opts) ->
    mod_pin_message_rdbms:init(HostType, Opts).

-spec read(mongooseim:host_type(), binary()) -> {ok, term()} | error.
read(HostType, Key) ->
    mod_pin_message_rdbms:read(HostType, Key).

-spec write(mongooseim:host_type(), #pin{}) -> ok | {error, any()}.
write(HostType, Pin) ->
    mod_pin_message_rdbms:write(HostType, Pin).
-spec check_message_exists(mongooseim:host_type(), binary()) -> boolean().
check_message_exists(HostType, RoomId) ->
    mod_pin_message_rdbms:check_message_exists(HostType, RoomId).

-spec delete(mongooseim:host_type(), binary()) -> ok | error.
delete(HostType, StanzaId) ->
    mod_pin_message_rdbms:delete(HostType, StanzaId).

-spec get_pin_by_room_id(mongooseim:host_type(), binary()) -> {ok, #pin{}} | error.
get_pin_by_room_id(HostType, RoomId) ->
    mod_pin_message_rdbms:get_pin_by_room_id(HostType, RoomId).
