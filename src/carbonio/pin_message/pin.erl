-module(pin).
-include("pin.hrl").
-include("jlib.hrl").
-include("mod_muc_light.hrl").
-export([
    xml_to_pin/4,
    xml_to_pin/5,
    pin_to_xml/1,
    datetime_to_timestamp/1,
    datetime_to_binary/1,
    message_to_xml/1,
    unpin_message_to_xml/1,
    generate_uuid/0,
    get_pin/2,
    check_message_exists/2,
    write/2,
    delete/2,
    get_pin_by_room_id/2,
    updated_message_to_xml/1
]).

-spec write(mongooseim:host_type(), #pin{}) -> ok | {error, any()}.
write(HostType, #pin{} = Pin) ->
    mod_pin_message_backend:write(HostType, Pin).

-spec check_message_exists(mongooseim:host_type(), binary()) -> boolean().
check_message_exists(HostType, StanzaId) ->
    mod_pin_message_backend:check_message_exists(HostType, StanzaId).

-spec get_pin(mongooseim:host_type(), binary()) -> {ok, #pin{}} | error.
get_pin(HostType, StanzaId) ->
    mod_pin_message_backend:read(HostType, StanzaId).

-spec delete(mongooseim:host_type(), binary()) -> ok | error.
delete(HostType, StanzaId) ->
    mod_pin_message_backend:delete(HostType, StanzaId).

get_pin_by_room_id(HostType, RoomId) ->
    mod_pin_message_backend:get_pin_by_room_id(HostType, RoomId).

-spec xml_to_pin(
    PinnedBy :: binary(),
    RoomId :: binary(),
    RequestId :: binary(),
    Xml :: exml:element(),
    Body :: binary()
) -> {ok, #pin{}} | {error, {invalid_xml, binary()}}.
xml_to_pin(PinnedBy, RoomId, RequestId, Xml, Body) ->   
    case xml_to_pin(PinnedBy, RoomId, RequestId, Xml) of
        {ok, Pin} -> {ok, Pin#pin{body = Body}};
        {error, Reason} -> error(Reason)
    end.

-spec xml_to_pin(
    PinnedBy :: binary(),
    RoomId :: binary(),
    RequestId :: binary(),
    Xml :: exml:element()
) -> {ok, #pin{}} | {error, {invalid_xml, binary()}}.
xml_to_pin(
    #jid{luser = LUser, lserver = LServer} = PinnedBy,
    RoomId,
    RequestId,
    [{xmlel, <<"pin">>, _, [{xmlel, <<"message-id">>, _, [{xmlcdata, MessageId, escaped}]}]}] = _xml
) ->
    %% Convert RoomId JID to binary if needed
    RoomIdBin =
        case RoomId of
            #jid{} -> jid:to_binary(RoomId);
            Bin when is_binary(Bin) -> Bin
        end,

    Pin = #pin{
        luser = LUser,
        server = LServer,
        request_id = RequestId,
        pinned_by = jid:to_binary(PinnedBy),
        room_id = RoomIdBin,
        stanza_id = MessageId
    },
    {ok, Pin};
xml_to_pin(
    #jid{luser = LUser, lserver = LServer} = PinnedBy,
    #jid{luser = LUserRoom, lserver = LServerRoom},
    RequestId,
    MessageId
) when is_binary(MessageId) ->
    NewRoomJid = #jid{luser = LUserRoom, lserver = LServerRoom},
    RoomIdBin = jid:to_binary(NewRoomJid),

    Pin = #pin{
        luser = LUser,
        server = LServer,
        request_id = RequestId,
        pinned_by = jid:to_binary(PinnedBy),
        room_id = RoomIdBin,
        stanza_id = MessageId
    },
    {ok, Pin};
xml_to_pin(_, _, RequestId, _) ->
    {error, {invalid_xml, RequestId}}.


-spec updated_message_to_xml(#msg{}) -> exml:element() | error.
updated_message_to_xml(#msg{id = MessageId, children = [#pin{} = Pin]}) ->
    #xmlel{
        name = <<"message">>,
        attrs = #{
            <<"id">> => MessageId, <<"type">> => <<"groupchat">>, <<"xmlns">> => <<"jabber:client">>
        },
        children = [
            #xmlel{
                name = <<"x">>,
                attrs = #{<<"xmlns">> => <<"urn:xmpp:muclight:0#configuration">>},
                children = [
                    #xmlel{
                        name = <<"operation">>,
                        attrs = #{},
                        children = [{xmlcdata, <<"messagePinUpdated">>, escaped}]
                    },
                    pin_to_xml(Pin)
                ]
            }
        ]
    };
updated_message_to_xml(_) ->
    error.
-spec pin_to_xml(#pin{}) -> exml:element().
pin_to_xml(#pin{
    request_id = _RequestId,
    pinned_by = PinnedBy,
    room_id = RoomId,
    stanza_id = StanzaId,
    pinned_at = PinnedAt,
    body = Body
}) ->
    {xmlel, <<"pin">>, #{<<"xmlns">> => <<"zextras:iq:pin">>, <<"message-id">> => StanzaId}, [
        % {xmlel, <<"message-id">>, #{}, [{xmlcdata, StanzaId, escaped}]},
        {xmlel, <<"pinned-by">>, #{}, [{xmlcdata, jid_to_bin(PinnedBy), escaped}]},
        {xmlel, <<"room-id">>, #{}, [{xmlcdata, jid_to_bin(RoomId), escaped}]},
        {xmlel, <<"pinned-at">>, #{}, [
            {xmlcdata, datetime_to_binary(PinnedAt), escaped}
        ]},
        {xmlel, <<"body">>, #{}, [{xmlcdata, get_body(Body), escaped}]}
    
    ]}.
-spec message_to_xml(#msg{}) -> exml:element() | error.
message_to_xml(#msg{id = MessageId, children = [#pin{} = Pin]}) ->
    #xmlel{
        name = <<"message">>,
        attrs = #{
            <<"id">> => MessageId, <<"type">> => <<"groupchat">>, <<"xmlns">> => <<"jabber:client">>
        },
        children = [
            #xmlel{
                name = <<"x">>,
                attrs = #{<<"xmlns">> => <<"urn:xmpp:muclight:0#configuration">>},
                children = [
                    #xmlel{
                        name = <<"operation">>,
                        attrs = #{},
                        children = [{xmlcdata, <<"messagePinned">>, escaped}]
                    },
                    pin_to_xml(Pin)
                ]
            },
            #xmlel{
                name = <<"body">>,
                attrs = #{},
                children = []
            }
        ]
    };
message_to_xml(_) ->
    error.
-spec unpin_message_to_xml(#msg{}) -> exml:element() | error.
unpin_message_to_xml(#msg{id = MessageId, children = Children}) ->
    #xmlel{
        name = <<"message">>,
        attrs = #{
            <<"id">> => MessageId, <<"type">> => <<"groupchat">>, <<"xmlns">> => <<"jabber:client">>
        },
        children = [
            #xmlel{
                name = <<"x">>,
                attrs = #{<<"xmlns">> => <<"urn:xmpp:muclight:0#configuration">>},
                children = [
                    #xmlel{
                        name = <<"operation">>,
                        attrs = #{},
                        children = [{xmlcdata, <<"messageUnpinned">>, escaped}]
                    }
                    | Children
                ]
            },
            #xmlel{
                name = <<"body">>,
                attrs = #{},
                children = []
            }
        ]
    };
unpin_message_to_xml(_) ->
    error.
-spec generate_uuid() -> binary().
generate_uuid() ->
    UuidState = uuid:new(self()),
    {Uuid, _} = uuid:get_v1(UuidState),
    UuidStr = uuid:uuid_to_string(Uuid),
    list_to_binary(UuidStr).

jid_to_bin(Jid) when is_tuple(Jid) -> jid:to_binary(Jid);
jid_to_bin(Bin) when is_binary(Bin) -> Bin;
jid_to_bin(undefined) -> <<>>.

int_to_bin(Int) when is_integer(Int) -> integer_to_binary(Int);
int_to_bin(Bin) when is_binary(Bin) -> Bin;
int_to_bin(undefined) -> <<>>.

datetime_to_binary({Date, {H, M, S}}) ->
    %TODO: verificare conversione
    Timestamp = datetime_to_timestamp({Date, {H, M, S}}),
    int_to_bin(Timestamp);
datetime_to_binary(_Data) ->
    <<>>.

%% Convert PostgreSQL datetime tuple to Unix timestamp in microseconds
-spec datetime_to_timestamp(calendar:datetime()) -> integer().
datetime_to_timestamp({Date, {H, M, S}}) ->
    SecInt = trunc(S),
    Microsec = round((S - SecInt) * 1000000),
    GregorianSec = calendar:datetime_to_gregorian_seconds({Date, {H, M, SecInt}}),
    %% Offset from year 0 to Unix epoch (1970)
    UnixSec = GregorianSec - 62167219200,
    UnixSec * 1000000 + Microsec.

%% Helper to get body, returning empty binary if undefined
get_body(undefined) -> <<>>;
get_body(Body) when is_binary(Body) -> Body.
