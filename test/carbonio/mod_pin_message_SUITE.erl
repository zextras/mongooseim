-module(mod_pin_message_SUITE).

-compile([export_all, nowarn_export_all]).
%% Common Test callbacks
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

%% Suite info
suite() ->
    [{timetrap, {minutes, 5}}].

init_per_suite(Config) ->
    ct:pal("Initializing suite~n"),
    Config.

end_per_suite(_Config) ->
    ct:pal("Ending suite~n"),
    ok.

init_per_testcase(TestCase, Config) ->
    ct:pal("Configuring test case ~p~n", [Config]),
    ct:pal("Initializing test case ~p~n", [TestCase]),
    setup(Config, TestCase).
end_per_testcase(_TestCase, _Config) ->
    ct:pal("Ending test case ~p~n", [_TestCase]),
    meck:unload(),
    ok.

all() ->
    ct:pal("Defining all test cases~n"),
    [
        pin_message_basic_test,
        pin_message_with_not_existing_message_test,
        get_pin_with_existing_pin_test,
        get_pin_with_not_existing_pin_test,
        delete_not_existing_pin_test,
        delete_pin_test,
        update_message_pinned_test,
        update_not_message_pinned_test
    ].
setup(Config, pin_message_basic_test) ->
    ct:pal("Setting up test environment~n"),
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, write, fun(_HostType, _Pin) ->
        ok
    end),
    meck:expect(mod_pin_message_backend, read, fun(_HostTypem, <<"CHFOU8II7901">>) ->
        {ok,
            {pin, 1, <<"pin1">>, <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                <<"room@localhost">>, <<"alice">>, <<"localhost">>, <<"CHFOU8II7901">>, {
                    {2026, 1, 7}, {14, 4, 35.560348}
                }}}
    end),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> true end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun
        (
            _From,
            _To,
            {xmlel, <<"iq">>,
                #{
                    <<"id">> := <<"pin1">>,
                    <<"type">> := <<"result">>
                },
                [
                    {xmlel, <<"pin">>,
                        #{
                            <<"xmlns">> := <<"zextras:iq:pin">>,
                            <<"message-id">> := <<"CHFOU8II7901">>
                        },
                        [
                            {xmlel, <<"pinned-by">>, #{}, [
                                {xmlcdata,
                                    <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                                    escaped}
                            ]},
                            {xmlel, <<"room-id">>, #{}, [{xmlcdata, <<"room@localhost">>, escaped}]},
                            {xmlel, <<"pinned-at">>, #{}, [
                                {xmlcdata, <<"1767794675560348">>, escaped}
                            ]}
                        ]}
                ]}
        ) ->
            ok;
        (
            {jid, <<"alice">>, <<"localhost">>, <<>>},
            {jid, <<"room">>, <<"localhost">>, <<>>},
            {xmlel, <<"message">>,
                #{
                    <<"id">> := _,
                    <<"type">> :=
                        <<"groupchat">>,
                    <<"xmlns">> :=
                        <<"jabber:client">>
                },
                [
                    {xmlel, <<"x">>,
                        #{
                            <<"xmlns">> :=
                                <<"urn:xmpp:muclight:0#configuration">>
                        },
                        [
                            {xmlel, <<"operation">>, #{}, [
                                {xmlcdata, <<"messagePinned">>, escaped}
                            ]},
                            {xmlel, <<"pin">>,
                                #{
                                    <<"xmlns">> :=
                                        <<"zextras:iq:pin">>,
                                    <<"message-id">> :=
                                        <<"CHFOU8II7901">>
                                },
                                [
                                    {xmlel, <<"pinned-by">>, #{}, [
                                        {xmlcdata,
                                            <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                                            escaped}
                                    ]},
                                    {xmlel, <<"room-id">>, #{}, [
                                        {xmlcdata, <<"room@localhost">>, escaped}
                                    ]},
                                    {xmlel, <<"pinned-at">>, #{}, [
                                        {xmlcdata, <<"1767794675560348">>, escaped}
                                    ]}
                                ]}
                        ]},
                    {xmlel, <<"body">>, #{}, []}
                ]}
        ) ->
            ok
    end),
    [
        {acc, default_accumulator()}
        | Config
    ];
setup(Config, get_pin_with_existing_pin_test) ->
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> false end),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, get_pin_by_room_id, fun(
        _HostTypem, <<"1765-785258-62595@muclight.localhost">>
    ) ->
        {ok,
            {pin, 1, <<"pin1">>, <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                <<"room@localhost">>, <<"alice">>, <<"localhost">>, <<"CHFOU8II7901">>, {
                    {2026, 1, 7}, {14, 4, 35.560348}
                }}}
    end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun(
        _From,
        _To,
        {xmlel, <<"iq">>,
            #{
                <<"id">> := <<"pin1">>,
                <<"type">> := <<"result">>
            },
            [
                {xmlel, <<"pin">>,
                    #{<<"xmlns">> := <<"zextras:iq:pin">>, <<"message-id">> := <<"CHFOU8II7901">>},
                    [
                        {xmlel, <<"pinned-by">>, #{}, [
                            {xmlcdata, <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                                escaped}
                        ]},
                        {xmlel, <<"room-id">>, #{}, [{xmlcdata, <<"room@localhost">>, escaped}]},
                        {xmlel, <<"pinned-at">>, #{}, [{xmlcdata, <<"1767794675560348">>, escaped}]}
                    ]}
            ]}
    ) ->
        ok
    end),
    [
        {acc, get_pin_accumulator()}
        | Config
    ];
setup(Config, pin_message_with_not_existing_message_test) ->
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> false end),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, read, fun(_HostTypem, <<"CHFOU8II7901">>) -> error end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun(
        _From,
        _To,
        {xmlel, <<"iq">>,
            #{
                <<"id">> := <<"pin1">>,
                <<"type">> := <<"error">>
            },
            [
                {xmlel, <<"error">>,
                    #{
                        <<"type">> := <<"modify">>
                    },
                    [
                        {xmlel, <<"bad-request">>,
                            #{
                                <<"xmlns">> := <<"urn:ietf:params:xml:ns:xmpp-stanzas">>
                            },
                            []}
                    ]}
            ]}
    ) ->
        ok
    end),
    [
        {acc, default_accumulator()}
        | Config
    ];
setup(Config, get_pin_with_not_existing_pin_test) ->
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> false end),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, get_pin_by_room_id, fun(_HostTypem, _) ->
        error
    end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun(
        _From,
        _To,
        {xmlel, <<"iq">>,
            #{
                <<"id">> := <<"pin1">>,
                <<"type">> := <<"error">>
            },
            [
                {xmlel, <<"error">>,
                    #{
                        <<"type">> := <<"modify">>
                    },
                    [
                        {xmlel, <<"bad-request">>,
                            #{
                                <<"xmlns">> := <<"urn:ietf:params:xml:ns:xmpp-stanzas">>
                            },
                            []}
                    ]}
            ]}
    ) ->
        ok
    end),
    [
        {acc, get_pin_accumulator()}
        | Config
    ];
setup(Config, delete_pin_test) ->
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, delete, fun(_, _) -> ok end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun
        (
            _From,
            _To,
            {xmlel, <<"message">>,
                #{
                    <<"type">> := <<"groupchat">>,
                    <<"xmlns">> := <<"jabber:client">>
                },
                [
                    {xmlel, <<"x">>,
                        #{
                            <<"xmlns">> :=
                                <<"urn:xmpp:muclight:0#configuration">>
                        },
                        [
                            {xmlel, <<"operation">>, #{}, [
                                {xmlcdata, <<"messageUnpinned">>, escaped}
                            ]},
                            {xmlel, <<"pin">>, #{<<"message-id">> := <<"CHFOU8II7901">>}, []}
                        ]},
                    {xmlel, <<"body">>, #{}, []}
                ]}
        ) ->
            ok;
        (
            _,
            _,
            {xmlel, <<"iq">>,
                #{
                    <<"id">> := <<"pin1">>,
                    <<"type">> := <<"result">>
                },
                []}
        ) ->
            ok
    end),
    [
        {acc, delete_pin_accumulator()}
        | Config
    ];
setup(Config, delete_not_existing_pin_test) ->
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, delete, fun(_, _) -> error end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun(
        _From,
        _To,
        {xmlel, <<"iq">>,
            #{
                <<"id">> := <<"pin1">>,
                <<"type">> := <<"error">>
            },
            [
                {xmlel, <<"error">>,
                    #{
                        <<"type">> := <<"modify">>
                    },
                    [
                        {xmlel, <<"bad-request">>,
                            #{
                                <<"xmlns">> := <<"urn:ietf:params:xml:ns:xmpp-stanzas">>
                            },
                            []}
                    ]}
            ]}
    ) ->
        ok
    end),
    [
        {acc, delete_pin_accumulator()}
        | Config
    ];
setup(Config, update_message_pinned_test) ->
    ct:pal("Setting up test environment~n"),
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, write, fun(_HostType, _Pin) ->
        ok
    end),
    meck:expect(mod_pin_message_backend, read, fun(_HostTypem, <<"CHFOU8II7901">>) ->
        {ok,
            {pin, 1, <<"pin1">>, <<"alice@localhost/1767-794620-784818-99cf5269796ab5ee">>,
                <<"room@localhost">>, <<"alice">>, <<"localhost">>, <<"CHFOU8II7901">>, {
                    {2026, 1, 7}, {14, 4, 35.560348}
                }}}
    end),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> true end),
    meck:new(ejabberd_router, [passthrough]),
    meck:expect(ejabberd_router, route, fun(
        _From,
        _To,
        {xmlel, <<"message">>,
            #{
                <<"id">> :=
                    _,
                <<"type">> := <<"groupchat">>,
                <<"xmlns">> := <<"jabber:client">>
            },
            [
                {xmlel, <<"x">>, #{<<"xmlns">> := <<"urn:xmpp:muclight:0#configuration">>}, [
                    {xmlel, <<"operation">>, #{}, [{xmlcdata, <<"messagePinned">>, escaped}]},
                    {xmlel, <<"pin">>,
                        #{
                            <<"xmlns">> := <<"zextras:iq:pin">>,
                            <<"message-id">> := <<"CHFOU8II7901">>
                        },
                        [
                            {xmlel, <<"pinned-by">>, #{}, [
                                {xmlcdata, <<"bob@localhost">>, escaped}
                            ]},
                            {xmlel, <<"room-id">>, #{}, [
                                {xmlcdata, _, escaped}
                            ]},
                            {xmlel, <<"pinned-at">>, #{}, [{xmlcdata, _, escaped}]}
                        ]}
                ]},
                {xmlel, <<"body">>, #{}, []}
            ]}
    ) ->
        ok
    end),
    [
        {acc, update_pin_accumulator()}
        | Config
    ];
setup(Config, update_not_message_pinned_test) ->
    ct:pal("Setting up test environment~n"),
    meck:new(mod_pin_message_backend, [passthrough]),
    meck:expect(mod_pin_message_backend, init, fun(_HostType, _Opts) -> ok end),
    meck:expect(mod_pin_message_backend, write, fun(_HostType, _Pin) ->
        ok
    end),
    meck:expect(mod_pin_message_backend, read, fun(_HostTypem, <<"CHFOU8II7901">>) ->
        error
    end),
    meck:expect(mod_pin_message_backend, check_message_exists, fun(_, _) -> true end),

    [
        {acc, update_pin_accumulator()}
        | Config
    ];
setup(Config, _TestCase) ->
    Config.

pin_message_basic_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)),
    ?assert(meck:validate(mod_pin_message_backend)).

pin_message_with_not_existing_message_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)).
get_pin_with_existing_pin_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)).
get_pin_with_not_existing_pin_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)).

delete_not_existing_pin_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)).

delete_pin_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({stop, drop}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)),
    ?assert(meck:validate(mod_pin_message_backend)).
update_message_pinned_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({ok, Acc}, mod_pin_message:pin_message(Acc, Params, Extra)),
    ?assert(meck:validate(ejabberd_router)).
update_not_message_pinned_test(Config) ->
    Acc = proplists:get_value(acc, Config),
    Params = #{},
    Extra = #{
        host_type => <<"localhost">>,
        hook_name => filter_local_packet,
        hook_tag => <<"localhost">>
    },
    ?assertEqual({ok, Acc}, mod_pin_message:pin_message(Acc, Params, Extra)).
% %% Test: Unpin a message
% pin_message_unpin_test() ->
%     ok = mog_pin_message:pin_message(<<"room2">>, <<"user2">>, <<"msg456">>),
%     ok = mog_pin_message:unpin_message(<<"room2">>, <<"user2">>),
%     {error, not_found} = mog_pin_message:get_pinned_message(<<"room2">>).

% %% Test: Pinning with invalid data
% pin_message_invalid_test() ->
%     {error, invalid_room} = mog_pin_message:pin_message(<<>>, <<"user1">>, <<"msg789">>),
%     {error, invalid_user} = mog_pin_message:pin_message(<<"room3">>, <<>>, <<"msg789">>),
%     {error, invalid_message} = mog_pin_message:pin_message(<<"room3">>, <<"user1">>, <<>>).

% %% Test: Pin multiple messages (should replace previous pin)
% pin_message_multiple_pins_test() ->
%     ok = mog_pin_message:pin_message(<<"room4">>, <<"user3">>, <<"msg111">>),
%     ok = mog_pin_message:pin_message(<<"room4">>, <<"user3">>, <<"msg222">>),
%     {ok, Pinned} = mog_pin_message:get_pinned_message(<<"room4">>),
%     ?assertEqual(<<"msg222">>, Pinned).

default_accumulator() ->
    {
        {jid, <<"alice">>, <<"localhost">>, <<"1767-792995-821901-fce4263fa3d7301d">>},
        {jid, <<"room">>, <<"localhost">>, <<>>},
        #{
            timestamp => 1767793003247273,
            ref => nil,
            mongoose_acc => true,
            lserver => <<"localhost">>,
            host_type => <<"localhost">>,
            stanza =>
                #{
                    name => <<"iq">>,
                    type => <<"set">>,
                    element =>
                        {xmlel, <<"iq">>,
                            #{
                                <<"id">> => <<"pin1">>,
                                <<"to">> => <<"room@localhost">>,
                                <<"type">> => <<"set">>,
                                <<"xmlns">> => <<"jabber:client">>
                            },
                            [
                                {xmlel, <<"pin">>,
                                    #{
                                        <<"xmlns">> => <<"zextras:iq:pin">>,
                                        <<"message-id">> => <<"CHFOU8II7901">>
                                    },
                                    []}
                            ]},
                    ref => nil,
                    to_jid => {jid, <<"room">>, <<"localhost">>, <<>>},
                    from_jid =>
                        {jid, <<"alice">>, <<"localhost">>,
                            <<"1767-792995-821901-fce4263fa3d7301d">>}
                },
            non_strippable =>
                [{c2s, module}, {c2s, origin_sid}, {c2s, origin_jid}],
            origin_location =>
                #{
                    line => 889,
                    file =>
                        "/Users/riccardodegan/work/erlang/carbonio-mongooseim/src/c2s/mongoose_c2s.erl",
                    mfa => {mongoose_c2s, element_to_origin_accum, 2}
                },
            origin_pid => nil,
            statem_acc =>
                #{
                    socket_send => [],
                    c2s_data => undefined,
                    state_mod => #{},
                    c2s_state => undefined,
                    actions => [],
                    hard_stop => undefined
                },
            {c2s, module} => mongoose_c2s,
            {c2s, origin_jid} =>
                {jid, <<"alice">>, <<"localhost">>, <<"1767-792995-821901-fce4263fa3d7301d">>},
            {c2s, origin_sid} => {1767792995790557, nil}
        },
        {xmlel, <<"iq">>,
            #{
                <<"id">> => <<"pin1">>,
                <<"to">> => <<"room@localhost">>,
                <<"type">> => <<"set">>,
                <<"xmlns">> => <<"jabber:client">>
            },
            [
                {xmlel, <<"pin">>,
                    #{<<"xmlns">> => <<"zextras:iq:pin">>, <<"message-id">> => <<"CHFOU8II7901">>},
                    []}
            ]}
    }.
get_pin_accumulator() ->
    {
        {jid, <<"bob">>, <<"localhost">>, <<"1767-958798-795846-78d63f7307200a67">>},
        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>, <<>>},
        #{
            timestamp => 1767958800975498,
            ref => undefined,
            mongoose_acc => true,
            lserver => <<"muclight.localhost">>,
            host_type => <<"localhost">>,
            stanza =>
                #{
                    name => <<"iq">>,
                    type => <<"get">>,
                    element =>
                        {xmlel, <<"iq">>,
                            #{
                                <<"id">> => <<"pin1">>,
                                <<"to">> =>
                                    <<"1765-785258-62595@muclight.localhost">>,
                                <<"type">> => <<"get">>,
                                <<"xmlns">> =>
                                    <<"jabber:client">>
                            },
                            [
                                {xmlel, <<"pin">>,
                                    #{
                                        <<"message-id">> =>
                                            <<"CHFOU8II7901">>,
                                        <<"xmlns">> =>
                                            <<"zextras:iq:pin">>
                                    },
                                    []}
                            ]},
                    ref => undefined,
                    to_jid =>
                        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>, <<>>},
                    from_jid =>
                        {jid, <<"bob">>, <<"localhost">>, <<"1767-958798-795846-78d63f7307200a67">>}
                },
            non_strippable =>
                [
                    {c2s, module},
                    {c2s, origin_sid},
                    {c2s, origin_jid}
                ],
            origin_location =>
                #{
                    line => 889,
                    file =>
                        "/Users/riccardodegan/work/erlang/carbonio-mongooseim/src/c2s/mongoose_c2s.erl",
                    mfa =>
                        {mongoose_c2s, element_to_origin_accum, 2}
                },
            origin_pid => undefined,
            statem_acc =>
                #{
                    socket_send => [],
                    c2s_data => undefined,
                    state_mod => #{},
                    c2s_state => undefined,
                    actions => [],
                    hard_stop => undefined
                },
            {c2s, module} => mongoose_c2s,
            {c2s, origin_jid} =>
                {jid, <<"bob">>, <<"localhost">>, <<"1767-958798-795846-78d63f7307200a67">>},
            {c2s, origin_sid} =>
                {1767958798707588, undefined}
        },
        {xmlel, <<"iq">>,
            #{
                <<"id">> => <<"pin1">>,
                <<"to">> =>
                    <<"1765-785258-62595@muclight.localhost">>,
                <<"type">> => <<"get">>,
                <<"xmlns">> => <<"jabber:client">>
            },
            [
                {xmlel, <<"pin">>,
                    #{
                        <<"message-id">> => <<"CHFOU8II7901">>,
                        <<"xmlns">> => <<"zextras:iq:pin">>
                    },
                    []}
            ]}
    }.

delete_pin_accumulator() ->
    {
        {jid, <<"bob">>, <<"localhost">>, <<"1767-974173-673680-d501f62252d1800f">>},
        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>, <<>>},
        #{
            timestamp => 1767974176713883,
            ref => undefined,
            mongoose_acc => true,
            lserver =>
                <<"muclight.localhost">>,
            host_type => <<"localhost">>,
            stanza =>
                #{
                    name => <<"iq">>,
                    type => <<"set">>,
                    element =>
                        {xmlel, <<"iq">>,
                            #{
                                <<"id">> => <<"pin1">>,
                                <<"to">> =>
                                    <<"1765-785258-62595@muclight.localhost">>,
                                <<"type">> => <<"set">>,
                                <<"xmlns">> =>
                                    <<"jabber:client">>
                            },
                            [
                                {xmlel, <<"pin">>,
                                    #{
                                        <<"action">> =>
                                            <<"delete">>,
                                        <<"message-id">> =>
                                            <<"CHFOU8II7902">>,
                                        <<"xmlns">> =>
                                            <<"zextras:iq:pin">>
                                    },
                                    []}
                            ]},
                    ref =>
                        undefined,
                    to_jid =>
                        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>, <<>>},
                    from_jid =>
                        {jid, <<"bob">>, <<"localhost">>, <<"1767-974173-673680-d501f62252d1800f">>}
                },
            non_strippable =>
                [
                    {c2s, module},
                    {c2s, origin_sid},
                    {c2s, origin_jid}
                ],
            origin_location =>
                #{
                    line => 889,
                    file =>
                        "/Users/riccardodegan/work/erlang/carbonio-mongooseim/src/c2s/mongoose_c2s.erl",
                    mfa =>
                        {mongoose_c2s, element_to_origin_accum, 2}
                },
            origin_pid => undefined,
            statem_acc =>
                #{
                    socket_send => [],
                    c2s_data => undefined,
                    state_mod => #{},
                    c2s_state => undefined,
                    actions => [],
                    hard_stop => undefined
                },
            {c2s, module} => mongoose_c2s,
            {c2s, origin_jid} =>
                {jid, <<"bob">>, <<"localhost">>, <<"1767-974173-673680-d501f62252d1800f">>},
            {c2s, origin_sid} =>
                {1767974173620304, undefined}
        },
        {xmlel, <<"iq">>,
            #{
                <<"id">> => <<"pin1">>,
                <<"to">> =>
                    <<"1765-785258-62595@muclight.localhost">>,
                <<"type">> => <<"set">>,
                <<"xmlns">> =>
                    <<"jabber:client">>
            },
            [
                {xmlel, <<"pin">>,
                    #{
                        <<"action">> => <<"delete">>,
                        <<"message-id">> =>
                            <<"CHFOU8II7901">>,
                        <<"xmlns">> =>
                            <<"zextras:iq:pin">>
                    },
                    []}
            ]}
    }.

update_pin_accumulator() ->
    {
        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>, <<"alice@localhost">>},
        {jid, <<"bob">>, <<"localhost">>, <<>>},
        #{
            timestamp =>
                1768292063873840,
            ref => undefined,
            mongoose_acc =>
                true,
            lserver =>
                <<"localhost">>,
            host_type =>
                <<"localhost">>,
            stanza =>
                #{
                    name =>
                        <<"message">>,
                    type =>
                        <<"groupchat">>,
                    element =>
                        {xmlel, <<"message">>,
                            #{
                                <<"from">> =>
                                    <<"1765-785258-62595@muclight.localhost/alice@localhost">>,
                                <<"id">> =>
                                    <<"533aeb61-97a4-4f95-bef0-cbbc19215ae6">>,
                                <<"to">> =>
                                    <<"bob@localhost">>,
                                <<"type">> =>
                                    <<"groupchat">>
                            },
                            [
                                {xmlel, <<"apply-to">>,
                                    #{
                                        <<"id">> =>
                                            <<"CHFOU8II7901">>,
                                        <<"xmlns">> =>
                                            <<"urn:xmpp:fasten:0">>
                                    },
                                    [
                                        {xmlel, <<"edit">>,
                                            #{
                                                <<"xmlns">> =>
                                                    <<"zextras:xmpp:edit:0">>
                                            },
                                            []},
                                        {xmlel, <<"external">>,
                                            #{
                                                <<"name">> =>
                                                    <<"body">>
                                            },
                                            []}
                                    ]},
                                {xmlel, <<"body">>, #{}, [
                                    {xmlcdata, <<"test messaggio modificato">>, escaped}
                                ]},
                                {xmlel, <<"stanza-id">>,
                                    #{
                                        <<"by">> =>
                                            <<"1765-785258-62595@muclight.localhost">>,
                                        <<"id">> =>
                                            <<"CHFOU8II7901">>,
                                        <<"xmlns">> =>
                                            <<"urn:xmpp:sid:0">>
                                    },
                                    []}
                            ]},
                    ref =>
                        undefined,
                    to_jid =>
                        {jid, <<"bob">>, <<"localhost">>, <<>>},
                    from_jid =>
                        {jid, <<"1765-785258-62595">>, <<"muclight.localhost">>,
                            <<"alice@localhost">>}
                },
            non_strippable =>
                [
                    {c2s, module},
                    {c2s, origin_sid},
                    {c2s, origin_jid}
                ],
            origin_location =>
                #{
                    line =>
                        264,
                    file =>
                        "/Users/riccardodegan/work/erlang/carbonio-mongooseim/src/muc_light/mod_muc_light_room.erl",
                    mfa =>
                        {mod_muc_light_room, make_handler_fun, 1}
                },
            origin_pid =>
                undefined,
            statem_acc =>
                #{
                    socket_send =>
                        [],
                    c2s_data =>
                        undefined,
                    state_mod =>
                        #{},
                    c2s_state =>
                        undefined,
                    actions =>
                        [],
                    hard_stop =>
                        undefined
                },
            {c2s, module} =>
                mongoose_c2s,
            {c2s, origin_jid} =>
                {jid, <<"alice">>, <<"localhost">>, <<"1768-292047-165089-38e41f00e97b428e">>},
            {c2s, origin_sid} =>
                {1768292047158159, undefined}
        },
        {xmlel, <<"message">>,
            #{
                <<"from">> =>
                    <<"1765-785258-62595@muclight.localhost/alice@localhost">>,
                <<"id">> =>
                    <<"533aeb61-97a4-4f95-bef0-cbbc19215ae6">>,
                <<"to">> =>
                    <<"bob@localhost">>,
                <<"type">> =>
                    <<"groupchat">>
            },
            [
                {xmlel, <<"apply-to">>,
                    #{
                        <<"id">> =>
                            <<"CHFOU8II7901">>,
                        <<"xmlns">> =>
                            <<"urn:xmpp:fasten:0">>
                    },
                    [
                        {xmlel, <<"edit">>,
                            #{
                                <<"xmlns">> =>
                                    <<"zextras:xmpp:edit:0">>
                            },
                            []},
                        {xmlel, <<"external">>,
                            #{
                                <<"name">> =>
                                    <<"body">>
                            },
                            []}
                    ]},
                {xmlel, <<"body">>, #{}, [{xmlcdata, <<"test messaggio modificato">>, escaped}]},
                {xmlel, <<"stanza-id">>,
                    #{
                        <<"by">> =>
                            <<"1765-785258-62595@muclight.localhost">>,
                        <<"id">> =>
                            <<"CHFOU8II7901">>,
                        <<"xmlns">> =>
                            <<"urn:xmpp:sid:0">>
                    },
                    []}
            ]}
    }.
