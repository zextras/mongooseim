-ifndef(MONGOOSEIM_PIN_HRL).
-define(MONGOOSEIM_PIN_HRL, true).

%% Load record definitions.
-include_lib("exml/include/exml.hrl").

-record(pin, {
    id :: integer(),
    request_id :: binary(),
    pinned_by :: binary(),
    room_id :: binary(),
    luser :: binary(),
    server :: binary(),
    stanza_id :: binary(),
    pinned_at :: integer(),
    body :: binary()
}).

-endif.
