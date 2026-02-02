-module(mod_pin_message).

-behaviour(gen_mod).

-include("mongoose.hrl").
-include("mongoose_logger.hrl").
-include("mod_muc_light.hrl").
-include("jlib.hrl").
-include("pin.hrl").
-include("mongoose_config_spec.hrl").

-export([pin_message/3, room_process_pin_iq/5, disco_local_features/3,
         disco_muc_features/3]).
-export([start/2, stop/1, supported_features/0, hooks/1, config_spec/0]).

-define(NS_PIN, <<"zextras:iq:pin">>).

start(HostType, Opts) ->
    mod_pin_message_backend:init(HostType, Opts),
    add_iq_handlers(HostType, Opts),
    ok.

stop(HostType) ->
    remove_iq_handlers(HostType),
    ok.

-spec config_spec() -> mongoose_config_spec:config_section().
config_spec() ->
    #section{items =
                 #{<<"backend">> => #option{type = atom, validate = {module, mod_pin_message}}},
             defaults = #{<<"backend">> => rdbms}}.

supported_features() ->
    [dynamic_domains].

hooks(HostType) ->
    [{disco_local_features, HostType, fun ?MODULE:disco_local_features/3, #{}, 99},
     {disco_muc_features, HostType, fun ?MODULE:disco_muc_features/3, #{}, 99},
     {filter_local_packet, HostType, fun mod_pin_message:pin_message/3, #{}, 90}].

-spec pin_message(Acc, Params, Extra) -> {ok, Acc}
    when Acc :: mongoose_hooks:filter_packet_acc(),
         Params :: map(),
         Extra :: map().
pin_message({From,
             To,
             _Acc,
             {xmlel,
              <<"iq">>,
              #{<<"id">> := RequestId, <<"type">> := <<"set">>},
              [{xmlel,
                <<"pin">>,
                #{<<"message-id">> := MessageId, <<"action">> := <<"delete">>},
                _}]}},
            _Params,
            #{host_type := HostType} = _Extra) ->
    handle_delete_pin(HostType, From, To, RequestId, MessageId);
pin_message({From,
             To,
             _Acc,
             {xmlel,
              <<"iq">>,
              #{<<"id">> := RequestId, <<"type">> := <<"set">>},
              [{xmlel, <<"pin">>, #{<<"message-id">> := MessageId}, _}]}},
            _Params,
            #{host_type := HostType} = _Extra) ->
    PinnedBy = From,
    case pin:xml_to_pin(PinnedBy, To, RequestId, MessageId) of
        {ok, Pin} ->
            handle_check_message_exists(HostType, From, To, RequestId, Pin);
        {error, {invalid_xml, RequestId}} ->
            handle_error(From, To, RequestId)
    end;
pin_message({From,
             To,
             _Acc,
             {xmlel,
              <<"iq">>,
              #{<<"id">> := RequestId,
                <<"type">> := <<"get">>,
                <<"to">> := RoomId},
              [{xmlel, <<"pin">>, #{}, _}] = _SubEl}},
            _Params,
            #{host_type := HostType} = _Extra) ->
    handle_get_and_send_pin(HostType, From, To, RequestId, RoomId);
pin_message({From,
             To,
             _Acc,
             {xmlel,
              <<"message">>,
              #{<<"id">> := RequestId},
              [{xmlel,
                <<"apply-to">>,
                #{<<"id">> := _ParentStanzaId,
                  <<"xmlns">> := <<"urn:xmpp:fasten:0">>,
                  <<"parent-id">> := ParentStanzaId},
                [{xmlel, <<"edit">>, #{<<"xmlns">> := <<"zextras:xmpp:edit:0">>}, []},
                 {xmlel, <<"external">>, #{<<"name">> := <<"body">>}, []}]},
               {xmlel, <<"body">>, #{}, [{xmlcdata, Body, escaped}]},
               {xmlel, <<"stanza-id">>, #{<<"id">> := NewStanzaId}, []}]} =
                 _Xml} =
                CompleteAcc,
            _Params,
            #{host_type := HostType} = _Extra) ->
    case pin:xml_to_pin(To, From, RequestId, NewStanzaId, Body) of
        {ok, Pin} ->
            handle_check_pin_exists(HostType,
                                    From,
                                    To,
                                    RequestId,
                                    Pin,
                                    ParentStanzaId,
                                    CompleteAcc);
        {error, {invalid_xml, RequestId}} ->
            handle_error(From, To, RequestId)
    end;
pin_message({_, _, _, _Xml} = Acc, _Params, _Extra) ->
    {ok, Acc}.

handle_check_pin_exists(HostType,
                        From,
                        To,
                        RequestId,
                        #pin{stanza_id = _StanzaId} = Pin,
                        ParentStanzaId,
                        CompleteAcc) ->
    case pin:get_pin(HostType, ParentStanzaId) of
        {ok, _Pin} ->
            handle_create_pin_and_send_only_message(HostType, From, To, RequestId, Pin),
            {ok, CompleteAcc};
        error ->
            {ok, CompleteAcc}
    end.

handle_check_message_exists(HostType,
                            From,
                            To,
                            RequestId,
                            #pin{stanza_id = StanzaId} = Pin) ->
    ConvertedStanzaId = mod_mam_utils:external_binary_to_mess_id(StanzaId),
    handle_create_pin(pin:check_message_exists(HostType, ConvertedStanzaId),
                      HostType,
                      From,
                      To,
                      RequestId,
                      Pin).

handle_create_pin_and_send_only_message(HostType,
                                        From,
                                        To,
                                        RequestId,
                                        #pin{stanza_id = _StanzaId} = Pin) ->
    case pin:write(HostType, Pin) of
        ok ->
            send_message_updated_pin(From, To, Pin),
            {stop, drop};
        {error, _Reason} ->
            handle_error(From, To, RequestId)
    end.

handle_create_pin(true,
                  HostType,
                  From,
                  To,
                  RequestId,
                  #pin{stanza_id = StanzaId} = Pin) ->
    case pin:write(HostType, Pin) of
        ok ->
            handle_send_pin_after_create(HostType, From, To, RequestId, StanzaId);
        {error, _Reason} ->
            handle_error(From, To, RequestId)
    end;
handle_create_pin(false, _HostType, From, To, RequestId, _Pin) ->
    handle_error(From, To, RequestId).

handle_send_pin_after_create(HostType, From, To, RequestId, StanzaId) ->
    case pin:get_pin(HostType, StanzaId) of
        {ok, Pin} ->
            Result = handle_send_pin(From, To, RequestId, Pin),
            send_message_pin(From, To, Pin),
            Result;
        error ->
            handle_error(From, To, RequestId)
    end.

handle_get_and_send_pin(HostType, From, To, RequestId, RoomId) ->
    case pin:get_pin_by_room_id(HostType, RoomId) of
        {ok, Pin} ->
            handle_send_pin(From, To, RequestId, Pin);
        error ->
            handle_error(From, To, RequestId)
    end.

handle_send_pin(From, To, RequestId, Pin) ->
    ResponseSubEl = pin:pin_to_xml(Pin),
    Response =
        #iq{type = result,
            id = RequestId,
            sub_el = ResponseSubEl},
    Xml = jlib:iq_to_xml(Response),
    ejabberd_router:route(To, From, Xml),
    {stop, drop}.

handle_delete_pin(HostType, From, To, RequestId, StanzaId) ->
    case pin:delete(HostType, StanzaId) of
        ok ->
            send_delete_answer(From, To, RequestId),
            send_unpin_notification(From, To, StanzaId),
            {stop, drop};
        error ->
            handle_error(From, To, RequestId)
    end.

send_delete_answer(From, To, RequestId) ->
    Response =
        #iq{type = result,
            id = RequestId,
            sub_el = []},
    Xml = jlib:iq_to_xml(Response),
    ejabberd_router:route(To, From, Xml),
    {stop, drop}.

send_unpin_notification(#jid{luser = FromUser, lserver = FromServer}, To, StanzaId) ->
    Uuid = pin:generate_uuid(),
    NewJid = jid:make(<<"room">>, <<"localhost">>, Uuid),
    Msg = #msg{id = jid:to_binary(NewJid),
               children =
                   [#xmlel{name = <<"pin">>,
                           attrs =
                               #{<<"message-id">> => StanzaId, <<"xmlns">> => <<"zextras:iq:pin">>},
                           children = []}]},
    MsgXml = pin:unpin_message_to_xml(Msg),
    ejabberd_router:route(
        jid:make(FromUser, FromServer, <<>>), To, MsgXml),
    ok.

handle_error(From, To, RequestId) ->
    ErrorSubEl =
        {xmlel,
         <<"error">>,
         #{<<"type">> => <<"modify">>},
         [{xmlel,
           <<"bad-request">>,
           #{<<"xmlns">> => <<"urn:ietf:params:xml:ns:xmpp-stanzas">>},
           []}]},
    ErrorIq =
        #iq{type = error,
            id = RequestId,
            sub_el = ErrorSubEl},
    ErrorXml = jlib:iq_to_xml(ErrorIq),
    ejabberd_router:route(To, From, ErrorXml),
    {stop, drop}.

send_message_pin(#jid{luser = FromUser, lserver = FromServer} = _From, To, Pin) ->
    Uuid = pin:generate_uuid(),
    Msg = #msg{id = Uuid, children = [Pin]},
    MsgXml = pin:message_to_xml(Msg),
    ejabberd_router:route(
        jid:make(FromUser, FromServer, <<>>), To, MsgXml),
    ok.

send_message_updated_pin(#jid{luser = FromUser, lserver = FromServer} = From,
                         _To = #jid{luser = ToUser, lserver = ToServer},
                         Pin) ->
    Uuid = pin:generate_uuid(),
    Msg = #msg{id = Uuid, children = [Pin]},
    MsgXml = pin:updated_message_to_xml(Msg),
    ejabberd_router:route(
        jid:make(ToUser, ToServer, <<>>), jid:make(FromUser, FromServer, <<>>), MsgXml),
    ok.

%% IQ handler registration for MUC rooms
add_iq_handlers(HostType, Opts) ->
    IQDisc = gen_mod:get_opt(iqdisc, Opts, parallel),
    %% Register for MUC Light rooms
    MUCLightSubdomainPattern =
        gen_mod:get_module_opt(HostType, mod_muc_light, host, <<"muclight.@HOST@">>),
    gen_iq_handler:add_iq_handler_for_subdomain(HostType,
                                                MUCLightSubdomainPattern,
                                                ?NS_PIN,
                                                mod_muc_iq,
                                                fun ?MODULE:room_process_pin_iq/5,
                                                #{},
                                                IQDisc),
    %% Ensure the handler is fully registered before returning
    %% This prevents race conditions where IQ requests arrive before registration completes
    mod_muc_iq:sync(),
    ok.

remove_iq_handlers(HostType) ->
    MUCLightSubdomainPattern =
        gen_mod:get_module_opt(HostType, mod_muc_light, host, <<"muclight.@HOST@">>),
    gen_iq_handler:remove_iq_handler_for_subdomain(HostType,
                                                   MUCLightSubdomainPattern,
                                                   ?NS_PIN,
                                                   mod_muc_iq),
    ok.

%% IQ handler callback for room pin requests
-spec room_process_pin_iq(mongoose_acc:t(), jid:jid(), jid:jid(), jlib:iq(), map()) ->
                             {mongoose_acc:t(), jlib:iq()}.
room_process_pin_iq(Acc, _From, To, #iq{type = get} = IQ, _Extra) ->
    HostType = mongoose_acc:host_type(Acc),
    RoomId =
        jid:to_binary(
            jid:to_bare(To)),
    case pin:get_pin_by_room_id(HostType, RoomId) of
        {ok, Pin} ->
            ResponseSubEl = pin:pin_to_xml(Pin),
            {Acc, IQ#iq{type = result, sub_el = [ResponseSubEl]}};
        error ->
            ErrorSubEl =
                #xmlel{name = <<"error">>,
                       attrs = #{<<"type">> => <<"modify">>},
                       children =
                           [#xmlel{name = <<"bad-request">>,
                                   attrs =
                                       #{<<"xmlns">> => <<"urn:ietf:params:xml:ns:xmpp-stanzas">>},
                                   children = []}]},
            {Acc, IQ#iq{type = error, sub_el = [ErrorSubEl]}}
    end;
room_process_pin_iq(Acc, _From, _To, IQ, _Extra) ->
    %% For set requests, return feature-not-implemented as they should go through the normal message flow
    Error =
        mongoose_xmpp_errors:feature_not_implemented(<<"en">>,
                                                     <<"Use message stanza to set pins">>),
    {Acc, IQ#iq{type = error, sub_el = [Error]}}.

%% Disco feature hooks
-spec disco_local_features(Acc, Params, Extra) -> {ok, Acc}
    when Acc :: mongoose_disco:feature_acc(),
         Params :: map(),
         Extra :: map().
disco_local_features(Acc = #{node := <<>>}, _Params, _Extra) ->
    {ok, mongoose_disco:add_features([?NS_PIN], Acc)};
disco_local_features(Acc, _Params, _Extra) ->
    {ok, Acc}.

-spec disco_muc_features(Acc, Params, Extra) -> {ok, Acc}
    when Acc :: mongoose_disco:feature_acc(),
         Params :: map(),
         Extra :: map().
disco_muc_features(Acc = #{node := <<>>}, _Params, _Extra) ->
    {ok, mongoose_disco:add_features([?NS_PIN], Acc)};
disco_muc_features(Acc, _Params, _Extra) ->
    {ok, Acc}.
