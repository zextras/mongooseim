-module(mod_pin_message_rdbms).
-behaviour(mod_pin_message_backend).

-include("pin.hrl").

-import(mongoose_rdbms, [prepare/4, execute_successfully/3]).

-export([init/2, read/2, write/2, check_message_exists/2, delete/2, get_pin_by_room_id/2]).

init(HostType, _Opts) ->
    prepare_queries(HostType),
    ok.

prepare_queries(_HostType) ->
    mongoose_rdbms:prepare(
        check_message_exists,
        mam_muc_message,
        [id],
        <<"SELECT id, room_id, sender_id, nick_name, message, search_body, origin_id FROM mam_muc_message where id = ? LIMIT 1">>
    ),
    mongoose_rdbms:prepare(
        get_messages,
        mod_pin_messages,
        [stanza_id],
        <<"SELECT id, request_id, pinned_by, room_id, luser, server, stanza_id, pinned_at FROM pin_message WHERE stanza_id = ?">>
    ),
    mongoose_rdbms:prepare(
        get_pin_by_room_id,
        mod_pin_messages,
        [room_id],
        <<"SELECT id, request_id, pinned_by, room_id, luser, server, stanza_id, pinned_at FROM pin_message WHERE room_id = ?">>
    ),
    mongoose_rdbms:prepare(
        delete_message,
        mod_pin_messages,
        [stanza_id],
        <<"DELETE FROM pin_message WHERE stanza_id = ?">>
    ),
    mongoose_rdbms:prepare(
        insert_message,
        mod_pin_messages,
        [request_id, pinned_by, room_id, luser, server, stanza_id],
        <<"INSERT INTO pin_message (request_id, pinned_by, room_id, luser, server, stanza_id) VALUES (?, ?, ?, ?, ?, ?) on conflict (room_id) DO UPDATE set pinned_at = now(), request_id = excluded.request_id, pinned_by = excluded.pinned_by, stanza_id = excluded.stanza_id, luser = excluded.luser, server = excluded.server; ">>
    ).

read(HostType, Key) ->
    case execute_successfully(HostType, get_messages, [Key]) of
        {selected, [{Id, RequestId, PinnedBy, RoomId, Luser, Server, StanzaId, PinnedAt}]} ->
            {ok, #pin{
                id = Id,
                request_id = RequestId,
                pinned_by = PinnedBy,
                room_id = RoomId,
                luser = Luser,
                server = Server,
                stanza_id = StanzaId,
                pinned_at = PinnedAt
            }};
        {selected, []} ->
            error
    end.

write(
    HostType,
    #pin{
        request_id = RequestId,
        pinned_by = PinnedBy,
        room_id = RoomId,
        luser = Luser,
        server = Server,
        stanza_id = StanzaId
    }
) ->
    %% Convert JID to binary if needed
    RoomIdBin =
        case RoomId of
            {jid, _, _, _} -> jid:to_binary(RoomId);
            _ when is_binary(RoomId) -> RoomId;
            _ -> <<>>
        end,
    %% Handle undefined server
    ServerBin =
        case Server of
            %% fallback to luser's server or use a default
            undefined -> Luser;
            S when is_binary(S) -> S;
            _ -> <<>>
        end,
    execute_successfully(HostType, insert_message, [
        RequestId, PinnedBy, RoomIdBin, Luser, ServerBin, StanzaId
    ]),
    ok.

check_message_exists(HostType, Id) ->
    case execute_successfully(HostType, check_message_exists, [Id]) of
        {selected, [{_, _, _, _, _, _, _}]} -> true;
        {selected, []} -> false
    end.

delete(HostType, StanzaId) ->
    case execute_successfully(HostType, delete_message, [StanzaId]) of
        {updated, Count} when Count > 0 ->
            ok;
        _ ->
            error
    end.

get_pin_by_room_id(HostType, RoomId) ->
    case execute_successfully(HostType, get_pin_by_room_id, [RoomId]) of
        {selected, [{Id, RequestId, PinnedBy, RoomId, Luser, Server, StanzaId, PinnedAt}]} ->
            {ok, #pin{
                id = Id,
                request_id = RequestId,
                pinned_by = PinnedBy,
                room_id = RoomId,
                luser = Luser,
                server = Server,
                stanza_id = StanzaId,
                pinned_at = PinnedAt
            }};
        {selected, []} ->
            error
    end.
