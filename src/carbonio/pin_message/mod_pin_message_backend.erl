-module(mod_pin_message_backend).
-define(MAIN_MODULE, mod_pin_message).
-export([init/2, read/2, write/2, check_message_exists/2, delete/2, get_pin_by_room_id/2]).
-include("pin.hrl").

-callback init(mongooseim:host_type(), gen_mod:module_opts()) -> ok.
-callback read(mongooseim:host_type(), binary()) -> {ok, term()} | error.
-callback write(mongooseim:host_type(), #pin{}) -> ok | {error, any()}.
-callback check_message_exists(mongooseim:host_type(), binary()) -> boolean().
-callback delete(mongooseim:host_type(), binary()) -> ok | error.
-callback get_pin_by_room_id(mongooseim:host_type(), binary()) -> {ok, #pin{}} | error.

-spec init(mongooseim:host_type(), gen_mod:module_opts()) -> ok.
init(HostType, Opts) ->
    TrackedFuns = [read, get_pin_by_room_id],
    mongoose_backend:init(HostType, ?MAIN_MODULE, TrackedFuns, Opts),
    Args = [HostType, Opts],
    mongoose_backend:call(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).

-spec read(mongooseim:host_type(), binary()) -> {ok, #pin{}} | error.
read(HostType, Key) ->
    Args = [HostType, Key],
    mongoose_backend:call_tracked(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).

-spec write(mongooseim:host_type(), #pin{}) -> ok | {error, any()}.
write(HostType, Pin) ->
    Args = [HostType, Pin],
    mongoose_backend:call(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).

-spec check_message_exists(mongooseim:host_type(), binary()) -> boolean().
check_message_exists(HostType, RoomId) ->
    Args = [HostType, RoomId],
    mongoose_backend:call(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).

-spec delete(mongooseim:host_type(), binary()) -> ok | error.
delete(HostType, StanzaId) ->
    Args = [HostType, StanzaId],
    mongoose_backend:call(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).

-spec get_pin_by_room_id(mongooseim:host_type(), binary()) -> {ok, #pin{}} | error.
get_pin_by_room_id(HostType, RoomId) ->
    Args = [HostType, RoomId],
    mongoose_backend:call_tracked(HostType, ?MAIN_MODULE, ?FUNCTION_NAME, Args).
