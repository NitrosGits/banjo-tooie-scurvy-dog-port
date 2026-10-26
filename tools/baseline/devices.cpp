// Public RT64 method wiring follows RecompFrontend's rt64_render_context.cpp.
// Reference: deps/RecompFrontend/recompui/src/renderer/rt64_render_context.cpp.
// RecompFrontend translation units stay unlinked; HOST selects authored baseline hooks.
#include "devices.hpp"
#if TOOIE_BASELINE_HOST && defined(BASELINE_PLAYER)
#include "guest/minimum-host/first_person_aim_abi.h"
#include "recomp.h"
#endif
#ifdef BASELINE_PLAYER
#include "guest_clock.hpp"
#include "frontend_input_preference.hpp"
#include "sound_trace.hpp"
#include "issue_evidence.hpp"
#endif
#include "input.hpp"
#ifdef BASELINE_TERMINAL_FENCE
#include "runtime_lifecycle.hpp"
#include "ultramodern/error_handling.hpp"
#endif
#if TOOIE_BASELINE_HOST
#include "minimum_host.hpp"
#include "minimum_render.hpp"
#if BASELINE_RENDERER_COMPARISON
#error Minimum host and developer comparison own different Inspectors; select one
#endif
#endif
#if TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER
#include "shadow_witness.hpp"
#endif
#include <fstream>
#if defined(BASELINE_VI_CONTROLLER_CYCLE)
#include "dp-freeze.hpp"
#endif
#include "librecomp/game.hpp"
#ifdef BASELINE_PLAYER
#include "librecomp/mods.hpp"
#include "ultramodern/error_handling.hpp"
#include <unordered_map>
#endif
#include "SDL.h"
#if defined(_WIN32)
#include "SDL_syswm.h"
// Runtime's lean Windows include omits the COM bases required by DXC headers.
#include <objbase.h>
#elif defined(__APPLE__)
#include "SDL_syswm.h"
#endif
#include "hle/rt64_application.h"
#include "hle/rt64_state.h"
#include "hle/rt64_rsp.h"
#include "hle/rt64_rdp.h"
#include "hle/rt64_interpreter.h"
#include "hle/rt64_shared_queue_resources.h"
#ifdef BASELINE_PLAYER
#include "render/rt64_texture_cache.h"
#endif
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <charconv>
#include <cstdlib>
#include <string_view>
#include <cstdio>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <vector>

namespace baseline {
namespace {
SDL_Window* window = nullptr;
// SDL pumps the Cocoa event queue on the main thread only. On macOS main() pumps while the runtime runs on
// another thread, which reads what was pumped; elsewhere the runtime thread polls (and pumps) itself.
int next_event(SDL_Event* event) {
#ifdef __APPLE__
    return SDL_PeepEvents(event, 1, SDL_GETEVENT, SDL_FIRSTEVENT, SDL_LASTEVENT);
#else
    return SDL_PollEvent(event);
#endif
}
#ifdef __APPLE__
SDL_MetalView metal_view = nullptr;  // The layer RT64's Metal backend draws into; destroyed before the window.
#endif
SDL_AudioDeviceID audio = 0;
uint32_t audio_frequency = 0;
std::mutex audio_mutex;
// Default-off, finite observation; only audio_mutex owners touch producer state.
struct AudioSummary {
    uint32_t limit=0, opened=0, epoch=0, device=0, hz=0, chunks=0, peak=0;
    uint64_t frames=0, rails=0, zero_before=0;
    uint32_t obtained_samples=0, obtained_size=0, obtained_format=0, obtained_channels=0, join_max=0, internal_max=0;
    uint64_t first_us=0,last_us=0,first_chunk_frames=0,post_bytes=0,submit_gap_max_us=0,queries=0,zero_queries=0,last_query_us=0,query_gap_max_us=0,headroom_excess=0,block_headroom_excess=0,headroom_max_us=0,block_headroom_max_us=0,joins=0;
    uint64_t queries_at_submit=0, first_interval_query_us=0;
    uint64_t max_gap_queries=0, max_gap_first_query_us=0, max_gap_last_query_us=0;
    uint32_t max_gap_ending_chunk=0;
    int16_t tail[2]{}; char driver[32]{};
    uint64_t locked_after=0, partial_fills=0, silence_min_frames=0, boundary_empty=0, drain_invalid=0;
    uint32_t first_dry_chunk=0, last_dry_chunk=0, partial_step_max=0, boundary_step_max=0;
    bool armed=true, stopped=false, reported=false;
} audio_summary;
uint64_t audio_observation_us() { return uint64_t(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count()); }
std::filesystem::path data_root;
RenderMode selected_render_mode = RenderMode::Original;
std::chrono::steady_clock::time_point quit_at;
bool start_requested = false;
bool quit_requested = false;
#ifdef BASELINE_TERMINAL_FENCE
bool lifecycle_stop_seen = false; // SDL owner; lifecycle is single-use per process.
void report_lifecycle_failure() noexcept {
    try {
        const auto failure = tooie::lifecycle::failure();
        if (!failure) {
            ultramodern::error_handling::message_box("Runtime stopped without a recorded failure.");
        } else {
            try { std::rethrow_exception(failure); }
            catch (const std::exception& error) { ultramodern::error_handling::message_box(error.what()); }
            catch (...) { ultramodern::error_handling::message_box("Unknown runtime failure."); }
        }
    } catch (...) {
        ultramodern::error_handling::message_box("Runtime failure details could not be retrieved.");
    }
}
#endif
#ifdef BASELINE_PLAYER
bool start_refused = false;
struct TexturePack { size_t order; std::filesystem::path path; };
std::mutex texture_pack_mutex;
std::unordered_map<std::string, TexturePack> texture_packs;
std::atomic<bool> texture_packs_pending = false;
void enable_texture_pack(recomp::mods::ModContext& context, const recomp::mods::ModHandle& mod) {
    const TexturePack pack{context.get_mod_order_index(mod.manifest.mod_id), mod.manifest.mod_root_path};
    std::lock_guard lock(texture_pack_mutex);
    texture_packs.insert_or_assign(mod.manifest.mod_id, pack);
    texture_packs_pending.store(true, std::memory_order_release);
}
void disable_texture_pack(recomp::mods::ModContext&, const recomp::mods::ModHandle& mod) {
    std::lock_guard lock(texture_pack_mutex);
    texture_packs.erase(mod.manifest.mod_id);
    texture_packs_pending.store(true, std::memory_order_release);
}
bool texture_only_selection() {
    for (const auto& mod : recomp::mods::get_all_mod_details("bt")) {
        if (!mod.runtime_toggleable && (recomp::mods::is_mod_enabled(mod.mod_id) ||
                recomp::mods::is_mod_auto_enabled(mod.mod_id))) {
            const auto message = "Only texture packs are supported. Disable mod: " + mod.display_name;
            ultramodern::error_handling::message_box(message.c_str());
            return false;
        }
    }
    return true;
}
void apply_texture_packs(RT64::TextureCache& cache) {
    if (!texture_packs_pending.exchange(false, std::memory_order_acq_rel)) return;
    std::vector<TexturePack> packs;
    {
        std::lock_guard lock(texture_pack_mutex);
        for (const auto& entry : texture_packs) packs.push_back(entry.second);
    }
    // Earlier mod entries override later ones; no runtime lock is held here.
    std::sort(packs.begin(), packs.end(), [](const auto& a, const auto& b) { return a.order > b.order; });
    std::vector<RT64::ReplacementDirectory> directories;
    for (const auto& pack : packs) directories.emplace_back(pack.path);
    cache.waitForGPUUploads();
    bool loaded = true;
    if (directories.empty()) cache.clearReplacementDirectories();
    else loaded = cache.loadReplacementDirectories(directories);
    if (!loaded) {
        cache.clearReplacementDirectories();
        std::fputs("baseline texture-pack filesystem load failed; using original textures\n", stderr);
    }
    std::fprintf(stderr, "baseline texture-pack count=%zu filesystem_loaded=%s\n", packs.size(), loaded ? "true" : "false");
}
#endif
std::atomic<bool> quit_published = false;
std::atomic<bool> initial_vi_ready = false;
std::atomic<uint32_t> first_dl_start{0}, first_dl_size{0};
std::atomic<bool> first_dl_armed{false}, first_dl_processed{false};
std::mutex input_mutex;
input::Player input_player;
// Same critical section/publication as Player's physical input.
uint32_t physical_aim_sample = 0, physical_aim_policy = 0;
#if !TOOIE_BASELINE_HOST
SDL_GameController* gamepad = nullptr;
bool gamepad_enabled = false;
#endif
uint64_t input_now() {
    return uint64_t(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count());
}
#if !TOOIE_BASELINE_HOST
void select_gamepad() {
    if (gamepad || !gamepad_enabled) return;
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i) && (gamepad = SDL_GameControllerOpen(i))) {
            std::fprintf(stderr, "baseline gamepad opened instance=%d\n",
                SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(gamepad)));
            break;
        }
    }
}
input::State gamepad_state() {
    input::State out;
    if (!gamepad || !SDL_GameControllerGetAttached(gamepad)) return out;
    const auto button = [](SDL_GameControllerButton b) { return SDL_GameControllerGetButton(gamepad, b) != 0; };
    if (button(SDL_CONTROLLER_BUTTON_A)) out.buttons |= 0x8000;
    if (button(SDL_CONTROLLER_BUTTON_B)) out.buttons |= 0x4000;
    if (button(SDL_CONTROLLER_BUTTON_START)) out.buttons |= 0x1000;
    if (button(SDL_CONTROLLER_BUTTON_LEFTSHOULDER)) out.buttons |= 0x0020;
    if (button(SDL_CONTROLLER_BUTTON_RIGHTSHOULDER)) out.buttons |= 0x0010;
    if (button(SDL_CONTROLLER_BUTTON_DPAD_UP)) out.buttons |= 0x0800;
    if (button(SDL_CONTROLLER_BUTTON_DPAD_DOWN)) out.buttons |= 0x0400;
    if (button(SDL_CONTROLLER_BUTTON_DPAD_LEFT)) out.buttons |= 0x0200;
    if (button(SDL_CONTROLLER_BUTTON_DPAD_RIGHT)) out.buttons |= 0x0100;
    if (SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_TRIGGERLEFT) > 16384) out.buttons |= 0x2000;
    const auto rx = SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_RIGHTX);
    const auto ry = SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_RIGHTY);
    if (rx < -16384) out.buttons |= 0x0002;
    if (rx > 16384) out.buttons |= 0x0001;
    if (ry < -16384) out.buttons |= 0x0008;
    if (ry > 16384) out.buttons |= 0x0004;
    out.x = input::axis(SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_LEFTX));
    out.y = -input::axis(SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_LEFTY));
    return out;
}
// Transient mapped activity aborts a script even if neutral by the end of this pump.
bool controller_activity(const SDL_Event& e) {
    if (!gamepad) return false;
    const auto id = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(gamepad));
    if (e.type == SDL_CONTROLLERBUTTONDOWN && e.cbutton.which == id) {
        const auto b = e.cbutton.button;
        return b == SDL_CONTROLLER_BUTTON_A || b == SDL_CONTROLLER_BUTTON_B || b == SDL_CONTROLLER_BUTTON_START ||
            b == SDL_CONTROLLER_BUTTON_LEFTSHOULDER || b == SDL_CONTROLLER_BUTTON_RIGHTSHOULDER ||
            (b >= SDL_CONTROLLER_BUTTON_DPAD_UP && b <= SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
    }
    if (e.type != SDL_CONTROLLERAXISMOTION || e.caxis.which != id) return false;
    if (e.caxis.axis == SDL_CONTROLLER_AXIS_LEFTX || e.caxis.axis == SDL_CONTROLLER_AXIS_LEFTY)
        return input::axis(e.caxis.value) != 0;
    if (e.caxis.axis == SDL_CONTROLLER_AXIS_RIGHTX || e.caxis.axis == SDL_CONTROLLER_AXIS_RIGHTY)
        return e.caxis.value < -16384 || e.caxis.value > 16384;
    return e.caxis.axis == SDL_CONTROLLER_AXIS_TRIGGERLEFT && e.caxis.value > 16384;
}
#endif
std::atomic<bool> keyboard_observed{false};
#if !TOOIE_BASELINE_HOST
uint32_t pressed_keys = 0;
Uint32 input_window_id = 0;
bool input_focused = false;
enum InputMask : uint32_t {
    ButtonA = 0x8000, ButtonB = 0x4000, ButtonZ = 0x2000, ButtonStart = 0x1000,
    ButtonL = 0x0020, ButtonR = 0x0010,
    CUp = 0x0008, CDown = 0x0004, CLeft = 0x0002, CRight = 0x0001,
    DUp = 0x0800, DDown = 0x0400, DLeft = 0x0200, DRight = 0x0100,
    StickUp = 1u << 16, StickDown = 1u << 17, StickLeft = 1u << 18, StickRight = 1u << 19
};
uint32_t key_mask(SDL_Scancode key) {
    switch (key) {
    case SDL_SCANCODE_W: return StickUp;
    case SDL_SCANCODE_S: return StickDown;
    case SDL_SCANCODE_A: return StickLeft;
    case SDL_SCANCODE_D: return StickRight;
    case SDL_SCANCODE_J: return ButtonA;
    case SDL_SCANCODE_K: return ButtonB;
    case SDL_SCANCODE_SPACE: return ButtonZ;
    case SDL_SCANCODE_RETURN: return ButtonStart;
    case SDL_SCANCODE_Q: return ButtonL;
    case SDL_SCANCODE_E: return ButtonR;
    case SDL_SCANCODE_UP: return CUp;
    case SDL_SCANCODE_DOWN: return CDown;
    case SDL_SCANCODE_LEFT: return CLeft;
    case SDL_SCANCODE_RIGHT: return CRight;
    case SDL_SCANCODE_T: return DUp;
    case SDL_SCANCODE_G: return DDown;
    case SDL_SCANCODE_F: return DLeft;
    case SDL_SCANCODE_H: return DRight;
    default: return 0;
    }
}
#endif

// Callback failures terminate the disposable process, never report successful service.
[[noreturn]] void fail(const char* message, bool sdl = true) {
    if (sdl) std::fprintf(stderr, "baseline device failure: %s (SDL: %s)\n", message, SDL_GetError());
    else std::fprintf(stderr, "baseline device failure: %s\n", message);
    std::fflush(stderr);
    std::quick_exit(EXIT_FAILURE);
}

// Runtime owns SP/DP delivery; RT64's core callback must not duplicate it.
void check_interrupts() {}

ultramodern::renderer::SetupResult map_result(RT64::Application::SetupResult result) {
    using Out = ultramodern::renderer::SetupResult;
    using In = RT64::Application::SetupResult;
    switch (result) {
    case In::Success: return Out::Success;
    case In::DynamicLibrariesNotFound: return Out::DynamicLibrariesNotFound;
    case In::InvalidGraphicsAPI: return Out::InvalidGraphicsAPI;
    case In::GraphicsAPINotFound: return Out::GraphicsAPINotFound;
    case In::GraphicsDeviceNotFound: return Out::GraphicsDeviceNotFound;
    }
    fail("Unknown RT64 setup result");
}

// This owns only the public renderer contract and its register storage.
class StockRenderer final : public ultramodern::renderer::RendererContext {
    bool first_screen_seen = false;
    const RenderMode mode = selected_render_mode;
    bool display_rate_seen = false;
    uint32_t observed_display_rate = 0;
    unsigned task_ordinal = 0;
    std::array<uint8_t, 0x40> header{};
    std::array<uint8_t, 0x1000> dmem{}, imem{};
    std::array<uint32_t, 9> registers{};
    std::unique_ptr<RT64::Application> app;
#ifdef BASELINE_PLAYER
    uint32_t diagnostic_task_sequence = 0;
    void record_graphics(uint32_t kind, const OSTask* task = nullptr) {
        issue_evidence::GraphicsRecord record{};
        record.kind = kind;
        if (task) {
            record.task_sequence = diagnostic_task_sequence;
            record.data_ptr = task->t.data_ptr; record.data_size = task->t.data_size;
        }
        record.swap_chain_rate = get_display_framerate(); // Release renderer lock before recorder lock.
        record.resolution = int(app->userConfig.resolutionMultiplier);
        record.output_rate = int(app->userConfig.refreshRate);
        record.manual_hz = app->userConfig.refreshRateTarget;
        record.texture_filter = !app->userConfig.threePointFiltering;
        record.output_filter = int(app->userConfig.filtering);
        issue_evidence::record(record);
    }
#endif
public:
    StockRenderer(uint8_t* rdram, ultramodern::renderer::WindowHandle handle, bool developer) {
        using namespace ultramodern::renderer;
        setup_result = SetupResult::DynamicLibrariesNotFound;
        chosen_api = GraphicsApi::Auto;
        if (developer != bool(BASELINE_RENDERER_COMPARISON)) fail("Developer mode differs from selected baseline admission");
        RT64::Application::Core core{};
#if defined(_WIN32)
        core.window = handle.window;
#elif defined(__APPLE__)
        core.window.window = handle.window;
        core.window.view = handle.view;
#elif defined(__linux__)
        core.window = handle;
#endif
        core.HEADER = header.data(); core.RDRAM = rdram;
        core.DMEM = dmem.data(); core.IMEM = imem.data();
        core.checkInterrupts = check_interrupts;
        core.MI_INTR_REG = &registers[0];
        core.DPC_START_REG = &registers[1]; core.DPC_END_REG = &registers[2];
        core.DPC_CURRENT_REG = &registers[3]; core.DPC_STATUS_REG = &registers[4];
        core.DPC_CLOCK_REG = &registers[5]; core.DPC_BUFBUSY_REG = &registers[6];
        core.DPC_PIPEBUSY_REG = &registers[7]; core.DPC_TMEM_REG = &registers[8];
        auto* vi = get_vi_regs();
        core.VI_STATUS_REG = &vi->VI_STATUS_REG; core.VI_ORIGIN_REG = &vi->VI_ORIGIN_REG;
        core.VI_WIDTH_REG = &vi->VI_WIDTH_REG; core.VI_INTR_REG = &vi->VI_INTR_REG;
        core.VI_V_CURRENT_LINE_REG = &vi->VI_V_CURRENT_LINE_REG;
        core.VI_TIMING_REG = &vi->VI_TIMING_REG; core.VI_V_SYNC_REG = &vi->VI_V_SYNC_REG;
        core.VI_H_SYNC_REG = &vi->VI_H_SYNC_REG; core.VI_LEAP_REG = &vi->VI_LEAP_REG;
        core.VI_H_START_REG = &vi->VI_H_START_REG; core.VI_V_START_REG = &vi->VI_V_START_REG;
        core.VI_V_BURST_REG = &vi->VI_V_BURST_REG;
        core.VI_X_SCALE_REG = &vi->VI_X_SCALE_REG; core.VI_Y_SCALE_REG = &vi->VI_Y_SCALE_REG;
        RT64::ApplicationConfiguration config;
        config.useConfigurationFile = false;
        config.detectDataPath = false;
        config.dataPath = data_root / "rt64";
        app = std::make_unique<RT64::Application>(core, config);
        auto& user = app->userConfig;
        user.developerMode = bool(BASELINE_RENDERER_COMPARISON);
        user.resolution = RT64::UserConfiguration::Resolution::Manual;
        user.resolutionMultiplier = 1;
        user.downsampleMultiplier = 1;
        user.aspectRatio = RT64::UserConfiguration::AspectRatio::Original;
        user.extAspectRatio = RT64::UserConfiguration::AspectRatio::Original;
        user.antialiasing = RT64::UserConfiguration::Antialiasing::None;
        user.refreshRate = BASELINE_RENDERER_COMPARISON ? RT64::UserConfiguration::RefreshRate::Manual
            : (mode == RenderMode::Display ? RT64::UserConfiguration::RefreshRate::Display
                : RT64::UserConfiguration::RefreshRate::Original);
        user.refreshRateTarget = 60;
        user.internalColorFormat = RT64::UserConfiguration::InternalColorFormat::Standard;
        user.graphicsAPI = get_graphics_config().api_option == GraphicsApi::D3D12
            ? RT64::UserConfiguration::GraphicsAPI::D3D12 : RT64::UserConfiguration::GraphicsAPI::Vulkan;
        app->enhancementConfig.presentation.mode = !BASELINE_RENDERER_COMPARISON && mode == RenderMode::Display
            ? RT64::EnhancementConfiguration::Presentation::Mode::PresentEarly
            : RT64::EnhancementConfiguration::Presentation::Mode::Console;
#if TOOIE_BASELINE_HOST
        host::render::configure_startup(*app);
#endif
        uint32_t thread_id = 0;
#if defined(_WIN32)
        thread_id = handle.thread_id;
#endif
        const auto original = app->setup(thread_id);
        setup_result = map_result(original);
        if (setup_result == SetupResult::Success && (!app->device || !app->swapChain || !app->interpreter ||
            !app->state || !app->workloadQueue || !app->presentQueue || !app->sharedQueueResources
#if TOOIE_BASELINE_HOST
            || !app->presentGraphicsWorker
#endif
            )) {
            std::fprintf(stderr, "baseline RT64 setup returned Success with missing owners; rejecting admission\n");
            setup_result = SetupResult::DynamicLibrariesNotFound;
        }
        if (setup_result == SetupResult::Success) {
            switch (app->chosenGraphicsAPI) {
            case RT64::UserConfiguration::GraphicsAPI::D3D12: chosen_api = GraphicsApi::D3D12; break;
            case RT64::UserConfiguration::GraphicsAPI::Vulkan: chosen_api = GraphicsApi::Vulkan; break;
            default: fail("RT64 chose undeclared graphics API");
            }
            // An explicit D3D12 request (QA or engineering --api d3d12; the default never asks for
            // it) must run D3D12. RT64's Windows creation fallback and its vendor compatibility
            // override can both create Vulkan instead; that is refused, never reported as D3D12.
            if (get_graphics_config().api_option == GraphicsApi::D3D12 && chosen_api != GraphicsApi::D3D12)
                fail("Requested D3D12 but RT64 created another graphics API; no fallback accepted", false);
            app->setFullScreen(false);
#if TOOIE_BASELINE_HOST
            host::render::publish_renderer(*app,window);
#endif
#if BASELINE_RENDERER_COMPARISON
            app->processDeveloperShortcut(RT64::Application::DeveloperShortcut::Inspector);
#endif
        }
        const auto runtime_config = get_graphics_config();
        std::fprintf(stderr, "baseline renderer-settings mode=%s refresh=%d presentation=%d comparison=%d setup=%d rt64_setup=%d rr_option=%d rr_manual_value=%d vi_original_rate=unobserved\n",
            mode == RenderMode::Display ? "display" : "original", int(user.refreshRate),
            int(app->enhancementConfig.presentation.mode), int(bool(BASELINE_RENDERER_COMPARISON)),
            int(setup_result), int(original), int(runtime_config.rr_option), runtime_config.rr_manual_value);
        std::fprintf(stderr, "baseline renderer setup=%d original=%d chosen_api=%d\n",
            int(setup_result), int(original), int(chosen_api));
    }
    ~StockRenderer() override { shutdown(); }
    bool valid() override { return app && setup_result == ultramodern::renderer::SetupResult::Success; }
    bool update_config(const ultramodern::renderer::GraphicsConfig& old_config,
        const ultramodern::renderer::GraphicsConfig& new_config) override {
#if BASELINE_PLAYER
        if (!valid()) fail("Config update on invalid renderer");
        try {
            if (host::render::update_rate(app->userConfig, *app->sharedQueueResources, old_config, new_config)) {
                std::fprintf(stderr, "baseline output-rate config-applied rr_option=%d rr_manual_value=%d owner=gfx presented=unobserved\n",
                    int(new_config.rr_option), new_config.rr_manual_value);
                record_graphics(issue_evidence::GraphicsRecord::ConfigApplied);
                return true;
            }
        } catch (const std::exception& error) { fail(error.what()); }
#else
        if (old_config != new_config) fail("Graphics config changed outside declared condition");
#endif
        return false;
    }
    void enable_instant_present() override {
        if (!valid()) fail("Instant present on invalid renderer");
        // This ultramodern API is outside the immutable RT64 mode selection.
        fail("Ultramodern instant-present API invoked outside declared static selection");
    }
    void send_dl(const OSTask* task) override {
        if (!valid() || !task) fail("Display list on invalid renderer");
#ifdef BASELINE_PLAYER
        apply_texture_packs(*app->textureCache);
        ++diagnostic_task_sequence;
        record_graphics(issue_evidence::GraphicsRecord::ParseBegin, task);
#endif
        const bool armed = first_dl_armed.load(std::memory_order_acquire);
        if (armed && task_ordinal < 3) ++task_ordinal;
        const bool observe = armed && task_ordinal <= 2;
        const bool first = observe && task_ordinal == 1;
        const uint32_t start = task->t.data_ptr & 0x3FFFFFF;
        if (first) {
            std::fprintf(stderr, "baseline graphics-task-enter start=%08x expected_start=%08x data_ptr=%08x size=%u expected_size=%u size_match=%u type=%u ucode=%08x ucode_data=%08x\n",
                start, first_dl_start.load(), task->t.data_ptr, task->t.data_size, first_dl_size.load(), unsigned(task->t.data_size == first_dl_size.load()),
                task->t.type, task->t.ucode, task->t.ucode_data);
            std::fflush(stderr);
            if (start != first_dl_start.load() || task->t.type != M_GFXTASK) fail("First graphics task identity mismatch");
        } else if (observe && task_ordinal == 2) {
            std::fprintf(stderr, "baseline graphics-task2-enter ordinal=%u start=%08x size=%u type=%u\n",
                task_ordinal, start, task->t.data_size, task->t.type);
            std::fflush(stderr);
        }
        app->state->rsp->reset();
        app->interpreter->loadUCodeGBI(task->t.ucode & 0x3FFFFFF, task->t.ucode_data & 0x3FFFFFF, true);
        app->processDisplayLists(app->core.RDRAM, task->t.data_ptr & 0x3FFFFFF, 0, true);
#ifdef BASELINE_PLAYER
        record_graphics(issue_evidence::GraphicsRecord::ParseEnd, task);
#endif
        if (first) {
            std::fprintf(stderr, "baseline graphics-task-return start=%08x size=%u expected_size=%u size_match=%u parser_returned=1\n",
                start, task->t.data_size, first_dl_size.load(), unsigned(task->t.data_size == first_dl_size.load()));
            std::fflush(stderr);
            first_dl_processed.store(true, std::memory_order_release);
        } else if (observe && task_ordinal == 2) {
            std::fprintf(stderr, "baseline graphics-task2-return ordinal=%u start=%08x size=%u type=%u parser_returned=1\n",
                task_ordinal, start, task->t.data_size, task->t.type);
            std::fflush(stderr);
        }
    }
    void send_dummy_workload(uint32_t fb) override {
        if (!valid()) fail("Dummy workload on invalid renderer");
#ifdef BASELINE_PLAYER
        record_graphics(issue_evidence::GraphicsRecord::DummyBegin);
#endif
        app->state->listProcessBegin();
        app->state->rdp->setColorImage(G_IM_FMT_RGBA, G_IM_SIZ_16b, 320, fb);
        app->state->rdp->setOtherMode(0x382C30, 0);
        app->state->rdp->fillRect(0, 0, 320 << 2, 240 << 2);
        app->state->fullSync();
        app->state->listProcessEnd();
#ifdef BASELINE_PLAYER
        record_graphics(issue_evidence::GraphicsRecord::DummyEnd);
#endif
    }
    void update_screen() override {
        if (!valid()) fail("Screen update on invalid renderer");
#if BASELINE_PLAYER
        record_graphics(issue_evidence::GraphicsRecord::ScreenBegin);
        const int resolution = host::requested_resolution();
        if (host::render::update_resolution(app->userConfig, *app->sharedQueueResources, resolution)) {
            std::fprintf(stderr, "baseline resolution config-applied scale=%d owner=gfx presented=unobserved\n", resolution);
        }
        const int texture_filter = host::requested_texture_filter(), output_filter = host::requested_output_filter();
        if (host::render::update_filters(app->userConfig, *app->sharedQueueResources, texture_filter, output_filter))
            std::fprintf(stderr, "baseline filtering config-applied texture=%d output=%d owner=gfx presented=unobserved\n",
                texture_filter, output_filter);
        const auto requested = host::requested_output_rate();
        auto config = ultramodern::renderer::get_graphics_config(); // Graphics owner only after startup.
        host::render::preference_rate(config, requested.option, requested.manual_hz);
        if (config != ultramodern::renderer::get_graphics_config()) ultramodern::renderer::set_graphics_config(config);
#endif
        app->updateScreen();
#ifdef BASELINE_PLAYER
        record_graphics(issue_evidence::GraphicsRecord::ScreenEnd);
#endif
        const uint32_t rate = get_display_framerate();
        if ((!display_rate_seen && rate != 0) || (display_rate_seen && rate != observed_display_rate)) {
            display_rate_seen = true; observed_display_rate = rate;
            std::fprintf(stderr, "baseline renderer-display-rate mode=%s refresh=%d presentation=%d swap_chain_rate=%u conservative_eligible=%d vi_original_rate=unobserved\n",
                mode == RenderMode::Display ? "display" : "original", int(app->userConfig.refreshRate),
                int(app->enhancementConfig.presentation.mode), rate, int(mode == RenderMode::Display && rate > 60));
        }
        if (first_dl_processed.load(std::memory_order_acquire) && !first_screen_seen) {
            first_screen_seen = true;
            const auto vi = *ultramodern::renderer::get_vi_regs();
            std::fprintf(stderr, "baseline graphics-screen status=%08x origin=%08x width=%u h_start=%08x v_start=%08x screen_returned=1\n",
                vi.VI_STATUS_REG, vi.VI_ORIGIN_REG, vi.VI_WIDTH_REG, vi.VI_H_START_REG, vi.VI_V_START_REG);
            std::fflush(stderr);
        }
    }
    void shutdown() override {
        if (app) { app->end(); app.reset(); }
    }
    uint32_t get_display_framerate() const override {
        if (!app || !app->sharedQueueResources) return 0;
        std::lock_guard guard(app->sharedQueueResources->configurationMutex);
        return app->sharedQueueResources->swapChainRate;
    }
    float get_resolution_scale() const override { return 1.0f; }
};

// Maintain a real S16 stereo queue; no gain or pacing policy. The player reports
// one VI fewer queued frames, as BK does; engineering builds report the raw count.
void set_frequency(uint32_t frequency) {
    if (frequency < 1000 || frequency > 192000) {
        std::fprintf(stderr, "baseline audio context: requested_rate=%u\n", static_cast<unsigned>(frequency));
        fail("Unsupported audio frequency", false);
    }
    std::lock_guard guard(audio_mutex);
    if (audio && audio_frequency == frequency) return;
    if (audio) {
        const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
        while (SDL_GetQueuedAudioSize(audio)) {
            if (std::chrono::steady_clock::now() >= deadline) {
                std::fprintf(stderr, "baseline audio context: old_rate=%u requested_rate=%u device=%u (SDL: %s)\n",
                    static_cast<unsigned>(audio_frequency), static_cast<unsigned>(frequency), static_cast<unsigned>(audio), SDL_GetError());
                std::fprintf(stderr, "baseline audio context: queued_bytes=%u\n", static_cast<unsigned>(SDL_GetQueuedAudioSize(audio)));
                fail("Old-rate audio did not drain", false);
            }
            SDL_Delay(1);
        }
        SDL_CloseAudioDevice(audio); audio = 0;
    }
    SDL_AudioSpec desired{}, obtained{};
    desired.freq = int(frequency); desired.format = AUDIO_S16SYS;
    desired.channels = 2; desired.samples = 512;
    audio = SDL_OpenAudioDevice(nullptr, 0, &desired, &obtained, 0);
    if (!audio || obtained.freq != int(frequency) || obtained.channels != 2 || obtained.format != AUDIO_S16SYS) {
        std::fprintf(stderr, "baseline audio context: requested_freq=%d requested_format=%u requested_channels=%u obtained_freq=%d obtained_format=%u obtained_channels=%u device=%u\n",
            desired.freq, static_cast<unsigned>(desired.format), static_cast<unsigned>(desired.channels),
            obtained.freq, static_cast<unsigned>(obtained.format), static_cast<unsigned>(obtained.channels), static_cast<unsigned>(audio));
        fail("SDL audio format admission failed");
    }
    audio_frequency = frequency;
#ifdef BASELINE_PLAYER
    sound_trace::record(sound_trace::Kind::AudioFrequency, frequency);
#endif
    if (audio_summary.limit) {
        auto& s=audio_summary; ++s.opened;
        s.queries_at_submit=s.queries;
        s.first_interval_query_us=0;
        if (!s.chunks) { s.epoch=s.opened; s.device=uint32_t(audio); s.hz=frequency; s.obtained_samples=obtained.samples; s.obtained_size=obtained.size; s.obtained_format=obtained.format; s.obtained_channels=obtained.channels;
            std::snprintf(s.driver,sizeof(s.driver),"%s",SDL_GetCurrentAudioDriver() ? SDL_GetCurrentAudioDriver() : "unknown"); }
        else if (s.chunks<s.limit) { s.stopped=true; s.tail[0]=s.tail[1]=0; }
    }
    SDL_PauseAudioDevice(audio, 0);
}
#ifdef BASELINE_PLAYER
// F6, guarded by audio_mutex: accelerated guest audio is discarded. The next
// submit/query clears after any applied edge, including a complete hold/release
// between audio calls; rate and revision are sampled under the same clock lock.
uint32_t audio_clock_revision = 0;
bool accelerated_audio_locked() {
    const auto clock = tooie::guest_clock::applied();
    if (clock.revision != audio_clock_revision) {
        audio_clock_revision = clock.revision;
        if (audio) SDL_ClearQueuedAudio(audio);
        sound_trace::record(sound_trace::Kind::AudioClock, clock.rate, clock.revision);
        auto& s = audio_summary;
        if (s.limit && s.chunks < s.limit) { s.stopped = true; s.tail[0] = s.tail[1] = 0; }
    }
    return clock.rate > 1U;
}
#endif
void queue_samples(int16_t* samples, size_t count) {
    if ((count & 1) || count > std::numeric_limits<Uint32>::max() / sizeof(int16_t) || (count && !samples))
        fail("Invalid audio samples");
    if (!count)
        return;
    std::lock_guard guard(audio_mutex);
    if (!audio)
        fail("Audio submitted before frequency admission");
#ifdef BASELINE_PLAYER
    if (accelerated_audio_locked()) {
        sound_trace::record(sound_trace::Kind::AudioDrop, count);
        return;
    }
#endif
    static std::vector<int16_t> corrected; // Reused only under audio_mutex; SDL_QueueAudio copies.
    corrected.resize(count);
    for (size_t i = 0; i < count; i += 2) {
        corrected[i] = samples[i + 1];
        corrected[i + 1] = samples[i];
    }
    auto& s = audio_summary;
    const bool observe = count != 0 && s.limit && s.armed && s.chunks < s.limit && !s.stopped &&
        !quit_published.load(std::memory_order_acquire);
    if (observe)
        SDL_LockAudioDevice(audio);
    const uint64_t pre = observe ? SDL_GetQueuedAudioSize(audio) : 0;
    const int queued = SDL_QueueAudio(audio, corrected.data(), Uint32(count * sizeof(int16_t)));
    if (observe)
        SDL_UnlockAudioDevice(audio);
    if (queued)
        fail("Audio queue failed");
#ifdef BASELINE_PLAYER
    // Fingerprint only; never retain PCM. Equal hashes are clues, not proof of replay.
    uint64_t digest = 14695981039346656037ULL;
    const auto* pcm_bytes = reinterpret_cast<const unsigned char*>(corrected.data());
    for (size_t i = 0; i < corrected.size() * sizeof(int16_t); ++i) {
        digest ^= pcm_bytes[i];
        digest *= 1099511628211ULL;
    }
    sound_trace::record(sound_trace::Kind::AudioChunk, count, digest, SDL_GetQueuedAudioSize(audio));
#endif
    const bool empty = observe && s.chunks && pre == 0;
    if (observe && !quit_published.load(std::memory_order_acquire)) {
        // Only first-to-last locked submit intervals; no shutdown-tail inference.
        const uint64_t request = s.obtained_size,
            after = pre + count * sizeof(int16_t);
        if (!request || request % 4 || after > UINT32_MAX)
            ++s.drain_invalid;
        if (s.chunks) {
            if (!request || request % 4 || pre > s.locked_after || s.locked_after > UINT32_MAX)
                ++s.drain_invalid;
            else if (pre) {
                if ((s.locked_after - pre) % request)
                    ++s.drain_invalid;
            }
            else {
                const uint64_t remainder = s.locked_after % request;
                const uint32_t step = uint32_t(std::max({
                    std::abs(int(s.tail[0])), std::abs(int(s.tail[1])),
                    std::abs(int(corrected[0])), std::abs(int(corrected[1]))}));
                if (remainder) {
                    ++s.partial_fills;
                    s.silence_min_frames += (request - remainder) / 4;
                    s.partial_step_max = std::max(s.partial_step_max, step);
                }
                else {
                    ++s.boundary_empty;
                    s.boundary_step_max = std::max(s.boundary_step_max, step);
                }
                if (!s.first_dry_chunk)
                    s.first_dry_chunk = s.chunks + 1;
                s.last_dry_chunk = s.chunks + 1;
            }
        }
        s.locked_after = after;
        const uint64_t now = audio_observation_us(),
            post_bytes = SDL_GetQueuedAudioSize(audio);
        if (s.chunks) {
            const uint64_t gap = now - s.last_us,
                queued_us = s.post_bytes * 1000000ull / (4ull * s.hz),
                block_us = uint64_t(s.obtained_samples) * 1000000ull / s.hz;
            if (gap > s.submit_gap_max_us) {
                s.submit_gap_max_us = gap;
                s.max_gap_ending_chunk = s.chunks + 1;
                s.max_gap_queries = s.queries - s.queries_at_submit;
                s.max_gap_first_query_us = s.max_gap_queries ? s.first_interval_query_us - s.last_us : 0;
                s.max_gap_last_query_us = s.max_gap_queries ? now - s.last_query_us : 0;
            }
            if (gap > queued_us) {
                ++s.headroom_excess;
                s.headroom_max_us = std::max(s.headroom_max_us, gap - queued_us);
            }
            if (gap > queued_us + block_us) {
                ++s.block_headroom_excess;
                s.block_headroom_max_us = std::max(s.block_headroom_max_us, gap - queued_us - block_us);
            }
            for (size_t channel = 0; channel < 2; ++channel) {
                const int32_t d = int32_t(corrected[channel]) - s.tail[channel];
                s.join_max = std::max(s.join_max, uint32_t(d < 0 ? -d : d));
            }
            ++s.joins;
        }
        else {
            s.first_us = now;
            s.first_chunk_frames = count / 2;
        }
        for (size_t i = 2; i < count; ++i) {
            const int32_t d = int32_t(corrected[i]) - corrected[i - 2];
            s.internal_max = std::max(s.internal_max, uint32_t(d < 0 ? -d : d));
        }
        s.last_us = now;
        s.post_bytes = post_bytes;
        s.queries_at_submit = s.queries;
        s.first_interval_query_us = 0;
        s.tail[0] = corrected[count - 2];
        s.tail[1] = corrected[count - 1];
        for (int16_t sample : corrected) {
            const uint32_t magnitude = sample < 0 ? uint32_t(-int32_t(sample)) : uint32_t(sample);
            if (magnitude > s.peak)
                s.peak = magnitude;
            s.rails += sample == INT16_MIN || sample == INT16_MAX;
        }
        s.zero_before += empty;
        s.frames += count / 2;
        ++s.chunks;
        if (s.chunks == s.limit)
            s.tail[0] = s.tail[1] = 0;
    }
}
size_t frames_remaining() {
    std::lock_guard guard(audio_mutex);
#ifdef BASELINE_PLAYER
    if (audio && accelerated_audio_locked())
        return 0; // Discarded; no normal query evidence.
#endif
    const size_t frames = audio ? SDL_GetQueuedAudioSize(audio) / (2 * sizeof(int16_t)) : 0;
    auto& s = audio_summary;
    if (s.limit && s.chunks && s.chunks < s.limit && !s.stopped) {
        const uint64_t now = audio_observation_us();
        if (s.queries == s.queries_at_submit)
            s.first_interval_query_us = now;
        ++s.queries;
        s.zero_queries += frames == 0;
        if (s.last_query_us)
            s.query_gap_max_us = std::max(s.query_gap_max_us, now - s.last_query_us);
        s.last_query_us = now;
    }
#ifdef BASELINE_PLAYER
    const size_t reserve = audio_frequency / 60; // audio_mutex is held; subtract saturating.
    return frames > reserve ? frames - reserve : 0;
#else
    return frames;
#endif
}
void poll_input() {}
void print_input_events(const input::Events& events) {
    for (size_t i = 0; i < events.count; ++i) {
        const auto& e = events.records[i];
        if (e.kind == input::Receipt::Start)
            std::fprintf(stderr, "baseline input-script start=first-port0-read\n");
        else if (e.kind == input::Receipt::StepEntry) {
            std::fprintf(stderr, "baseline input-script step=%zu kind=%s name=%s ms=%llu buttons=%04x x=%.0f y=%.0f\n",
                e.index, e.step->kind.c_str(), e.step->name.c_str(), (unsigned long long)e.step->ms,
                unsigned(e.step->state.buttons), e.step->state.x, e.step->state.y);
        }
        else if (e.kind == input::Receipt::Delivered) {
            std::fprintf(stderr, "baseline input-script delivered name=%s reads=%llu elapsed_ms=%llu\n",
                e.step->name.c_str(), (unsigned long long)e.reads, (unsigned long long)e.elapsed);
            if (audio_summary.limit && e.step->name == "forward_once" && e.reads) {
                std::lock_guard guard(audio_mutex); audio_summary.armed=true;
            }
#if TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER
            if (shadow_witness::forward_mode() && e.step->name == "forward_once" && e.reads) {
                shadow_witness::forward_ready.store(true,std::memory_order_release);
                std::fprintf(stderr,"baseline shadow-witness event=ready step=forward_once phase=delivered reads=%llu\n",(unsigned long long)e.reads);
            }
#endif
        }
        else
            std::fprintf(stderr, "baseline input-script %s step=%zu reads=%llu elapsed_ms=%llu neutral_latch=1\n",
                e.reason, e.index, (unsigned long long)e.reads, (unsigned long long)e.elapsed);
    }
    if (events.count) std::fflush(stderr);
}
bool keyboard_input(int port, uint16_t* buttons, float* x, float* y) {
    if (port != 0) return false;
    *buttons = 0; *x = 0; *y = 0;
    if (quit_published.load(std::memory_order_acquire)) return true;
    input::Events events;
    input::State state;
    bool scripted;
    const auto now = input_now();
    {
        std::lock_guard guard(input_mutex);
        scripted = input_player.owns_port();
        state = input_player.read(now, quit_published.load(std::memory_order_acquire), &events);
    }
    print_input_events(events);
    *buttons = state.buttons; *x = state.x; *y = state.y;
    if (!scripted && state.nonneutral() && !keyboard_observed.exchange(true, std::memory_order_relaxed)) {
        std::fprintf(stderr, "baseline keyboard-input port=0 buttons=%04x x=%.3f y=%.3f first_nonneutral=1 source=physical\n",
            unsigned(*buttons), *x, *y);
        std::fflush(stderr);
    }
    return true;
}
#ifdef BASELINE_PLAYER
void controller_rumble(int port, bool enabled) {
    std::lock_guard guard(input_mutex);
    tooie::input::set_rumble(port, enabled && !quit_published.load(std::memory_order_acquire) &&
        input_player.delivers_physical());
}
#endif
ultramodern::input::connected_device_info_t keyboard_device(int port) {
#ifdef BASELINE_PLAYER
    if (port == 0) return {ultramodern::input::Device::Controller, ultramodern::input::Pak::RumblePak};
#endif
    return {port == 0 ? ultramodern::input::Device::Controller : ultramodern::input::Device::None, ultramodern::input::Pak::None};
}
std::unique_ptr<ultramodern::renderer::RendererContext> create_renderer(uint8_t* rdram,
    ultramodern::renderer::WindowHandle handle, bool developer) {
    return std::make_unique<StockRenderer>(rdram, handle, developer);
}
}

void load_input_script(const std::filesystem::path& path) {
    if (path.empty()) return;
    if (std::filesystem::file_size(path) > 16384) throw std::runtime_error("Input script exceeds 16KiB");
    std::ifstream file(path);
    auto plan = input::parse(file);
#ifdef BASELINE_PLAYER
    // Player QA paths may be Unicode, where the narrow conversion throws; log UTF-8.
    const auto shown = path.u8string();
    std::fprintf(stderr, "baseline input-script load path=%.*s steps=%zu checkpoint=terminal run_bound=explicit-seconds\n",
        int(shown.size()), reinterpret_cast<const char*>(shown.data()), plan.steps.size());
#else
    std::fprintf(stderr, "baseline input-script load path=%s steps=%zu checkpoint=terminal run_bound=explicit-seconds\n",
        path.string().c_str(), plan.steps.size());
#endif
    std::lock_guard guard(input_mutex);
    input_player = input::Player(std::move(plan));
}

void expect_first_graphics(uint32_t start, uint32_t size) {
    if (first_dl_armed.load(std::memory_order_acquire)) fail("First graphics expectation republished");
    first_dl_start.store(start, std::memory_order_relaxed);
    first_dl_size.store(size, std::memory_order_relaxed);
    first_dl_armed.store(true, std::memory_order_release);
}
bool first_graphics_processed() { return first_dl_processed.load(std::memory_order_acquire); }
bool quit_was_requested() { return quit_published.load(std::memory_order_acquire); }
#ifdef BASELINE_PLAYER
void register_texture_packs() {
    const auto content = recomp::mods::register_mod_content_type({
        .content_filename = "rt64.json", .allow_runtime_toggle = true,
        .on_enabled = enable_texture_pack, .on_disabled = disable_texture_pack, .on_reordered = nullptr
    });
    if (!recomp::mods::register_mod_container_type("rtz", {content}, false))
        throw std::runtime_error("Texture pack registration failed");
}
#endif

ultramodern::renderer::WindowHandle open_devices(const std::filesystem::path& root,
    ultramodern::renderer::GraphicsApi api, unsigned seconds, RenderMode render_mode) {
    selected_render_mode = render_mode;
    data_root = root;
    audio_summary={};
    if (const char* value=std::getenv("TOOIE_BASELINE_AUDIO_SUMMARY_CHUNKS")) {
        const std::string_view text(value);
        const auto parsed=std::from_chars(text.data(),text.data()+text.size(),audio_summary.limit);
        if (parsed.ec!=std::errc{} || parsed.ptr!=text.data()+text.size() || !audio_summary.limit || audio_summary.limit>4096)
            throw std::runtime_error("Audio summary chunks must be an integer from 1 through 4096");
    }
    if (const char* step=std::getenv("TOOIE_BASELINE_AUDIO_SUMMARY_ARM_STEP")) {
        if (std::string_view(step)!="forward_once" || !audio_summary.limit) throw std::runtime_error("Invalid audio summary arm step");
        audio_summary.armed=false;
    }
    if (audio_summary.limit && std::getenv("SDL_DYNAMIC_API")) throw std::runtime_error("Audio summary forbids redirected SDL dynapi");
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) throw std::runtime_error(SDL_GetError());
#ifdef BASELINE_PLAYER
    constexpr const char* window_title = "Banjo-Tooie: Scurvy Dog Port";
#else
    constexpr const char* window_title = "Banjo-Tooie baseline";
#endif
    const char* required_display = std::getenv("TOOIE_REQUIRED_DISPLAY_NAME");
    int display_index = -1;
    SDL_Rect display_bounds{};
    if (required_display) {
        if (std::string_view(required_display) != "\\\\.\\DISPLAY2")
            throw std::runtime_error("Required test display must be exact Windows DISPLAY2");
#if defined(_WIN32)
        struct CanonicalMonitor { HMONITOR handle=nullptr; RECT bounds{}; unsigned matches=0; bool failed=false; } canonical;
        const auto visit = [](HMONITOR monitor, HDC, LPRECT, LPARAM opaque) -> BOOL {
            auto& found = *reinterpret_cast<CanonicalMonitor*>(opaque);
            MONITORINFOEXW info{}; info.cbSize=sizeof(info);
            if (!GetMonitorInfoW(monitor,reinterpret_cast<MONITORINFO*>(&info))) { found.failed=true; return FALSE; }
            if (std::wstring_view(info.szDevice) == L"\\\\.\\DISPLAY2") {
                ++found.matches; found.handle=monitor; found.bounds=info.rcMonitor;
            }
            return TRUE;
        };
        if (!EnumDisplayMonitors(nullptr,nullptr,visit,reinterpret_cast<LPARAM>(&canonical)) ||
            canonical.failed || canonical.matches != 1)
            throw std::runtime_error("Canonical Windows DISPLAY2 unavailable or ambiguous");
        const int count = SDL_GetNumVideoDisplays();
        for (int i = 0; i < count; ++i) {
            SDL_Rect bounds{};
            if (SDL_GetDisplayBounds(i,&bounds) != 0) throw std::runtime_error("SDL display bounds unavailable");
            if (int64_t(bounds.x)==canonical.bounds.left && int64_t(bounds.y)==canonical.bounds.top &&
                int64_t(bounds.w)==int64_t(canonical.bounds.right)-canonical.bounds.left &&
                int64_t(bounds.h)==int64_t(canonical.bounds.bottom)-canonical.bounds.top) {
                if (display_index >= 0) throw std::runtime_error("Canonical DISPLAY2 SDL bounds mapping is ambiguous");
                display_index=i; display_bounds=bounds;
            }
        }
        if (display_index < 0 || display_bounds.w <= 0 || display_bounds.h <= 0)
            throw std::runtime_error("Canonical DISPLAY2 has no exact SDL bounds mapping");
#else
        throw std::runtime_error("Canonical DISPLAY2 guard requires Windows");
#endif
    }
    const int position = required_display ? SDL_WINDOWPOS_CENTERED_DISPLAY(display_index) : SDL_WINDOWPOS_CENTERED;
    const int width = required_display ? std::min(960, display_bounds.w) : 960;
    const int height = required_display ? std::min(540, display_bounds.h) : 540;
    window = SDL_CreateWindow(window_title, position, position,
        width, height, (required_display ? SDL_WINDOW_HIDDEN : SDL_WINDOW_SHOWN)
#if TOOIE_BASELINE_HOST
        | SDL_WINDOW_RESIZABLE
#endif
#if defined(__linux__)
        | SDL_WINDOW_VULKAN
#elif defined(__APPLE__)
        | SDL_WINDOW_METAL
#endif
        );
    if (!window) throw std::runtime_error(SDL_GetError());
    if (required_display) {
#if defined(_WIN32)
        const auto verify_display = [&](const char* phase) {
            const int actual = SDL_GetWindowDisplayIndex(window);
            const char* name = actual >= 0 ? SDL_GetDisplayName(actual) : nullptr;
            SDL_Rect bounds{};
            int x=0,y=0,w=0,h=0;
            SDL_GetWindowPosition(window,&x,&y); SDL_GetWindowSize(window,&w,&h);
            SDL_SysWMinfo wm{}; SDL_VERSION(&wm.version);
            MONITORINFOEXW monitor{}; monitor.cbSize=sizeof(monitor);
            const bool canonical_match = SDL_GetWindowWMInfo(window,&wm) == SDL_TRUE && wm.subsystem == SDL_SYSWM_WINDOWS &&
                GetMonitorInfoW(MonitorFromWindow(wm.info.win.window,MONITOR_DEFAULTTONULL),reinterpret_cast<MONITORINFO*>(&monitor)) &&
                std::wstring_view(monitor.szDevice) == L"\\\\.\\DISPLAY2";
            const bool matched = canonical_match && actual == display_index && name &&
                SDL_GetDisplayBounds(display_index,&bounds) == 0 && bounds.w > 0 && bounds.h > 0 &&
                int64_t(bounds.x)==monitor.rcMonitor.left && int64_t(bounds.y)==monitor.rcMonitor.top &&
                int64_t(bounds.w)==int64_t(monitor.rcMonitor.right)-monitor.rcMonitor.left &&
                int64_t(bounds.h)==int64_t(monitor.rcMonitor.bottom)-monitor.rcMonitor.top &&
                x >= bounds.x && y >= bounds.y && w > 0 && h > 0 &&
                int64_t(x)+w <= int64_t(bounds.x)+bounds.w && int64_t(y)+h <= int64_t(bounds.y)+bounds.h;
            std::fprintf(stderr,"baseline required-display phase=%s required=%s index=%d actual=%d name=%s x=%d y=%d width=%d height=%d bounds_x=%d bounds_y=%d bounds_width=%d bounds_height=%d matched=%u\n",
                phase,required_display,display_index,actual,canonical_match?required_display:"na",x,y,w,h,bounds.x,bounds.y,bounds.w,bounds.h,unsigned(matched));
            std::fprintf(stderr,"baseline required-display-sdl phase=%s index=%d friendly_name=%s canonical_match=%u\n",phase,actual,name?name:"na",unsigned(canonical_match));
            std::fflush(stderr);
            if (!matched) throw std::runtime_error("Required DISPLAY2 window placement failed");
        };
        verify_display("hidden");
        SDL_ShowWindow(window);
        try { verify_display("shown"); }
        catch (...) { SDL_HideWindow(window); throw; }
#else
        throw std::runtime_error("Canonical DISPLAY2 guard requires Windows");
#endif
    }
#if TOOIE_BASELINE_HOST
    bool allow_background_controller = false;
#ifdef BASELINE_PLAYER
    {
        std::lock_guard guard(input_mutex);
        // Tape sessions keep their original focus policy even after completion.
        allow_background_controller = !input_player.has_script();
    }
#endif
    host::initialize(window,root,allow_background_controller);
    host::render::install();
#else
    input_window_id = SDL_GetWindowID(window);
    input_focused = (SDL_GetWindowFlags(window) & SDL_WINDOW_INPUT_FOCUS) != 0;
    pressed_keys = 0;
    gamepad_enabled = SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) == 0;
    if (!gamepad_enabled) std::fprintf(stderr, "baseline gamepad unavailable; keyboard-only SDL=%s\n", SDL_GetError());
    select_gamepad();
#endif
    keyboard_observed.store(false, std::memory_order_relaxed);
#if defined(_WIN32)
    SDL_SysWMinfo wm{}; SDL_VERSION(&wm.version);
    if (!SDL_GetWindowWMInfo(window, &wm)) throw std::runtime_error(SDL_GetError());
#endif
    using namespace ultramodern::renderer;
    GraphicsConfig config{};
    config.developer_mode = bool(BASELINE_RENDERER_COMPARISON); config.res_option = Resolution::Original;
    config.wm_option = WindowMode::Windowed; config.hr_option = HUDRatioMode::Original;
    config.api_option = api; config.ar_option = AspectRatio::Original;
    config.msaa_option = Antialiasing::None;
    config.rr_option = BASELINE_RENDERER_COMPARISON ? RefreshRate::Manual : RefreshRate::Original;
    config.hpfb_option = HighPrecisionFramebuffer::Off; config.rr_manual_value = 60; config.ds_option = 1;
#if BASELINE_PLAYER
    const auto& latched = host::latched_preferences();
    host::render::preference_rate(config, latched.output_rate, latched.manual_hz);
#endif
    set_graphics_config(config);
    quit_published.store(false, std::memory_order_relaxed);
    quit_at = seconds ? std::chrono::steady_clock::now() + std::chrono::seconds(seconds)
        : std::chrono::steady_clock::time_point::max();
#if defined(_WIN32)
    return {wm.info.win.window, GetCurrentThreadId()};
#elif defined(__APPLE__)
    SDL_SysWMinfo wm{}; SDL_VERSION(&wm.version);
    if (!SDL_GetWindowWMInfo(window, &wm)) throw std::runtime_error(SDL_GetError());
    if (!metal_view) metal_view = SDL_Metal_CreateView(window);
    if (!metal_view) throw std::runtime_error(SDL_GetError());
    return {wm.info.cocoa.window, SDL_Metal_GetLayer(metal_view)};
#elif defined(__linux__)
    // The selected runtime and RT64 SDL Vulkan backend share this SDL owner.
    return window;
#else
#error Selected baseline window handle requires a platform implementation
#endif
}
void emit_audio_summary() {
    std::lock_guard guard(audio_mutex);
    if (!audio_summary.limit || audio_summary.reported) return;
    audio_summary.reported=true;
    const auto& s=audio_summary;
    std::fprintf(stderr,"baseline audio-summary epoch=%u device=%u hz=%u enqueues=%u limit=%u complete=%u stopped_on_reopen=%u frames=%llu zero_before=%llu subsequent_enqueues=%u peak=%u rail_samples=%llu samples=%llu\n",
        s.epoch,s.device,s.hz,s.chunks,s.limit,unsigned(s.chunks==s.limit),unsigned(s.stopped),
        (unsigned long long)s.frames,(unsigned long long)s.zero_before,s.chunks ? s.chunks-1 : 0,s.peak,
        (unsigned long long)s.rails,(unsigned long long)(s.frames*2));
    std::fprintf(stderr,"baseline audio-summary-detail driver=%s requested_hz=%u requested_format=%u requested_channels=2 requested_samples=512 obtained_hz=%u obtained_format=%u obtained_channels=%u obtained_samples=%u obtained_bytes=%u first_submit_us=%llu last_submit_us=%llu span_us=%llu span_source_frames=%llu submit_gap_max_us=%llu queries=%llu zero_queries=%llu query_gap_max_us=%llu application_headroom_excess=%llu application_headroom_max_us=%llu application_plus_block_excess=%llu application_plus_block_max_us=%llu joins=%llu join_step_max=%u internal_step_max=%u\n",
        s.driver,s.hz,unsigned(AUDIO_S16SYS),s.hz,s.obtained_format,s.obtained_channels,s.obtained_samples,s.obtained_size,
        (unsigned long long)s.first_us,(unsigned long long)s.last_us,(unsigned long long)(s.last_us-s.first_us),(unsigned long long)(s.frames-s.first_chunk_frames),(unsigned long long)s.submit_gap_max_us,
        (unsigned long long)s.queries,(unsigned long long)s.zero_queries,(unsigned long long)s.query_gap_max_us,(unsigned long long)s.headroom_excess,(unsigned long long)s.headroom_max_us,
        (unsigned long long)s.block_headroom_excess,(unsigned long long)s.block_headroom_max_us,(unsigned long long)s.joins,s.join_max,s.internal_max);
    std::fprintf(stderr,"baseline audio-gap-interval ending_chunk=%u interval_valid=%u queries=%llu query_valid=%u first_query_after_previous_submit_us=%llu last_query_to_submit_us=%llu limit=%u\n",
        s.max_gap_ending_chunk,unsigned(s.max_gap_ending_chunk!=0),
        (unsigned long long)s.max_gap_queries,unsigned(s.max_gap_queries!=0),
        (unsigned long long)s.max_gap_first_query_us,(unsigned long long)s.max_gap_last_query_us,s.limit);
    std::fprintf(stderr,"baseline audio-drain-window armed=%u closed_intervals=%u request_bytes=%u partial_fills=%llu silence_min_frames=%llu boundary_ambiguous=%llu first_dry_chunk=%u last_dry_chunk=%u partial_step_max=%u boundary_step_max=%u consistency_failures=%llu terminal_status=%u\n",
        unsigned(s.armed),s.chunks ? s.chunks-1 : 0,s.obtained_size,(unsigned long long)s.partial_fills,
        (unsigned long long)s.silence_min_frames,(unsigned long long)s.boundary_empty,s.first_dry_chunk,s.last_dry_chunk,
        s.partial_step_max,s.boundary_step_max,(unsigned long long)s.drain_invalid,unsigned(SDL_GetAudioDeviceStatus(audio)));
    std::fflush(stderr);
}
void close_devices() {
    emit_audio_summary();
#if TOOIE_BASELINE_HOST
    // Called only before renderer startup or after start joined app.end/Deinit.
    host::shutdown();
#else
    pressed_keys = 0;
    input_focused = false;
#endif
    input::Events events;
    const auto now = input_now();
    {
        std::lock_guard guard(input_mutex);
        input_player.publish({}, false, true, now, false, &events);
    }
    print_input_events(events);
#if !TOOIE_BASELINE_HOST
    if (gamepad) { SDL_GameControllerClose(gamepad); gamepad = nullptr; }
#endif
    std::lock_guard guard(audio_mutex);
    if (audio) { SDL_CloseAudioDevice(audio); audio = 0; }
#ifdef __APPLE__
    if (metal_view) { SDL_Metal_DestroyView(metal_view); metal_view = nullptr; }
#endif
    if (window) { SDL_DestroyWindow(window); window = nullptr; }
    SDL_Quit();
}
ultramodern::renderer::callbacks_t renderer_callbacks() { return {create_renderer, nullptr}; }
ultramodern::audio_callbacks_t audio_callbacks() { return {queue_samples, frames_remaining, set_frequency}; }
ultramodern::input::callbacks_t input_callbacks() {
#ifdef BASELINE_PLAYER
    return {poll_input, keyboard_input, controller_rumble, keyboard_device};
#else
    return {poll_input, keyboard_input, nullptr, keyboard_device};
#endif
}

void vi_complete() {
    // The stock VI callback runs after its initial mode and both states are seeded.
    initial_vi_ready.store(true, std::memory_order_release);
}

// Pumps SDL events, starts the guest after initial VI, and requests runtime quit.
void update_gfx(void*) {
#if TOOIE_BASELINE_HOST
    SDL_Event event;
    while(next_event(&event)) host::handle_event(event);
#ifdef BASELINE_PLAYER
    {
        std::lock_guard guard(input_mutex);
        if (!input_player.delivers_physical()) tooie::input::set_rumble(0, false);
    }
#endif
    // Exactly one SDL-owner publication; no second controller registry/poller.
    const auto publication=host::tick(start_requested);
    const bool deadline_reached=std::chrono::steady_clock::now()>=quit_at;
    const bool close=publication.quit;
#ifdef BASELINE_PLAYER
    const bool start_failed=start_requested && !ultramodern::is_game_started();
#else
    constexpr bool start_failed=false, start_refused=false;
#endif
#ifdef BASELINE_TERMINAL_FENCE
    if(!quit_requested && !lifecycle_stop_seen && tooie::lifecycle::stopping()) {
        lifecycle_stop_seen=true;
        report_lifecycle_failure(); // Retained by main's error owner, never shown here.
    }
    const bool lifecycle_stopping=lifecycle_stop_seen;
    // Errors from any thread are only retained; this SDL owner alone turns a retained
    // report or a lifecycle stop into quit.
    const bool lifecycle_quit=lifecycle_stop_seen || runtime_error_retained();
#else
    constexpr bool lifecycle_stopping=false, lifecycle_quit=false;
#endif
    const bool stopping=close || quit_requested || deadline_reached || start_failed || start_refused || lifecycle_stopping;
    // Menu ownership uses the existing tape abort/latch, not a hardware witness.
    const bool activity=publication.activity || host::menu_open();
    const auto physical=stopping ? input::State{} : publication.physical;
    input::Events events;
    const auto now=input_now();
    {
        std::lock_guard guard(input_mutex);
        input_player.publish(physical,activity,stopping,now,
            (publication.focused || publication.physical_admitted) && !stopping,&events);
#ifdef BASELINE_PLAYER
        physical_aim_sample = stopping ? 0 : publication.aim_sample;
        physical_aim_policy = stopping ? 0 : publication.aim_policy;
#endif
    }
    print_input_events(events);
    if(!quit_requested && (close || deadline_reached || start_failed || start_refused || lifecycle_quit)) {
        quit_requested=true;
        quit_published.store(true,std::memory_order_release);
        const char* reason=start_refused ? "unsupported-mod" : start_failed ? "mod-load" : lifecycle_quit ? "lifecycle-failure" : close ? "host/window" : "deadline";
        std::fprintf(stderr,"baseline standard quit requested (%s)\n",reason);
        ultramodern::quit();
#if defined(BASELINE_VI_CONTROLLER_CYCLE)
        ultramodern::detail::dp_freeze::notify_stop();
#endif
    }
    if(!start_requested && !quit_requested && !start_refused && !lifecycle_stopping && initial_vi_ready.load(std::memory_order_acquire)) {
#ifdef BASELINE_PLAYER
        if (!texture_only_selection()) { start_refused=true; return; }
#endif
        // HOST selects the compiled typed guest presentation provider too.
        // Static capability is independent of lazy menu renderer readiness.
        host::render::latch_startup(true);
        host::note_game_started();
        start_requested=true;
#ifdef BASELINE_PLAYER // Matches the port 0 Pak reported by keyboard_device.
        std::fputs("baseline start_game requested after initial VI; input=shared-mapper port0 pak=RumblePak\n",stderr);
#else
        std::fputs("baseline start_game requested after initial VI; input=shared-mapper port0 pak=None\n",stderr);
#endif
        recomp::start_game(u8"bt.n64.us.1.0", "");
    }
#else
    SDL_Event event;
    bool close = false, activity = false;
    while (next_event(&event)) {
        if (event.type == SDL_QUIT) close = true;
        activity |= controller_activity(event);
        if (event.type == SDL_CONTROLLERDEVICEREMOVED && gamepad &&
            event.cdevice.which == SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(gamepad))) {
            SDL_GameControllerClose(gamepad); gamepad = nullptr;
            std::fprintf(stderr, "baseline gamepad detached; neutralized\n");
            select_gamepad();
        }
        if (event.type == SDL_CONTROLLERDEVICEADDED) select_gamepad();
        if (close || quit_requested) continue;
        if (event.type == SDL_WINDOWEVENT && event.window.windowID == input_window_id) {
            if (event.window.event == SDL_WINDOWEVENT_FOCUS_LOST) { input_focused = false; pressed_keys = 0; std::fprintf(stderr, "baseline input focus-lost physical-neutral=1\n"); }
            if (event.window.event == SDL_WINDOWEVENT_FOCUS_GAINED) input_focused = true;
            if (event.window.event == SDL_WINDOWEVENT_CLOSE) close = true;
        }
        if ((event.type == SDL_KEYDOWN || event.type == SDL_KEYUP) && event.key.windowID == input_window_id) {
            if (event.type == SDL_KEYDOWN && event.key.repeat) continue;
            const uint32_t mask = key_mask(event.key.keysym.scancode);
            if (event.type == SDL_KEYDOWN && mask) activity = true;
            if (event.type == SDL_KEYUP) pressed_keys &= ~mask;
            else if (input_focused) {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) close = true;
                pressed_keys |= mask;
            }
        }
    }
    const bool deadline_reached = std::chrono::steady_clock::now() >= quit_at;
    if (close || quit_requested || deadline_reached) { pressed_keys = 0; input_focused = false; }
    activity |= pressed_keys != 0; // Opposing held keys must not qualify as raw neutral.
    auto physical = gamepad_state();
    physical.buttons |= uint16_t(pressed_keys);
    const float key_x = float(bool(pressed_keys & StickRight)) - float(bool(pressed_keys & StickLeft));
    const float key_y = float(bool(pressed_keys & StickUp)) - float(bool(pressed_keys & StickDown));
    if (key_x) physical.x = key_x;
    if (key_y) physical.y = key_y;
    input::Events events;
    const auto now = input_now();
    {
        std::lock_guard guard(input_mutex);
        input_player.publish(physical, activity, close || quit_requested || deadline_reached,
            now, input_focused, &events);
    }
    print_input_events(events);
    if (!quit_requested && (close || deadline_reached)) {
        quit_requested = true;
        quit_published.store(true, std::memory_order_release);
        std::fprintf(stderr, "baseline standard quit requested (%s)\n", close ? "window" : "deadline");
        ultramodern::quit();
#if defined(BASELINE_VI_CONTROLLER_CYCLE)
        ultramodern::detail::dp_freeze::notify_stop();
#endif
    }
    if (!start_requested && !quit_requested && initial_vi_ready.load(std::memory_order_acquire)) {
        start_requested = true;
        std::fprintf(stderr, "baseline start_game requested after initial VI; input=keyboard+optional-gamepad port0 pak=None\n");
        recomp::start_game(u8"bt.n64.us.1.0", "");
    }
#endif
}
}

#if TOOIE_BASELINE_HOST && defined(BASELINE_PLAYER)
extern "C" void tooie_baseline_first_person_aim(uint8_t*, recomp_context* ctx) {
    using namespace baseline;
    uint32_t sample = 0, policy = 0;
    {
        std::lock_guard guard(input_mutex);
        if (!quit_published.load(std::memory_order_acquire) && input_player.delivers_physical() &&
            (physical_aim_policy & TOOIE_FP_AIM_ENABLED)) {
            sample = physical_aim_sample;
            policy = physical_aim_policy;
        }
    }
    ctx->r2 = (gpr)(int32_t)sample;
    ctx->r3 = (gpr)(int32_t)policy;
}
#endif
