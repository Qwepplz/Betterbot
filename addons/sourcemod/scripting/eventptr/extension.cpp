#include <IExtensionSys.h>
#include <IHandleSys.h>
#include <cstdio>
#include <cstdint>
#include <cstring>

using namespace SourceMod;
using namespace SourcePawn;

namespace {
IHandleSys *g_Handles = nullptr;

// EventInfo::pEvent is the first field in SourceMod 1.12.0.7253,
// core/EventManager.h at 2e229b111534b1be007dc3bd9acfcf2fc472e893.
// Read the pointer only after IHandleSys validates the GameEvent handle.
cell_t GetGameEventAddress(IPluginContext *context, const cell_t *params)
{
    static_assert(sizeof(void *) == sizeof(cell_t), "Requires a 32-bit target");
    if (params[0] != 1 || !g_Handles)
        return context->ThrowNativeError("GameEvent conversion is unavailable");

    HandleType_t type;
    if (!g_Handles->FindHandleType("GameEvent", &type))
        return context->ThrowNativeError("SourceMod GameEvent type is unavailable");

    void *object = nullptr;
    HandleError error = g_Handles->ReadHandle(
        static_cast<Handle_t>(params[1]), type, nullptr, &object);
    if (error != HandleError_None || !object)
        return context->ThrowNativeError("Invalid GameEvent handle %x (error %d)",
                                         params[1], error);

    void *event = nullptr;
    std::memcpy(&event, object, sizeof(event));
    if (!event)
        return context->ThrowNativeError("GameEvent has no engine event");
    return static_cast<cell_t>(reinterpret_cast<intptr_t>(event));
}

const sp_nativeinfo_t g_Natives[] = {
    {"BB_GetGameEventAddress", GetGameEventAddress},
    {nullptr, nullptr}
};

class EventPtr final : public IExtensionInterface
{
public:
    bool OnExtensionLoad(IExtension *me, IShareSys *sys,
                         char *error, size_t maxlength, bool) override
    {
        SMInterface *interface = nullptr;
        if (!sys->RequestInterface(SMINTERFACE_HANDLESYSTEM_NAME,
                SMINTERFACE_HANDLESYSTEM_VERSION, me, &interface)) {
            std::snprintf(error, maxlength, "SourceMod IHandleSys v5 is required");
            return false;
        }
        g_Handles = static_cast<IHandleSys *>(interface);
        sys->AddNatives(me, g_Natives);
        sys->RegisterLibrary(me, "eventptr");
        return true;
    }

    void OnExtensionUnload() override { g_Handles = nullptr; }
    void OnExtensionsAllLoaded() override {}
    void OnExtensionPauseChange(bool) override {}
    void NotifyInterfaceDrop(SMInterface *interface) override
    {
        if (interface == g_Handles)
            g_Handles = nullptr;
    }
    bool IsMetamodExtension() override { return false; }
    const char *GetExtensionName() override { return "EventPtr"; }
    const char *GetExtensionURL() override { return ""; }
    const char *GetExtensionTag() override { return "EVENTPTR"; }
    const char *GetExtensionAuthor() override { return "BetterBots"; }
    const char *GetExtensionVerString() override { return "0.1.0"; }
    const char *GetExtensionDescription() override
    { return "Validated SourceMod GameEvent addresses"; }
    const char *GetExtensionDateString() override { return __DATE__; }
};

EventPtr g_Extension;
}

extern "C" __attribute__((visibility("default")))
IExtensionInterface *GetSMExtAPI()
{
    return &g_Extension;
}
