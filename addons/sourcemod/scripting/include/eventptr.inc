#if defined _eventptr_included
    #endinput
#endif
#define _eventptr_included

// The event must remain alive for the entire synchronous SDKCall.
native Address BB_GetGameEventAddress(Event event);

public Extension __ext_eventptr =
{
    name = "EventPtr",
    file = "eventptr.ext",
    autoload = 1,
    required = 1
};
