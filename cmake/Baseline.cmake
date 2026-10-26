# Baseline and selected player build composition; generic RT64 repairs remain separately selected.
# _baseline_posix selects POSIX host decisions (SDL2 package, OpenSSL, POSIX startup); the binary
# format decisions (link map, qualification gates) use _baseline_elf or _baseline_macho.
set(_baseline_posix OFF)
set(_baseline_elf OFF)
set(_baseline_macho OFF)
if(WIN32)
    # PE/COFF
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64" AND NOT MSVC)
    # Linux qualifies only x86_64 ELF/GNU ar/GNU bfd maps; Windows evidence never applies.
    set(_baseline_posix ON)
    set(_baseline_elf ON)
elseif(APPLE AND CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    # macOS qualifies only arm64 Mach-O/ld64 maps; neither ELF nor PE evidence applies.
    set(_baseline_posix ON)
    set(_baseline_macho ON)
else()
    message(FATAL_ERROR "The reviewed baseline carrier supports Windows, Linux x86_64 or macOS arm64 only")
endif()
# One linker-map and force-include spelling per toolchain family.
function(_baseline_link_map target path)
    if(_baseline_elf)
        target_link_options(${target} PRIVATE -fuse-ld=bfd "LINKER:-Map=${path}" "LINKER:--cref" "LINKER:--no-demangle")
    elseif(_baseline_macho)
        target_link_options(${target} PRIVATE "LINKER:-map,${path}")
    else()
        target_link_options(${target} PRIVATE "/MAP:${path}")
    endif()
endfunction()
function(_baseline_force_include target header)
    if(MSVC)
        target_compile_options(${target} PRIVATE "/FI${header}")
    else()
        target_compile_options(${target} PRIVATE -include "${header}")
    endif()
endfunction()
set(TOOIE_DEPS_ROOT "${CMAKE_SOURCE_DIR}/deps" CACHE PATH "Pinned dependency root")
set(TOOIE_BASELINE_GENERATED_DIR "${CMAKE_BINARY_DIR}/baseline/raw" CACHE PATH "Raw baseline guest corpus")
option(TOOIE_BASELINE_RENDER_BRIDGE "Select reviewed lifetime-safe Honey guest bridge" OFF)
option(TOOIE_BASELINE_SILO_CANDIDATE "Select reviewed Silo bridge used by the current player composition" OFF)
option(TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER "Bounded Silo acquisition receipt only" OFF)
if(TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER AND (NOT TOOIE_BASELINE_SILO_CANDIDATE OR NOT TOOIE_BASELINE_RENDER_BRIDGE))
    message(FATAL_ERROR "Silo acquisition observer requires held Silo and bridge")
endif()
option(TOOIE_BASELINE_RENDER_OBSERVER "Select bounded CPU intermediate observer" OFF)
option(TOOIE_BASELINE_CAMERA_IDENTITY "Prepare reviewed camera identity candidate; enabling remains separately gated" OFF)
option(TOOIE_BASELINE_NPC665 "Select qualified original NPC665 pose owner on actor/PRE carrier" OFF)
if(TOOIE_BASELINE_NPC665 AND NOT TOOIE_BASELINE_CAMERA_IDENTITY)
    message(FATAL_ERROR "NPC665 requires the camera identity composition")
endif()
option(TOOIE_BASELINE_BACKPACK621 "Select finite original621 owner through existing CPU625 transports" OFF)
option(TOOIE_BASELINE_CPU625 "Select reviewed CPU625 public AUTO owner on the actor/PRE carrier" OFF)
if(TOOIE_BASELINE_CPU625 AND NOT TOOIE_BASELINE_CAMERA_IDENTITY)
    message(FATAL_ERROR "CPU625 requires the camera identity composition")
endif()
if(TOOIE_BASELINE_BACKPACK621 AND NOT TOOIE_BASELINE_CPU625)
    message(FATAL_ERROR "Backpack621 requires selected CPU625 transports")
endif()
option(TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER "Bounded read-only camera CPU/guest observation" OFF)
option(TOOIE_BASELINE_CAMERA_CPU_OBSERVER "Bounded processed camera projection CPU measurement" OFF)
if(TOOIE_BASELINE_CAMERA_CPU_OBSERVER AND NOT TOOIE_BASELINE_CAMERA_IDENTITY)
    message(FATAL_ERROR "Camera CPU observer requires camera identity candidate")
endif()
option(TOOIE_BASELINE_PRESENT_TRACE "Select bounded diagnostic present-return trace" OFF)
option(TOOIE_BASELINE_MATRIX_TRACE "Select maintained read-only consumed RT64 matrix diagnostics" OFF)
if(TOOIE_BASELINE_MATRIX_TRACE AND
   (TOOIE_BASELINE_RENDER_OBSERVER OR TOOIE_BASELINE_CAMERA_CPU_OBSERVER))
    message(FATAL_ERROR "Matrix trace and legacy queue observers require the same RT64 source owner")
endif()
if(TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER AND NOT TOOIE_BASELINE_CAMERA_IDENTITY)
    message(FATAL_ERROR "Camera runtime observer requires camera identity candidate")
endif()
if(TOOIE_BASELINE_CAMERA_IDENTITY AND NOT TOOIE_BASELINE_RENDER_BRIDGE)
    message(FATAL_ERROR "Camera identity candidate requires the reviewed guest bridge")
endif()
option(TOOIE_BASELINE_RENDERER_CANDIDATE_OUTPUT "Select candidate executable/archive/map directory; player builds override the executable and map directory" OFF)
option(TOOIE_BASELINE_PLAYER_BOUNDARY "Select source-owned player label providers for the selected composition" OFF)
if(TOOIE_BASELINE_PLAYER_BOUNDARY AND (NOT TOOIE_BASELINE_SILO_CANDIDATE OR NOT TOOIE_BASELINE_RENDERER_CANDIDATE_OUTPUT))
    message(FATAL_ERROR "Player boundary requires held Silo and isolated candidate output")
endif()
if(TOOIE_BASELINE_PLAYER_BOUNDARY AND TOOIE_BASELINE_RENDER_OBSERVER AND NOT TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER)
    message(FATAL_ERROR "Player queue observer requires acquisition accessor providers")
endif()
option(TOOIE_BASELINE_SILO_FAMILY_OBSERVER "Bounded source-qualified family CPU observation" OFF)
if(TOOIE_BASELINE_SILO_FAMILY_OBSERVER AND (NOT TOOIE_BASELINE_SILO_CANDIDATE OR NOT TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER OR NOT TOOIE_BASELINE_RENDER_OBSERVER))
    message(FATAL_ERROR "Family observer requires held Silo, acquisition and render observer")
endif()
set(_baseline_bridge_dir "${CMAKE_BINARY_DIR}/baseline/render-bridge-draw-boundaries")
if(TOOIE_BASELINE_SILO_CANDIDATE)
    if(NOT TOOIE_BASELINE_RENDER_BRIDGE)
        message(FATAL_ERROR "Held Silo candidate requires the accepted bridge composition")
    endif()
    set(_baseline_bridge_dir "${CMAKE_BINARY_DIR}/baseline/render-bridge-silo-candidate")
endif()
if(TOOIE_BASELINE_CAMERA_IDENTITY)
    set(_baseline_bridge_dir "${CMAKE_BINARY_DIR}/baseline/render-bridge-camera-candidate/composition-v2")
endif()
if(TOOIE_BASELINE_RENDER_BRIDGE)
    # Normal-variable override preserves the cached bridge-OFF corpus selection.
    set(TOOIE_BASELINE_GENERATED_DIR "${_baseline_bridge_dir}/raw")
endif()
if(TOOIE_BASELINE_RENDER_OBSERVER AND NOT TOOIE_BASELINE_RENDER_BRIDGE)
    message(FATAL_ERROR "Renderer observer requires the reviewed guest bridge")
endif()
get_filename_component(TOOIE_BASELINE_GENERATED_DIR "${TOOIE_BASELINE_GENERATED_DIR}" ABSOLUTE)
file(REAL_PATH "${CMAKE_BINARY_DIR}" _baseline_build_root)
file(REAL_PATH "${TOOIE_BASELINE_GENERATED_DIR}" _baseline_raw_root)
cmake_path(IS_PREFIX _baseline_build_root "${_baseline_raw_root}" NORMALIZE _baseline_raw_in_build)
if(NOT _baseline_raw_in_build)
    message(FATAL_ERROR "Baseline raw corpus must be under the existing build directory")
endif()
foreach(_header IN ITEMS funcs.h recomp_overlays.inl)
    if(NOT EXISTS "${TOOIE_BASELINE_GENERATED_DIR}/${_header}")
        message(FATAL_ERROR "Missing raw baseline registry: ${_header}; prepare the selected raw guest corpus before configuring")
    endif()
endforeach()
file(GLOB _baseline_guest CONFIGURE_DEPENDS "${TOOIE_BASELINE_GENERATED_DIR}/funcs_*.c")
if(NOT _baseline_guest)
    message(FATAL_ERROR "Missing raw baseline funcs_*.c")
endif()
set(RUNTIME_ROOT "${TOOIE_DEPS_ROOT}/N64ModernRuntime")
set(RUNTIME_RECOMP_INCLUDE "${RUNTIME_ROOT}/N64Recomp/include")
set(_baseline_rt64 "${TOOIE_DEPS_ROOT}/rt64")
if(NOT _baseline_posix)
    # Match the original RT64 Windows CMake's bundled SDL headers/imports/DLL.
    set(_baseline_sdl "${_baseline_rt64}/src/contrib/mupen64plus-win32-deps/SDL2-2.26.3")
    # Official pinned runtime pair; RT64's loader and build-time compiler stay unchanged.
    file(READ "${CMAKE_SOURCE_DIR}/dependencies.lock.json" _baseline_dxc_lock)
    string(JSON _baseline_dxc_dir GET "${_baseline_dxc_lock}" dependencies dxc_windows directory)
    set(_baseline_dxc "${TOOIE_DEPS_ROOT}/${_baseline_dxc_dir}/bin/x64")
    foreach(_dll IN ITEMS dxcompiler.dll dxil.dll)
        string(JSON _pin GET "${_baseline_dxc_lock}" dependencies dxc_windows files "bin/x64/${_dll}")
        if(NOT EXISTS "${_baseline_dxc}/${_dll}")
            message(FATAL_ERROR "Missing pinned DXC runtime: ${_dll}; bootstrap dxc_windows")
        endif()
        file(SHA256 "${_baseline_dxc}/${_dll}" _actual)
        if(NOT _actual STREQUAL _pin)
            message(FATAL_ERROR "Pinned DXC runtime hash mismatch: ${_dll}")
        endif()
    endforeach()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${CMAKE_SOURCE_DIR}/dependencies.lock.json"
        "${_baseline_dxc}/dxcompiler.dll" "${_baseline_dxc}/dxil.dll")
endif()
find_package(Threads REQUIRED)
if(_baseline_posix)
    # Non-Windows runtime/platform hashing uses OpenSSL, as Dependencies.cmake declares.
    find_package(OpenSSL REQUIRED COMPONENTS Crypto)
endif()
add_subdirectory("${RUNTIME_ROOT}" "${CMAKE_BINARY_DIR}/runtime")
target_include_directories(librecomp PUBLIC "${RUNTIME_RECOMP_INCLUDE}")
target_include_directories(ultramodern PUBLIC "${RUNTIME_RECOMP_INCLUDE}")
if(_baseline_posix)
    # Public SDL2 package with RT64's SDL Vulkan window ABI, as NativeHost.cmake selects on Linux.
    find_package(SDL2 2.26 REQUIRED)
    if(TARGET SDL2::SDL2)
        set(_baseline_sdl_link SDL2::SDL2)
    else()
        set(_baseline_sdl_link ${SDL2_LIBRARIES})
    endif()
    set(_baseline_crypto_library OpenSSL::Crypto)
    set(_baseline_timer_library)
    set(_baseline_startup_libraries)
else()
    set(SDL2_INCLUDE_DIRS "${_baseline_sdl}/include")
    set(SDL2_LIBRARIES "${_baseline_sdl}/lib/x64/SDL2.lib")
    set(_baseline_sdl_link "${SDL2_LIBRARIES}")
    set(_baseline_crypto_library bcrypt)
    set(_baseline_timer_library winmm)
    set(_baseline_startup_libraries user32 shell32 ole32 comdlg32)
endif()
set(_baseline_platform_libraries ${_baseline_crypto_library} ${_baseline_timer_library})
set(RT64_STATIC ON CACHE BOOL "Stock static RT64" FORCE)
if(_baseline_elf)
    set(RT64_SDL_WINDOW_VULKAN ON CACHE BOOL "Public SDL Vulkan Linux backend" FORCE)
elseif(_baseline_macho)
    set(RT64_SDL_WINDOW_VULKAN OFF CACHE BOOL "macOS uses RT64's Metal backend" FORCE)
else()
    set(RT64_SDL_WINDOW_VULKAN OFF CACHE BOOL "Stock Windows backend" FORCE)
endif()
add_subdirectory("${_baseline_rt64}" "${CMAKE_BINARY_DIR}/rt64")
if(_baseline_macho)
    # The pinned hlslpp calls labs() after including only <math.h>; the macOS SDK's libc++ no longer
    # reaches <stdlib.h> through it. Dependents include the same RT64 headers.
    target_compile_options(rt64 PUBLIC -include stdlib.h)
endif()

# Only source-demonstrated generic repairs; never select the product matcher bundle.
option(TOOIE_BASELINE_RT64_GENERIC_FIXES "Select pinned generic RT64 repairs" OFF)
if(TOOIE_BASELINE_RT64_GENERIC_FIXES)
    target_include_directories(rt64 PRIVATE "${_baseline_rt64}/src/hle"
        "${_baseline_rt64}/src/render" "${_baseline_rt64}/src/common" "${_baseline_rt64}/src/gbi")
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_baseline_generic_tool "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py")
    foreach(_repair IN ITEMS owner_index_guard transform_upload_guard rotation_interpolation pop_matrix_group_projection projection_residual)
        set(_recipe "${CMAKE_SOURCE_DIR}/patches/rt64/${_repair}.delta.json")
        if(_repair STREQUAL "owner_index_guard")
            set(_relative "src/hle/rt64_game_frame.cpp")
        elseif(_repair STREQUAL "transform_upload_guard")
            set(_relative "src/render/rt64_transform_processor.cpp")
        elseif(_repair STREQUAL "pop_matrix_group_projection")
            set(_relative "src/gbi/rt64_gbi_extended.cpp")
        elseif(_repair STREQUAL "projection_residual")
            set(_relative "src/render/rt64_projection_processor.cpp")
        else()
            set(_relative "src/common/rt64_math.cpp")
        endif()
        get_filename_component(_filename "${_relative}" NAME)
        set(_input "${_baseline_rt64}/${_relative}")
        set(_output "${CMAKE_BINARY_DIR}/baseline/rt64_generic/${_filename}")
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${_baseline_generic_tool}"
            --dependency "${_baseline_rt64}" --recipe "${_recipe}" --output "${_output}"
            RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Baseline generic RT64 repair failed: ${_repair}: ${_stdout}${_stderr}")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "${_baseline_generic_tool}" "${_recipe}" "${_input}")
        get_target_property(_sources rt64 SOURCES)
        set(_updated)
        set(_replaced 0)
        foreach(_source IN LISTS _sources)
            get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
            if(_absolute STREQUAL _input)
                list(APPEND _updated "${_output}")
                math(EXPR _replaced "${_replaced}+1")
            else()
                list(APPEND _updated "${_source}")
            endif()
        endforeach()
        if(NOT _replaced EQUAL 1)
            message(FATAL_ERROR "Expected one baseline generic source for ${_repair}; got ${_replaced}")
        endif()
        set_property(TARGET rt64 PROPERTY SOURCES "${_updated}")
    endforeach()
endif()
if(TOOIE_BASELINE_RENDER_OBSERVER OR TOOIE_BASELINE_CAMERA_CPU_OBSERVER)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_observer_tool "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_render_observer.py")
    set(_observer_input "${_baseline_rt64}/src/hle/rt64_workload_queue.cpp")
    set(_observer_patch "${CMAKE_SOURCE_DIR}/patches/rt64/baseline_queue_observer.patch")
    set(_observer_inl "${CMAKE_SOURCE_DIR}/tools/baseline/frame_match_observer.inl")
    set(_observer_output "${CMAKE_BINARY_DIR}/baseline/render-observer/frame_match_queue.cpp")
    if(TOOIE_BASELINE_CAMERA_CPU_OBSERVER)
        set(_camera_cpu_tool "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_camera_cpu_observer.py")
        set(_camera_cpu_pins "${CMAKE_SOURCE_DIR}/tools/baseline/camera_cpu_observer_pins.json")
        set(_camera_cpu_inl "${CMAKE_SOURCE_DIR}/tools/baseline/camera_projection_observer.inl")
        if(TOOIE_BASELINE_RENDER_OBSERVER)
            set(_camera_cpu_mode combined)
        else()
            set(_camera_cpu_mode camera)
        endif()
        set(_camera_cpu_patch "${CMAKE_SOURCE_DIR}/patches/rt64/baseline_queue_${_camera_cpu_mode}_observer.patch")
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${_camera_cpu_tool}"
            --source "${_observer_input}" --patch "${_camera_cpu_patch}" --camera "${_camera_cpu_inl}"
            --pins "${_camera_cpu_pins}" --mode "${_camera_cpu_mode}" --honey "${_observer_inl}"
            --output "${_observer_output}"
            RESULT_VARIABLE _observer_result ERROR_VARIABLE _observer_error)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "${_camera_cpu_tool}" "${_camera_cpu_pins}" "${_camera_cpu_inl}" "${_camera_cpu_patch}"
            "${CMAKE_SOURCE_DIR}/tools/baseline/shadow_witness.hpp")
    else()
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${_observer_tool}"
            --source "${_observer_input}" --patch "${_observer_patch}"
            --observer "${_observer_inl}" --output "${_observer_output}"
            RESULT_VARIABLE _observer_result ERROR_VARIABLE _observer_error)
    endif()
    if(NOT _observer_result EQUAL 0)
        message(FATAL_ERROR "Pinned baseline observer materialization failed: ${_observer_error}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_observer_tool}" "${_observer_input}" "${_observer_patch}" "${_observer_inl}")
    get_target_property(_sources rt64 SOURCES)
    set(_updated)
    set(_replaced 0)
    foreach(_source IN LISTS _sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
        if(_absolute STREQUAL _observer_input)
            list(APPEND _updated "${_observer_output}")
            math(EXPR _replaced "${_replaced}+1")
        else()
            list(APPEND _updated "${_source}")
        endif()
    endforeach()
    if(NOT _replaced EQUAL 1)
        message(FATAL_ERROR "Expected one baseline workload queue owner; got ${_replaced}")
    endif()
    set_property(TARGET rt64 PROPERTY SOURCES "${_updated}")
    target_include_directories(rt64 PRIVATE "${_baseline_rt64}/src/hle"
        "${_baseline_rt64}/src/render" "${_baseline_rt64}/src/common")
endif()
# Reuse the maintained diagnostic without selecting the legacy native-host bundle.
if(TOOIE_BASELINE_MATRIX_TRACE)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_baseline_matrix_trace_tool "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py")
    set(_baseline_matrix_trace_recipe "${CMAKE_SOURCE_DIR}/patches/rt64/matrix_trace.delta.json")
    set(_baseline_matrix_trace_input "${_baseline_rt64}/src/hle/rt64_workload_queue.cpp")
    set(_baseline_matrix_trace_output "${CMAKE_BINARY_DIR}/baseline/rt64_generic/rt64_workload_queue.cpp")
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${_baseline_matrix_trace_tool}"
        --dependency "${_baseline_rt64}" --recipe "${_baseline_matrix_trace_recipe}"
        --output "${_baseline_matrix_trace_output}"
        RESULT_VARIABLE _baseline_matrix_trace_result
        OUTPUT_VARIABLE _baseline_matrix_trace_stdout ERROR_VARIABLE _baseline_matrix_trace_stderr)
    if(NOT _baseline_matrix_trace_result EQUAL 0)
        message(FATAL_ERROR "Pinned baseline matrix trace failed: ${_baseline_matrix_trace_stdout}${_baseline_matrix_trace_stderr}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_baseline_matrix_trace_tool}" "${_baseline_matrix_trace_recipe}" "${_baseline_matrix_trace_input}")
    get_target_property(_baseline_matrix_trace_sources rt64 SOURCES)
    set(_baseline_matrix_trace_updated)
    set(_baseline_matrix_trace_replaced 0)
    foreach(_source IN LISTS _baseline_matrix_trace_sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
        if(_absolute STREQUAL _baseline_matrix_trace_input)
            list(APPEND _baseline_matrix_trace_updated "${_baseline_matrix_trace_output}")
            math(EXPR _baseline_matrix_trace_replaced "${_baseline_matrix_trace_replaced}+1")
        else()
            list(APPEND _baseline_matrix_trace_updated "${_source}")
        endif()
    endforeach()
    if(NOT _baseline_matrix_trace_replaced EQUAL 1)
        message(FATAL_ERROR "Expected one baseline matrix trace queue owner; got ${_baseline_matrix_trace_replaced}")
    endif()
    set_property(TARGET rt64 PROPERTY SOURCES "${_baseline_matrix_trace_updated}")
    target_sources(rt64 PRIVATE "${CMAKE_SOURCE_DIR}/src/rt64_matrix_trace.cpp")
    target_include_directories(rt64 PRIVATE "${CMAKE_SOURCE_DIR}/src" "${_baseline_rt64}/src"
        "${_baseline_rt64}/src/hle" "${_baseline_rt64}/src/render" "${_baseline_rt64}/src/common")
endif()
# Explicit opt-in replaces only the two pinned parser owners; OFF retains originals.
set(_baseline_adapter_source "${CMAKE_SOURCE_DIR}/tools/baseline/adapters.cpp")
if(TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_camera_observer_tool "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_camera_runtime_observer.py")
    set(_camera_observer_dir "${CMAKE_BINARY_DIR}/baseline/camera-runtime-observer")
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${_camera_observer_tool}"
        --root "${CMAKE_SOURCE_DIR}" --output "${_camera_observer_dir}" --enabled --camera-enabled
        RESULT_VARIABLE _camera_result ERROR_VARIABLE _camera_error)
    if(NOT _camera_result EQUAL 0)
        message(FATAL_ERROR "Camera runtime observer materialization failed: ${_camera_error}")
    endif()
    get_target_property(_sources rt64 SOURCES)
    set(_updated)
    set(_replaced 0)
    foreach(_source IN LISTS _sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
        if(_absolute STREQUAL "${_baseline_rt64}/src/gbi/rt64_gbi_rdp.cpp" OR
           _absolute STREQUAL "${_baseline_rt64}/src/hle/rt64_rsp.cpp")
            get_filename_component(_filename "${_absolute}" NAME)
            list(APPEND _updated "${_camera_observer_dir}/${_filename}")
            math(EXPR _replaced "${_replaced}+1")
        else()
            list(APPEND _updated "${_source}")
        endif()
    endforeach()
    if(NOT _replaced EQUAL 2)
        message(FATAL_ERROR "Camera observer requires exactly two original parser owners")
    endif()
    set_property(TARGET rt64 PROPERTY SOURCES "${_updated}")
    target_include_directories(rt64 PRIVATE "${_baseline_rt64}/src")
    set(_baseline_adapter_source "${_camera_observer_dir}/adapters.cpp")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_camera_observer_tool}" "${CMAKE_SOURCE_DIR}/tools/baseline/camera_runtime_observer.hpp"
        "${CMAKE_SOURCE_DIR}/tools/baseline/camera_guest_summary.hpp"
        "${CMAKE_SOURCE_DIR}/tools/baseline/shadow_witness.hpp"
        "${CMAKE_SOURCE_DIR}/tools/baseline/adapters.cpp"
        "${_baseline_rt64}/src/gbi/rt64_gbi_rdp.cpp" "${_baseline_rt64}/src/hle/rt64_rsp.cpp")
endif()
add_library(BaselineRecompiledFuncs STATIC ${_baseline_guest})
target_include_directories(BaselineRecompiledFuncs PRIVATE "${RUNTIME_RECOMP_INCLUDE}" "${TOOIE_BASELINE_GENERATED_DIR}")
if(TOOIE_BASELINE_CAMERA_IDENTITY)
    target_include_directories(BaselineRecompiledFuncs PRIVATE "${_baseline_bridge_dir}")
endif()
target_compile_options(BaselineRecompiledFuncs PRIVATE -fno-strict-aliasing -Wno-unused-variable -Wno-implicit-function-declaration)
add_executable(TooieBaseline tools/baseline/main.cpp tools/baseline/devices.cpp)
if(TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER)
    target_include_directories(TooieBaseline PRIVATE "${CMAKE_SOURCE_DIR}/tools/baseline" "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate")
    target_compile_definitions(TooieBaseline PRIVATE TOOIE_BASELINE_CAMERA_RUNTIME_OBSERVER=1)
endif()
if(TOOIE_BASELINE_RENDERER_CANDIDATE_OUTPUT)
    set(_baseline_executable_dir "${CMAKE_BINARY_DIR}/baseline/renderer-candidate-bin")
    set_target_properties(rt64 PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
else()
    set(_baseline_executable_dir "${CMAKE_BINARY_DIR}/baseline/bin")
endif()
option(TOOIE_BASELINE_PLAYER "Banjo-Tooie: Scurvy Dog Port player startup instead of the engineering command line" OFF)
if(TOOIE_BASELINE_PLAYER)
    # A player build never replaces an engineering executable in the same tree.
    set(_baseline_executable_dir "${CMAKE_BINARY_DIR}/baseline/player-bin")
endif()
set_target_properties(TooieBaseline PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}"
    PDB_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
set(TOOIE_BASELINE_FATAL_PROVIDERS "" CACHE STRING "Individually declared rejected-generation fatal providers")
set(TOOIE_BASELINE_FATAL_IMPORTS "" CACHE STRING "Individually declared declared imports (including supported overlay registration)")
option(TOOIE_BASELINE_BOOT_PI "Declared preworker boot PI ROM transport" OFF)
option(TOOIE_BASELINE_BOOT_OBSERVER "Declared read-only boot initializer pre/post observer" OFF)
set(TOOIE_BASELINE_BOOT_PATCH_DIR "" CACHE PATH "Prepared fixed guest initializer patch")
option(TOOIE_BASELINE_CORE1_PUBLICATION "Observe original core1 bytes then publish its bounded range" OFF)
option(TOOIE_BASELINE_VI_CONTROLLER_CYCLE "Original first overlay arm with audio, timer ownership and suspended-stop children" OFF)
option(TOOIE_BASELINE_TERMINAL_FENCE "Opt-in retained-memory guest fence before terminal exit" OFF)
if(TOOIE_BASELINE_TERMINAL_FENCE AND NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
    message(FATAL_ERROR "Terminal guest fence requires the selected VI/controller baseline")
endif()
option(TOOIE_BASELINE_LIFECYCLE_FIXTURE "Finite native worker ownership fixture on the selected baseline" OFF)
option(TOOIE_BASELINE_EXTERNAL_WAIT_FIXTURE "Select the finite lifecycle external-message wait child" OFF)
option(TOOIE_BASELINE_SAVE_DRAIN_FIXTURE "Select the existing native saver fixture only" OFF)
option(TOOIE_BASELINE_SAVE_COMPOSITION "Select the existing saver with the terminal guest fence" OFF)
if(TOOIE_BASELINE_SAVE_COMPOSITION AND (NOT TOOIE_BASELINE_TERMINAL_FENCE OR TOOIE_BASELINE_SAVE_DRAIN_FIXTURE))
    message(FATAL_ERROR "Saver composition requires terminal fence ON and saver fixture OFF")
endif()
if(TOOIE_BASELINE_EXTERNAL_WAIT_FIXTURE AND NOT TOOIE_BASELINE_LIFECYCLE_FIXTURE)
    message(FATAL_ERROR "External wait fixture requires the lifecycle fixture")
endif()
if(TOOIE_BASELINE_LIFECYCLE_FIXTURE AND NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
    message(FATAL_ERROR "Lifecycle fixture requires the selected VI/controller baseline condition")
endif()
option(TOOIE_BASELINE_HEAP_PATCH "Select the accepted M2 heap body in the combined initializer image" OFF)
option(TOOIE_BASELINE_RENDERER_COMPARISON "Public developer and Manual60 baseline comparison settings" OFF)
option(TOOIE_BASELINE_HOST "Select the reviewed minimum baseline menu/input/presentation host" OFF)
if(TOOIE_BASELINE_HOST AND (TOOIE_BASELINE_RENDERER_COMPARISON OR NOT TOOIE_BASELINE_CAMERA_IDENTITY OR NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE))
    message(FATAL_ERROR "Minimum host requires camera/VI composition and excludes the developer comparison Inspector")
endif()
# Observe the actual present return without selecting legacy UI/vsync policy.
if(TOOIE_BASELINE_PRESENT_TRACE)
    if(NOT TOOIE_BASELINE_PLAYER OR NOT TOOIE_BASELINE_HOST)
        message(FATAL_ERROR "Present trace requires the baseline player/minimum-host composition")
    endif()
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_baseline_present_trace_tool "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py")
    set(_baseline_present_trace_recipe "${CMAKE_SOURCE_DIR}/patches/rt64/present_trace.delta.json")
    set(_baseline_present_trace_input "${_baseline_rt64}/src/hle/rt64_present_queue.cpp")
    set(_baseline_present_trace_output "${CMAKE_BINARY_DIR}/baseline/rt64_generic/rt64_present_queue.cpp")
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${_baseline_present_trace_tool}"
        --dependency "${_baseline_rt64}" --recipe "${_baseline_present_trace_recipe}"
        --output "${_baseline_present_trace_output}"
        RESULT_VARIABLE _baseline_present_trace_result
        OUTPUT_VARIABLE _baseline_present_trace_stdout ERROR_VARIABLE _baseline_present_trace_stderr)
    if(NOT _baseline_present_trace_result EQUAL 0)
        message(FATAL_ERROR "Pinned baseline present trace failed: ${_baseline_present_trace_stdout}${_baseline_present_trace_stderr}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_baseline_present_trace_tool}" "${_baseline_present_trace_recipe}" "${_baseline_present_trace_input}")
    get_target_property(_baseline_present_trace_sources rt64 SOURCES)
    set(_baseline_present_trace_updated)
    set(_baseline_present_trace_replaced 0)
    foreach(_source IN LISTS _baseline_present_trace_sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
        if(_absolute STREQUAL _baseline_present_trace_input)
            list(APPEND _baseline_present_trace_updated "${_baseline_present_trace_output}")
            math(EXPR _baseline_present_trace_replaced "${_baseline_present_trace_replaced}+1")
        else()
            list(APPEND _baseline_present_trace_updated "${_source}")
        endif()
    endforeach()
    if(NOT _baseline_present_trace_replaced EQUAL 1)
        message(FATAL_ERROR "Expected one baseline present trace queue owner; got ${_baseline_present_trace_replaced}")
    endif()
    set_property(TARGET rt64 PROPERTY SOURCES "${_baseline_present_trace_updated}")
    target_sources(rt64 PRIVATE "${CMAKE_SOURCE_DIR}/src/pacing_present_probe.cpp")
    target_include_directories(rt64 PRIVATE "${CMAKE_SOURCE_DIR}/src" "${_baseline_rt64}/src"
        "${_baseline_rt64}/src/hle" "${_baseline_rt64}/src/render" "${_baseline_rt64}/src/common")
endif()

# Plume Vulkan: per-swap-chain present ID reset (all platforms) and the default-OFF, unverified
# Windows acquire-pacing candidate. Pinned delta overlay; retrieved RT64 stays intact.
option(TOOIE_BASELINE_RT64_VULKAN_ACQUIRE_PACING "Unverified Windows Vulkan acquire-paced present candidate" OFF)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(_plume_vulkan_input "${_baseline_rt64}/src/contrib/plume/plume_vulkan.cpp")
set(_plume_vulkan_recipe "${CMAKE_SOURCE_DIR}/patches/rt64/vulkan_present_id.delta.json")
set(_plume_vulkan_output "${CMAKE_BINARY_DIR}/baseline/rt64_plume/plume_vulkan.cpp")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py"
    --dependency "${_baseline_rt64}" --recipe "${_plume_vulkan_recipe}" --output "${_plume_vulkan_output}"
    RESULT_VARIABLE _plume_vulkan_result OUTPUT_VARIABLE _plume_vulkan_out ERROR_VARIABLE _plume_vulkan_err)
if(NOT _plume_vulkan_result EQUAL 0)
    message(FATAL_ERROR "Plume Vulkan overlay failed: ${_plume_vulkan_out}${_plume_vulkan_err}")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py"
    "${_plume_vulkan_recipe}" "${_plume_vulkan_input}")
get_target_property(_plume_dir plume SOURCE_DIR)
get_target_property(_plume_sources plume SOURCES)
set(_plume_updated)
set(_plume_replaced 0)
foreach(_source IN LISTS _plume_sources)
    get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_plume_dir}")
    if(_absolute STREQUAL _plume_vulkan_input)
        list(APPEND _plume_updated "${_plume_vulkan_output}")
        math(EXPR _plume_replaced "${_plume_replaced}+1")
    else()
        list(APPEND _plume_updated "${_source}")
    endif()
endforeach()
if(NOT _plume_replaced EQUAL 1)
    message(FATAL_ERROR "Expected one plume Vulkan source owner; got ${_plume_replaced}")
endif()
set_property(TARGET plume PROPERTY SOURCES "${_plume_updated}")
target_include_directories(plume PRIVATE "${_baseline_rt64}/src/contrib/plume")
if(TOOIE_BASELINE_RT64_VULKAN_ACQUIRE_PACING)
    target_compile_definitions(plume PRIVATE TOOIE_RT64_VULKAN_ACQUIRE_PACING=1)
endif()

target_compile_definitions(TooieBaseline PRIVATE "TOOIE_BASELINE_HOST=$<BOOL:${TOOIE_BASELINE_HOST}>")
target_compile_definitions(BaselineRecompiledFuncs PRIVATE "TOOIE_BASELINE_HOST=$<BOOL:${TOOIE_BASELINE_HOST}>")
if(TOOIE_BASELINE_HOST)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_host_backend "${CMAKE_BINARY_DIR}/baseline/minimum-host-backend")
    # Reuse the existing pinned delta materializer. Retrieved RT64 stays intact.
    foreach(_relative IN ITEMS imgui/imgui_impl_sdl2_custom.cpp imgui/imgui_impl_sdl2_custom.h gui/rt64_inspector.cpp gui/rt64_inspector.h)
        get_filename_component(_filename "${_relative}" NAME)
        string(REPLACE "." "_" _recipe_name "${_filename}")
        set(_recipe "${CMAKE_SOURCE_DIR}/patches/rt64/minimum_host_${_recipe_name}.delta.json")
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py"
            --dependency "${_baseline_rt64}" --recipe "${_recipe}" --output "${_host_backend}/${_relative}"
            RESULT_VARIABLE _host_prepare_result OUTPUT_VARIABLE _host_prepare_out ERROR_VARIABLE _host_prepare_err)
        if(NOT _host_prepare_result EQUAL 0)
            message(FATAL_ERROR "Minimum host pinned backend preparation failed: ${_host_prepare_out}${_host_prepare_err}")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_recipe}" "${_baseline_rt64}/src/${_relative}")
    endforeach()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/tools/prepare_rt64_matching.py")
    get_target_property(_host_sources rt64 SOURCES)
    set(_host_updated)
    set(_host_replaced 0)
    foreach(_source IN LISTS _host_sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE BASE_DIR "${_baseline_rt64}")
        if(_absolute STREQUAL "${_baseline_rt64}/src/imgui/imgui_impl_sdl2_custom.cpp")
            list(APPEND _host_updated "${_host_backend}/imgui/imgui_impl_sdl2_custom.cpp")
            math(EXPR _host_replaced "${_host_replaced}+1")
        elseif(_absolute STREQUAL "${_baseline_rt64}/src/gui/rt64_inspector.cpp")
            list(APPEND _host_updated "${_host_backend}/gui/rt64_inspector.cpp")
            math(EXPR _host_replaced "${_host_replaced}+1")
        else()
            list(APPEND _host_updated "${_source}")
        endif()
    endforeach()
    if(NOT _host_replaced EQUAL 2)
        message(FATAL_ERROR "Minimum host must replace exactly the existing SDL backend and Inspector source owners")
    endif()
    set_property(TARGET rt64 PROPERTY SOURCES "${_host_updated}")
    target_include_directories(rt64 BEFORE PRIVATE "${_host_backend}")
    target_include_directories(TooieBaseline BEFORE PRIVATE "${_host_backend}")
    target_include_directories(TooieBaseline PRIVATE "${CMAKE_SOURCE_DIR}/src" "${CMAKE_SOURCE_DIR}/tools/baseline"
        "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host" "${RUNTIME_ROOT}/thirdparty")
    target_sources(TooieBaseline PRIVATE tools/baseline/minimum_host.cpp tools/baseline/minimum_render.cpp
        tools/baseline/minimum_presentation.cpp tools/baseline/minimum_menu.cpp
        src/frontend_input_preference.cpp src/frontend_config.cpp src/widescreen.cpp)
endif()
if(TOOIE_BASELINE_PLAYER)
    if(NOT TOOIE_BASELINE_HOST OR NOT TOOIE_BASELINE_SAVE_COMPOSITION)
        message(FATAL_ERROR "Player startup requires the minimum host and saver composition")
    endif()
    foreach(_engineering IN ITEMS RENDER_OBSERVER CAMERA_RUNTIME_OBSERVER CAMERA_CPU_OBSERVER
        SILO_ACQUISITION_OBSERVER SILO_FAMILY_OBSERVER LIFECYCLE_FIXTURE EXTERNAL_WAIT_FIXTURE SAVE_DRAIN_FIXTURE)
        if(TOOIE_BASELINE_${_engineering})
            message(FATAL_ERROR "Player build excludes engineering selection TOOIE_BASELINE_${_engineering}")
        endif()
    endforeach()
    if(NOT TOOIE_PLAYER_VERSION)
        message(FATAL_ERROR "TOOIE_PLAYER_VERSION must be declared before the baseline include")
    endif()
    # Small generated identity only; build reports belong to packaging.
    set(_player_generated "${CMAKE_BINARY_DIR}/baseline/player")
    file(CONFIGURE OUTPUT "${_player_generated}/player_version.hpp" CONTENT [[
#pragma once
namespace baseline::player::build {
inline constexpr char product[] = "Banjo-Tooie: Scurvy Dog Port";
inline constexpr char version[] = "@TOOIE_PLAYER_VERSION@";
}
]] @ONLY)
    if(_baseline_posix)
        set(_baseline_player_startup tools/baseline/player_startup_posix.cpp)
        target_link_libraries(TooieBaseline PRIVATE nfd)
    else()
        set(_baseline_player_startup tools/baseline/player_startup.cpp)
    endif()
    target_sources(TooieBaseline PRIVATE ${_baseline_player_startup} tools/baseline/issue_evidence.cpp)
    target_include_directories(TooieBaseline PRIVATE "${_player_generated}")
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_PLAYER=1)
    if(_baseline_posix)
        set_target_properties(TooieBaseline PROPERTIES OUTPUT_NAME BanjoTooieScurvyDogPort)
    else()
        target_link_libraries(TooieBaseline PRIVATE ${_baseline_startup_libraries})
        # Double-click play opens no console; diagnostics go to the profile log.
        set_target_properties(TooieBaseline PROPERTIES OUTPUT_NAME BanjoTooieScurvyDogPort WIN32_EXECUTABLE TRUE)
        target_link_options(TooieBaseline PRIVATE /ENTRY:mainCRTStartup)
        # Release-family PDB reference without the build machine's absolute path.
        target_link_options(TooieBaseline PRIVATE "/PDBALTPATH:%_PDB%")
    endif()
    if(_baseline_posix)
        add_executable(BaselinePlayerStartupTest EXCLUDE_FROM_ALL tests/baseline_player_startup_posix_test.cpp
            ${_baseline_player_startup})
        target_link_libraries(BaselinePlayerStartupTest PRIVATE ${_baseline_sdl_link} nfd)
    else()
        add_executable(BaselinePlayerStartupTest EXCLUDE_FROM_ALL tests/baseline_player_startup_test.cpp
            ${_baseline_player_startup})
    endif()
    target_include_directories(BaselinePlayerStartupTest PRIVATE "${CMAKE_SOURCE_DIR}/tools/baseline" "${_player_generated}")
    target_compile_definitions(BaselinePlayerStartupTest PRIVATE NOMINMAX)
    if(NOT _baseline_posix)
        target_link_libraries(BaselinePlayerStartupTest PRIVATE ${_baseline_startup_libraries})
    endif()
    set_target_properties(BaselinePlayerStartupTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
endif()
# Separate guest/image selection, exact raw imports/providers/layout/hash and
# embedding checks are inserted beside the existing camera qualification owner.
# This block alone must never enable native HOST with a HOST-OFF guest image.

option(TOOIE_BASELINE_SUCCESS_TRACE "Repeat success-only baseline qualification logs" OFF)
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_SUCCESS_TRACE=$<BOOL:${TOOIE_BASELINE_SUCCESS_TRACE}>")
option(TOOIE_BASELINE_HONEY_PATCH "Select the finite Honey guest draw in the combined M2 image" OFF)
option(TOOIE_BASELINE_HONEY_EMIT "Select the emission-on prepared Honey guest body" OFF)
if(TOOIE_BASELINE_RENDER_BRIDGE)
    if(NOT TOOIE_BASELINE_HEAP_PATCH OR NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE OR TOOIE_BASELINE_HONEY_PATCH)
        message(FATAL_ERROR "Renderer bridge requires heap/VI and excludes legacy Honey")
    endif()
    set(TOOIE_BASELINE_BOOT_PATCH_DIR "${_baseline_bridge_dir}")
endif()
if(TOOIE_BASELINE_HONEY_EMIT AND NOT TOOIE_BASELINE_HONEY_PATCH)
    message(FATAL_ERROR "Honey emission requires its selected guest patch")
endif()
if(TOOIE_BASELINE_HONEY_PATCH AND NOT TOOIE_BASELINE_HEAP_PATCH)
    message(FATAL_ERROR "Honey selection requires the accepted combined heap patch")
endif()
if(TOOIE_BASELINE_RENDERER_COMPARISON AND NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
    message(FATAL_ERROR "Renderer comparison requires the VI baseline condition")
endif()
if(TOOIE_BASELINE_HEAP_PATCH AND (NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE OR NOT TOOIE_BASELINE_BOOT_PATCH_DIR))
    message(FATAL_ERROR "Heap selection requires the two-initializer baseline patch condition")
endif()
target_compile_definitions(TooieBaseline PRIVATE
    BASELINE_HEAP_PATCH=$<BOOL:${TOOIE_BASELINE_HEAP_PATCH}>
    BASELINE_HONEY_PATCH=$<BOOL:${TOOIE_BASELINE_HONEY_PATCH}>
    BASELINE_RENDERER_COMPARISON=$<BOOL:${TOOIE_BASELINE_RENDERER_COMPARISON}>)
foreach(_retired IN ITEMS MODEL_LABEL_EXPERIMENT MODEL_LABEL_EMIT CORE1_STOP CORE1_INIT MAIN_ENTRY_STOP CIC_READ_STOP ROM_PIO_STOP ROM_PIO_BRIDGE VI_CREATE_OFF VI_FIRST_EVENT_OFF VI_STATUS_RETURN VI_WORKER_CYCLE VI_MAIN_PRELOADER VI_CORE2_PUBLICATION VI_POST_CORE2_PREFIX VI_SCHEDULER_START VI_SCHEDULER_EVENT VI_INPUT_PREFIX VI_TIMER_OWNERSHIP)
    if(TOOIE_BASELINE_${_retired})
        message(FATAL_ERROR "Retired baseline terminal selection TOOIE_BASELINE_${_retired}; use its historical source/corpus")
    endif()
endforeach()
set(TOOIE_BASELINE_CORE1_REFERENCE "${CMAKE_BINARY_DIR}/baseline/core1-publication/core1-observation.bin" CACHE FILEPATH "Pinned disposable core1 observation bytes")
set(_baseline_known_fatal
    boot___osException boot_handle_CpU boot___osDispatchThread boot_osWritebackDCache
    boot_osInvalICache boot_osUnmapTLBAll boot_osMapTLBRdb boot___osGetCause boot___osProbeTLB
    func_8001DDC0 ovl_entrypoint_alternate boot_osInitialize tooie_core1_osInitialize)
set(_baseline_known_imports recomp_syscall_handler __osGetSR_recomp __osSetSR_recomp
    __osSiRawReadIo_recomp __osSiRawWriteIo_recomp osMapTLBRdb_recomp __osGetCause_recomp
    __osSiGetAccess_recomp __osSiRawStartDma_recomp __osSiRelAccess_recomp
    osViGetCurrentLine_recomp osPfsInit_recomp)
if(TOOIE_BASELINE_FATAL_PROVIDERS OR TOOIE_BASELINE_FATAL_IMPORTS OR TOOIE_BASELINE_BOOT_PI OR TOOIE_BASELINE_BOOT_PATCH_DIR OR TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
    target_sources(TooieBaseline PRIVATE "${_baseline_adapter_source}")
    foreach(_provider IN LISTS TOOIE_BASELINE_FATAL_PROVIDERS)
        if(NOT _provider IN_LIST _baseline_known_fatal)
            message(FATAL_ERROR "Undeclared baseline fatal provider: ${_provider}")
        endif()
        target_compile_definitions(TooieBaseline PRIVATE "BASELINE_FAIL_${_provider}=1")
    endforeach()
    foreach(_import IN LISTS TOOIE_BASELINE_FATAL_IMPORTS)
        if(NOT _import IN_LIST _baseline_known_imports)
            message(FATAL_ERROR "Undeclared baseline fatal import: ${_import}")
        endif()
        target_compile_definitions(TooieBaseline PRIVATE "BASELINE_IMPORT_${_import}=1")
    endforeach()
    # Ignored names are absent from generated funcs.h; retain exact ABI declarations.
    if(MSVC)
        target_compile_options(BaselineRecompiledFuncs PRIVATE "/FI${CMAKE_SOURCE_DIR}/tools/baseline/adapters.h")
    else()
        target_compile_options(BaselineRecompiledFuncs PRIVATE -include "${CMAKE_SOURCE_DIR}/tools/baseline/adapters.h")
    endif()
endif()
if(TOOIE_BASELINE_PLAYER AND NOT (TOOIE_BASELINE_VI_CONTROLLER_CYCLE AND TOOIE_BASELINE_TERMINAL_FENCE))
    message(FATAL_ERROR "F6 player arm requires the selected VI-cycle terminal-fence timer/events composition")
endif()
if(TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
    if(NOT TOOIE_BASELINE_CORE1_PUBLICATION OR "tooie_core1_osInitialize" IN_LIST TOOIE_BASELINE_FATAL_PROVIDERS)
        message(FATAL_ERROR "VI input-prefix arm requires bounded publication and excludes fatal initializer selection")
    endif()
    if(NOT EXISTS "${CMAKE_BINARY_DIR}/baseline/ipl3-scatter/ipl3_shape.hpp")
        message(FATAL_ERROR "VI input-prefix arm requires authenticated baseline-local IPL3 preparation")
    endif()
    set(TOOIE_BASELINE_CORE2_REFERENCE "${CMAKE_BINARY_DIR}/baseline/core2-publication/core2-observation.bin" CACHE FILEPATH "Pinned disposable core2 observation bytes")
    file(REAL_PATH "${TOOIE_BASELINE_CORE2_REFERENCE}" _baseline_core2_reference)
    cmake_path(IS_PREFIX _baseline_build_root "${_baseline_core2_reference}" NORMALIZE _baseline_core2_in_build)
    file(SHA256 "${_baseline_core2_reference}" _baseline_core2_sha)
    if(NOT _baseline_core2_in_build OR NOT _baseline_core2_sha STREQUAL "6522eefee489b670fb24e594642c5bfb693e639e2c6d82c40dc9fe2eaa12adc7")
        message(FATAL_ERROR "Core2 observation reference location/hash differs from the reviewed condition")
    endif()
    # Configure identity only: adapters.cpp checks this SHA-256 over guest-order memory; the bytes are never embedded.
    target_sources(TooieBaseline PRIVATE src/ipl3_boot_state.cpp)
    file(SHA256 "${CMAKE_SOURCE_DIR}/src/si_adapter.cpp" _baseline_si_cpp_sha)
    file(SHA256 "${CMAKE_SOURCE_DIR}/src/si_adapter.hpp" _baseline_si_hpp_sha)
    if(NOT _baseline_si_cpp_sha STREQUAL "20f8c0f51edf53360b41630bc6c901e87ffcef42bc9a09948444a7abe682d806" OR
        NOT _baseline_si_hpp_sha STREQUAL "38aabc63d2d99d1ffbd5178c6e545cddbc5c774f35d1a751c4349f8c8ff45806")
        message(FATAL_ERROR "Resource SI provider differs from the reviewed unchanged source")
    endif()
    target_sources(TooieBaseline PRIVATE src/si_adapter.cpp)
    target_include_directories(TooieBaseline PRIVATE "${CMAKE_SOURCE_DIR}/src" "${CMAKE_BINARY_DIR}/baseline/ipl3-scatter")
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_CORE1_INIT=1 BASELINE_CIC_OBSERVER=1 BASELINE_ROM_PIO_BRIDGE=1 BASELINE_VI_CONTROLLER_CYCLE=1)
    if(TOOIE_BASELINE_TERMINAL_FENCE)
        # Configure consumes the child hashes below; a build target is too late.
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_continuous.py"
            --runtime "${RUNTIME_ROOT}" --baseline-selected-runtime --output-directory "${CMAKE_BINARY_DIR}"
            RESULT_VARIABLE _baseline_prepare_result OUTPUT_VARIABLE _baseline_prepare_out ERROR_VARIABLE _baseline_prepare_err)
        if(NOT _baseline_prepare_result EQUAL 0)
            message(FATAL_ERROR "Selected baseline runtime preparation failed: ${_baseline_prepare_out}${_baseline_prepare_err}")
        endif()
        set(_baseline_runtime_provenance "${CMAKE_BINARY_DIR}/baseline/selected-runtime/manifest.json")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_continuous.py"
            "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_baseline_selected.py"
            "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_threadqueue.py"
            "${RUNTIME_ROOT}/.git/HEAD"
            "${CMAKE_SOURCE_DIR}/patches/runtime/events-q-vi-lock.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/timer-guest-clock.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/events-guest-clock.patch"
            "${CMAKE_SOURCE_DIR}/tools/owned_timer.py"
            "${CMAKE_SOURCE_DIR}/patches/runtime/events-next-framebuffer.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/events-dp-freeze.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/events-sp-exception.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/threads-suspended-stop.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/producer-quiescent-cleanup.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/threadqueue-removal.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/dp-freeze.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/dp-freeze.hpp"
            "${CMAKE_SOURCE_DIR}/patches/runtime/mesgqueue-required-admission.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/mesgqueue-lifecycle-wait.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/pi-save-persistence.patch"
            "${CMAKE_SOURCE_DIR}/patches/runtime/recomp-terminal-fence.patch")
        foreach(_component IN ITEMS events threads threadqueue mesgqueue timer)
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${RUNTIME_ROOT}/ultramodern/src/${_component}.cpp")
        endforeach()
        foreach(_component IN ITEMS dp recomp pi)
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${RUNTIME_ROOT}/librecomp/src/${_component}.cpp")
        endforeach()
    else()
        set(_baseline_runtime_provenance "${CMAKE_BINARY_DIR}/baseline/vi-off/before.json")
    endif()
    set(_baseline_events_original "${RUNTIME_ROOT}/ultramodern/src/events.cpp")
    set(_baseline_events_parent "${CMAKE_BINARY_DIR}/baseline/scheduler-event/events.cpp")
    set(_baseline_events_patch "${CMAKE_SOURCE_DIR}/patches/runtime/events-next-framebuffer.patch")
    set(_baseline_events_locked "${CMAKE_BINARY_DIR}/baseline/first-frame-sync/events.cpp")
    if(NOT EXISTS "${_baseline_events_locked}" OR NOT EXISTS "${_baseline_runtime_provenance}")
        message(FATAL_ERROR "VI input-prefix requires authenticated Q-VI-LOCK current-getter child")
    endif()
    file(SHA256 "${_baseline_events_original}" _baseline_events_original_sha)
    file(SHA256 "${_baseline_events_parent}" _baseline_events_parent_sha)
    file(SHA256 "${_baseline_events_patch}" _baseline_events_patch_sha)
    file(SHA256 "${_baseline_events_locked}" _baseline_events_locked_sha)
    if(NOT _baseline_events_original_sha STREQUAL "474621d28868daa3ea82ce137a043b560472dd45f4942d361f02935091d4aa6c" OR
        NOT _baseline_events_parent_sha STREQUAL "7ad9ad3def0f061125db69ed608078558141aecfa1ed715588b807fdcdf5dee2" OR
        NOT _baseline_events_patch_sha STREQUAL "6e17ed72a30d942af19ed4242c9e8a3f8f947bad9d709cc264498b1084b5ab27" OR
        NOT _baseline_events_locked_sha STREQUAL "aed57c028028a756d507a4c4adfb915171fac167cf543d40447c935e47d3bf88")
        message(FATAL_ERROR "Q-VI-LOCK original/materialized source hash differs")
    endif()
    set(_baseline_timer_original "${RUNTIME_ROOT}/ultramodern/src/timer.cpp")
    if(TOOIE_BASELINE_PLAYER)
        set(_baseline_timer_owned "${CMAKE_BINARY_DIR}/baseline/guest-clock/timer.cpp")
        file(SHA256 "${_baseline_timer_owned}" _baseline_guest_timer_sha)
        if(NOT _baseline_guest_timer_sha STREQUAL "910d020a22203cc6d0c91f2c7aed0c0856835ab8bed2c6dffd948e35483de37c")
            message(FATAL_ERROR "F6 guest-clock timer child differs")
        endif()
        target_sources(TooieBaseline PRIVATE src/virtual_clock.cpp)
    elseif(TOOIE_BASELINE_TERMINAL_FENCE)
        set(_baseline_timer_owned "${CMAKE_BINARY_DIR}/baseline/timer-periodic/timer.cpp")
        add_custom_command(OUTPUT "${_baseline_timer_owned}"
            BYPRODUCTS "${CMAKE_BINARY_DIR}/baseline/timer-periodic/manifest.json"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_continuous.py"
                --runtime "${RUNTIME_ROOT}" --baseline-timer
                --output-directory "${CMAKE_BINARY_DIR}/baseline/timer-periodic"
            DEPENDS "${_baseline_timer_original}" "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_continuous.py"
                "${CMAKE_SOURCE_DIR}/tools/owned_timer.py"
            VERBATIM)
        add_custom_target(BaselineOwnedTimerSource DEPENDS "${_baseline_timer_owned}")
        add_dependencies(ultramodern BaselineOwnedTimerSource)
    else()
        set(_baseline_timer_owned "${CMAKE_BINARY_DIR}/baseline/timer-owned/timer.cpp")
        if(NOT EXISTS "${_baseline_timer_owned}")
            message(FATAL_ERROR "Timer ownership arm requires its authenticated baseline-local one-shot child")
        endif()
        file(SHA256 "${_baseline_timer_original}" _baseline_timer_original_sha)
        file(SHA256 "${_baseline_timer_owned}" _baseline_timer_owned_sha)
        if(NOT _baseline_timer_original_sha STREQUAL "5919412bafcde237d911d1110059c39863b2a09baedba782d366d4804a32f72d" OR
            NOT _baseline_timer_owned_sha STREQUAL "a8fc30c2c2562c1ddd1bfc3172b83fac0263d8fe4590afee97f2e232990c0a66")
            message(FATAL_ERROR "Timer ownership original/materialized source hash differs")
        endif()
    endif()
    get_target_property(_baseline_runtime_sources ultramodern SOURCES)
    set(_baseline_timer_sources ${_baseline_runtime_sources})
    list(FILTER _baseline_timer_sources INCLUDE REGEX "/timer\\.cpp$")
    list(LENGTH _baseline_timer_sources _baseline_timer_count)
    if(NOT _baseline_timer_count EQUAL 1 OR NOT _baseline_timer_sources STREQUAL "${_baseline_timer_original}")
        message(FATAL_ERROR "Timer ownership requires exactly one original timer translation unit")
    endif()
    list(REMOVE_ITEM _baseline_runtime_sources "${_baseline_timer_original}")
    list(APPEND _baseline_runtime_sources "${_baseline_timer_owned}")
    set(_baseline_event_sources ${_baseline_runtime_sources})
    list(FILTER _baseline_event_sources INCLUDE REGEX "/events\\.cpp$")
    list(LENGTH _baseline_event_sources _baseline_event_count)
    if(NOT _baseline_event_count EQUAL 1 OR NOT _baseline_event_sources STREQUAL "${_baseline_events_original}")
        message(FATAL_ERROR "Q-VI-LOCK requires exactly one original events translation unit")
    endif()
    list(REMOVE_ITEM _baseline_runtime_sources "${_baseline_events_original}")
    set(_baseline_freeze "${CMAKE_BINARY_DIR}/baseline/dp-freeze")
    set(_baseline_freeze_include "${CMAKE_SOURCE_DIR}/patches/runtime")
    set(_baseline_dp_original "${RUNTIME_ROOT}/librecomp/src/dp.cpp")
    set(_freeze_inputs
        "${_baseline_dp_original}" "${_baseline_freeze_include}/dp-freeze.hpp"
        "${_baseline_freeze_include}/events-dp-freeze.patch" "${_baseline_freeze_include}/dp-freeze.patch"
        "${_baseline_freeze}/events.cpp" "${_baseline_freeze}/dp.cpp")
    set(_freeze_hashes
        21d8601c2207137b296d4211f8fd5d45ae2284d41913298d66916580c74d2094
        32cad60bc4a471733db1be985ebbe0eb6ac3c0f44a382cadf056e5f8dce31639
        7f287aec255a5dcb9eaa2ae53082403ff9a4eaa67c22b0f56d65e4f5d5864cdf
        4006e77ef9591ac7584e84ad348eb237b09799b56962b0ed70d45100d53cfa23
        96f362c7a774c4629a2e9523ecea748a1865bc9cb54de177207c486a6e7ccf4c
        ac866e51f0cb90c07ee330bfd7579ef4ead8c9c30bfc0cb285d09e515c3df4e4)
    foreach(_input _expected IN ZIP_LISTS _freeze_inputs _freeze_hashes)
        file(SHA256 "${_input}" _actual)
        if(NOT _actual STREQUAL _expected)
            message(FATAL_ERROR "DP Freeze source differs: ${_input}")
        endif()
    endforeach()
    set(_baseline_events_selected "${_baseline_freeze}/events.cpp")
    if(TOOIE_BASELINE_TERMINAL_FENCE)
        set(_baseline_events_selected "${CMAKE_BINARY_DIR}/baseline/lifecycle/events.cpp")
        file(SHA256 "${_baseline_events_selected}" _baseline_sp_events_sha)
        if(NOT _baseline_sp_events_sha STREQUAL "c680d7ba54a66010eabaad23dfa26d1c7dea35030ed0ae75cec4e5306470e9b0")
            message(FATAL_ERROR "SP terminal exception child differs")
        endif()
        if(TOOIE_BASELINE_PLAYER)
            set(_baseline_events_selected "${CMAKE_BINARY_DIR}/baseline/guest-clock/events.cpp")
            file(SHA256 "${_baseline_events_selected}" _baseline_guest_events_sha)
            if(NOT _baseline_guest_events_sha STREQUAL "720195ce6c8d2a77dc6c6b256e4ec10f0f6d744337d3dfe8fbb1221ce100298c")
                message(FATAL_ERROR "F6 guest-clock events child differs")
            endif()
        endif()
    endif()
    list(APPEND _baseline_runtime_sources "${_baseline_events_selected}")
    get_target_property(_baseline_librecomp_sources librecomp SOURCES)
    set(_baseline_dp_sources ${_baseline_librecomp_sources})
    list(FILTER _baseline_dp_sources INCLUDE REGEX "/dp\\.cpp$")
    list(LENGTH _baseline_dp_sources _baseline_dp_count)
    if(NOT _baseline_dp_count EQUAL 1 OR NOT _baseline_dp_sources STREQUAL "${_baseline_dp_original}")
        message(FATAL_ERROR "DP Freeze requires exactly one original dp translation unit")
    endif()
    list(REMOVE_ITEM _baseline_librecomp_sources "${_baseline_dp_original}")
    list(APPEND _baseline_librecomp_sources "${_baseline_freeze}/dp.cpp")
    set(_baseline_recomp_original "${RUNTIME_ROOT}/librecomp/src/recomp.cpp")
    set(_baseline_recomp_patch "${_baseline_freeze_include}/recomp-retain-rdram.patch")
    set(_baseline_recomp_child "${_baseline_freeze}/recomp.cpp")
    set(_recomp_inputs "${_baseline_recomp_original}" "${_baseline_recomp_patch}" "${_baseline_recomp_child}")
    set(_recomp_hashes
        af9c6f983fb1620ff5b971836d7792ef0b83a47e77010ab89ddf2fa1fb87e143
        0863fceaabfb7075b07f046f67bb1ec4d34bf3783acae4a9e3d329e5df86819f
        735ddf3d6983fb2ebfb3186814ae05e3768ac6dcdd37b193d47e509ff1c0a9ab)
    if(TOOIE_BASELINE_TERMINAL_FENCE)
        set(_baseline_recomp_patch "${_baseline_freeze_include}/recomp-terminal-fence.patch")
        set(_baseline_recomp_child "${CMAKE_BINARY_DIR}/baseline/lifecycle/recomp.cpp")
        set(_recomp_inputs "${_baseline_recomp_original}" "${_baseline_recomp_patch}" "${_baseline_recomp_child}")
        set(_recomp_hashes af9c6f983fb1620ff5b971836d7792ef0b83a47e77010ab89ddf2fa1fb87e143
            eb157ab9876972d73b610edc5280cfd6475930591d119b3eb3877429cd12aae2
            53f3f6480924483fcc3e19a7f90632abf2e6b3997bb6b85c6614ad66501bcc89)
    endif()
    foreach(_input _expected IN ZIP_LISTS _recomp_inputs _recomp_hashes)
        file(SHA256 "${_input}" _actual)
        if(NOT _actual STREQUAL _expected)
            message(FATAL_ERROR "Baseline terminal source differs: ${_input}")
        endif()
    endforeach()
    set(_baseline_recomp_sources ${_baseline_librecomp_sources})
    list(FILTER _baseline_recomp_sources INCLUDE REGEX "/recomp\\.cpp$")
    list(LENGTH _baseline_recomp_sources _baseline_recomp_count)
    if(NOT _baseline_recomp_count EQUAL 1 OR NOT _baseline_recomp_sources STREQUAL "${_baseline_recomp_original}")
        message(FATAL_ERROR "Baseline terminal requires exactly one original recomp translation unit")
    endif()
    list(REMOVE_ITEM _baseline_librecomp_sources "${_baseline_recomp_original}")
    list(APPEND _baseline_librecomp_sources "${_baseline_recomp_child}")
    if(TOOIE_BASELINE_SAVE_COMPOSITION)
        set(_baseline_pi_original "${RUNTIME_ROOT}/librecomp/src/pi.cpp")
        set(_baseline_pi_child "${CMAKE_BINARY_DIR}/runtime-continuous/pi.cpp")
        set(_baseline_pi_sources ${_baseline_librecomp_sources})
        list(FILTER _baseline_pi_sources INCLUDE REGEX "/pi\\.cpp$")
        list(LENGTH _baseline_pi_sources _baseline_pi_count)
        if(NOT _baseline_pi_count EQUAL 1 OR NOT _baseline_pi_sources STREQUAL "${_baseline_pi_original}")
            message(FATAL_ERROR "Saver composition requires exactly one original PI translation unit")
        endif()
        set(_save_inputs "${_baseline_pi_original}" "${_baseline_pi_child}"
            "${CMAKE_SOURCE_DIR}/src/runtime_save_root.cpp" "${CMAKE_SOURCE_DIR}/src/save_persistence.hpp")
        set(_save_hashes
            30189d04fe830f26ee69ec0f3aae8a4e37ffedc74cfee3294d5ac135038f90ca
            e44d154c455cbd1d4d9a1cf61dc9d4c2ca74274b1515f6c0f23e735ce7a868ba
            127b63dc087849530aa4c84c1979898d5e5cf681a0190f615a0ce8c22d2da20c
            5c17d907ed48a9c51c3921e1100626cea5fad0c8912ecc8cdb7a7ca4444553b3)
        foreach(_input _expected IN ZIP_LISTS _save_inputs _save_hashes)
            file(SHA256 "${_input}" _actual)
            if(NOT _actual STREQUAL _expected)
                message(FATAL_ERROR "Saver composition source differs: ${_input}")
            endif()
        endforeach()
        list(REMOVE_ITEM _baseline_librecomp_sources "${_baseline_pi_original}")
        list(APPEND _baseline_librecomp_sources "${_baseline_pi_child}")
        target_sources(TooieBaseline PRIVATE src/runtime_save_root.cpp)
        target_compile_definitions(TooieBaseline PRIVATE BASELINE_SAVE_COMPOSITION=1)
    endif()
if(TOOIE_BASELINE_SAVE_COMPOSITION)
    add_executable(BaselineSavePublicationTest EXCLUDE_FROM_ALL tools/baseline/save_publication_test.cpp src/runtime_save_root.cpp)
    target_include_directories(BaselineSavePublicationTest PRIVATE "${CMAKE_SOURCE_DIR}/src")
    foreach(_mode IN ITEMS main-absent malformed-main both-valid temporary-incomplete backup-refused promotion-refused)
        add_test(NAME baseline_save_publication_${_mode} COMMAND BaselineSavePublicationTest ${_mode}
            "${CMAKE_BINARY_DIR}/baseline/save-publication")
        set_tests_properties(baseline_save_publication_${_mode} PROPERTIES TIMEOUT 15)
    endforeach()
endif()
    set_property(TARGET librecomp PROPERTY SOURCES ${_baseline_librecomp_sources})
    foreach(_target IN ITEMS ultramodern librecomp TooieBaseline)
        target_include_directories(${_target} PRIVATE "${_baseline_freeze_include}")
    endforeach()
    add_executable(BaselineDPFreezeRegression EXCLUDE_FROM_ALL tools/baseline/dp_freeze_test.cpp "${_baseline_freeze}/dp.cpp")
    target_include_directories(BaselineDPFreezeRegression PRIVATE "${RUNTIME_RECOMP_INCLUDE}" "${_baseline_freeze_include}")
    target_link_libraries(BaselineDPFreezeRegression PRIVATE Threads::Threads)
    set(_baseline_thread_components threads threadqueue)
    if(TOOIE_BASELINE_TERMINAL_FENCE)
        list(APPEND _baseline_thread_components mesgqueue)
        file(SHA256 "${CMAKE_SOURCE_DIR}/src/runtime_lifecycle.cpp" _baseline_owner_sha)
        if(NOT _baseline_owner_sha STREQUAL "b757d64a2b1620fa3d5eef1b2d2a6594043cac6604f03236431375af533a7f69")
            message(FATAL_ERROR "Terminal guest fence existing owner differs")
        endif()
        target_sources(TooieBaseline PRIVATE src/runtime_lifecycle.cpp)
        target_compile_definitions(TooieBaseline PRIVATE BASELINE_TERMINAL_FENCE=1)
        foreach(_target IN ITEMS ultramodern librecomp)
            target_include_directories(${_target} PRIVATE "${CMAKE_SOURCE_DIR}/src")
        endforeach()
        if(MSVC OR _baseline_posix)
            if(TOOIE_BASELINE_RENDERER_CANDIDATE_OUTPUT)
                set(_baseline_map "${_baseline_executable_dir}/TooieBaseline.map")
            else()
                set(_baseline_map "${CMAKE_BINARY_DIR}/baseline/lifecycle/terminal-fence.map")
            endif()
            _baseline_link_map(TooieBaseline "${_baseline_map}")
        endif()
    endif()
    foreach(_component IN LISTS _baseline_thread_components)
        set(_original "${RUNTIME_ROOT}/ultramodern/src/${_component}.cpp")
        set(_child "${CMAKE_BINARY_DIR}/baseline/controller-cycle/${_component}.cpp")
        if(_component STREQUAL "threads")
            set(_pin_sha "e3ba32a1e06ba1643adc10ccc29ef5e3429e8809270f787a181314fc5704e653")
            set(_child "${CMAKE_BINARY_DIR}/baseline/thread-refusals/threads.cpp")
            set(_child_sha "64ddcfdd413bd1a893ab00bae1b7b2ad08f251af446687abd605fa0ae09dabde")
            if(TOOIE_BASELINE_TERMINAL_FENCE)
                set(_child "${CMAKE_BINARY_DIR}/baseline/lifecycle/threads.cpp")
                set(_child_sha "a1227291c933fa003706575e407ad8b0a469f04fe44125b7de03ad16faff8469")
            endif()
        elseif(_component STREQUAL "threadqueue")
            set(_pin_sha "b9bb55edeb9cb99a153d00d80a13c5a09140113403499af7656fd9489d38f305")
            set(_child_sha "67f48b19bc92f2cd8abba882b53209d5bbba1d297c0ad0c159108eb4faa8e621")
        else()
            set(_pin_sha "720db0e01ed2d874710b180292bd3ee9480c742a99bc574c4ce87e8f42949d21")
            set(_child "${CMAKE_BINARY_DIR}/baseline/lifecycle/mesgqueue.cpp")
            set(_child_sha "0889f02f33c2da072eebdccaccc81bcdeba09993eb7ea3e020200feaeabfcf8d")
        endif()
        file(SHA256 "${_original}" _actual_pin_sha)
        file(SHA256 "${_child}" _actual_child_sha)
        set(_matching ${_baseline_runtime_sources})
        list(FILTER _matching INCLUDE REGEX "/${_component}\\.cpp$")
        list(LENGTH _matching _count)
        if(NOT _actual_pin_sha STREQUAL _pin_sha OR NOT _actual_child_sha STREQUAL _child_sha OR
            NOT _count EQUAL 1 OR NOT _matching STREQUAL _original)
            message(FATAL_ERROR "Controller-cycle exact native source composition differs")
        endif()
        list(REMOVE_ITEM _baseline_runtime_sources "${_original}")
        list(APPEND _baseline_runtime_sources "${_child}")
    endforeach()
    set(_audio_artifacts generated/audio_mission01/tooie_audio_rsp_generated.cpp generated/audio_mission01/audio_identity.hpp)
    set(_audio_hashes 5e66e7433230412ee9a62e52d698a299b2dbc0ba55171c710c8e5ccb6564a777 03467322e5cbc5660cf3d0b87293623b476af2a5d8676dba4691e2dd1bdaba3b)
    foreach(_artifact _expected IN ZIP_LISTS _audio_artifacts _audio_hashes)
        file(SHA256 "${CMAKE_SOURCE_DIR}/${_artifact}" _actual)
        if(NOT _actual STREQUAL _expected)
            message(FATAL_ERROR "Existing audio artifact hash differs: ${_artifact}")
        endif()
    endforeach()
    target_sources(TooieBaseline PRIVATE src/tooie_audio_rsp.cpp src/platform_support.cpp generated/audio_mission01/tooie_audio_rsp_generated.cpp)
    target_include_directories(TooieBaseline PRIVATE generated/audio_mission01)
    if(MSVC AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64|X86)$")
        set_source_files_properties(generated/audio_mission01/tooie_audio_rsp_generated.cpp PROPERTIES COMPILE_OPTIONS "/clang:-msse4.1")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64|i.86)$")
        set_source_files_properties(generated/audio_mission01/tooie_audio_rsp_generated.cpp PROPERTIES COMPILE_OPTIONS "-msse4.1")
    endif()
    if(TOOIE_BASELINE_TERMINAL_FENCE)
        find_package(Threads REQUIRED)
        set(_mq_fixture "${CMAKE_BINARY_DIR}/baseline/lifecycle/mesgqueue-admission")
        add_custom_command(
            OUTPUT "${_mq_fixture}/mesgqueue_admission_struct.inl"
                "${_mq_fixture}/mesgqueue_admission_bodies.inl"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/prepare_mesgqueue_admission_fixture.py"
                "${CMAKE_BINARY_DIR}/baseline/lifecycle/mesgqueue.cpp" "${_mq_fixture}"
            DEPENDS "${CMAKE_SOURCE_DIR}/tests/prepare_mesgqueue_admission_fixture.py"
                "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_baseline_selected.py"
                "${CMAKE_SOURCE_DIR}/patches/runtime/mesgqueue-required-admission.patch"
                "${CMAKE_BINARY_DIR}/baseline/lifecycle/mesgqueue.cpp"
            VERBATIM)
        add_executable(BaselineMesgqueueAdmissionTest EXCLUDE_FROM_ALL
            tests/mesgqueue_admission_fixture.cpp
            "${RUNTIME_ROOT}/ultramodern/src/error_handling.cpp"
            "${_mq_fixture}/mesgqueue_admission_struct.inl"
            "${_mq_fixture}/mesgqueue_admission_bodies.inl")
        target_compile_features(BaselineMesgqueueAdmissionTest PRIVATE cxx_std_20)
        target_include_directories(BaselineMesgqueueAdmissionTest PRIVATE "${_mq_fixture}"
            $<TARGET_PROPERTY:ultramodern,INCLUDE_DIRECTORIES>)
        target_compile_definitions(BaselineMesgqueueAdmissionTest PRIVATE
            $<TARGET_PROPERTY:ultramodern,COMPILE_DEFINITIONS>)
        target_link_libraries(BaselineMesgqueueAdmissionTest PRIVATE Threads::Threads)
        add_test(NAME baseline_mesgqueue_required_admission
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/run_mesgqueue_admission_fixture.py"
                $<TARGET_FILE:BaselineMesgqueueAdmissionTest>)
        set_tests_properties(baseline_mesgqueue_required_admission PROPERTIES TIMEOUT 45)

        set(_sp_fixture "${CMAKE_BINARY_DIR}/baseline/lifecycle/sp-task-fixture")
        foreach(_mode IN ITEMS selected parent)
            set(_sp_pin "${_mode}")
            if(_mode STREQUAL "selected")
                set(_sp_source "${_baseline_events_selected}")
                # The player compiles the guest-clock child; bind its own pin.
                if(TOOIE_BASELINE_PLAYER)
                    set(_sp_pin player)
                endif()
            else()
                set(_sp_source "${_baseline_freeze}/events.cpp")
            endif()
            add_custom_command(OUTPUT "${_sp_fixture}/sp_task_${_mode}.inc"
                BYPRODUCTS "${_sp_fixture}/sp_task_${_mode}.json"
                COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/prepare_sp_task_fixture.py"
                    "${_sp_pin}" "${_sp_source}" "${_sp_fixture}/sp_task_${_mode}.inc"
                DEPENDS "${_sp_source}" "${CMAKE_SOURCE_DIR}/tests/prepare_sp_task_fixture.py"
                    "${CMAKE_SOURCE_DIR}/patches/runtime/events-sp-exception.patch"
                    "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_baseline_selected.py" VERBATIM)
        endforeach()
        add_executable(BaselineSPTaskTest EXCLUDE_FROM_ALL tests/baseline_sp_task_test.cpp "${_sp_fixture}/sp_task_selected.inc")
        add_executable(BaselineSPTaskParentTest EXCLUDE_FROM_ALL tests/baseline_sp_task_test.cpp "${_sp_fixture}/sp_task_parent.inc")
        target_compile_definitions(BaselineSPTaskParentTest PRIVATE SP_TASK_PARENT=1)
        foreach(_target IN ITEMS BaselineSPTaskTest BaselineSPTaskParentTest)
            target_include_directories(${_target} PRIVATE "${_sp_fixture}")
            target_compile_features(${_target} PRIVATE cxx_std_17)
            target_link_libraries(${_target} PRIVATE Threads::Threads)
        endforeach()
        foreach(_mode IN ITEMS success runtime-error bad-alloc unsupported)
            add_test(NAME baseline_sp_task_${_mode} COMMAND BaselineSPTaskTest "${_mode}")
            set_tests_properties(baseline_sp_task_${_mode} PROPERTIES TIMEOUT 10)
        endforeach()
        add_test(NAME baseline_sp_task_parent_negative COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/tests/prepare_sp_task_fixture.py" --check-negative "$<TARGET_FILE:BaselineSPTaskParentTest>")
        set_tests_properties(baseline_sp_task_parent_negative PROPERTIES TIMEOUT 10)
    endif()
    add_executable(BaselineThreadQueueRegression EXCLUDE_FROM_ALL tests/threadqueue_regression.cpp)
    target_link_libraries(BaselineThreadQueueRegression PRIVATE ultramodern)
    set_property(TARGET ultramodern PROPERTY SOURCES ${_baseline_runtime_sources})
    message(STATUS "Q-VI-LOCK: one materialized events.cpp; thread_create_callback=seed_thread_status; vi_callback=vi_complete; gfx_init_callback=nullptr; controller-cycle arm; selected copied timer ownership and suspended-stop/queue children; reached current getter synchronized")
endif()
if(TOOIE_BASELINE_CORE1_PUBLICATION)
    if(NOT TOOIE_BASELINE_BOOT_PATCH_DIR OR NOT TOOIE_BASELINE_BOOT_PI OR NOT TOOIE_BASELINE_BOOT_OBSERVER OR
        (NOT "tooie_core1_osInitialize" IN_LIST TOOIE_BASELINE_FATAL_PROVIDERS AND NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE))
        message(FATAL_ERROR "Core1 publication requires boot patch, boot PI, boot observer, and either the explicit tooie_core1_osInitialize provider or VI/controller-cycle selection")
    endif()
    file(REAL_PATH "${TOOIE_BASELINE_CORE1_REFERENCE}" _baseline_core1_reference)
    cmake_path(IS_PREFIX _baseline_build_root "${_baseline_core1_reference}" NORMALIZE _baseline_core1_in_build)
    file(SHA256 "${_baseline_core1_reference}" _baseline_core1_sha)
    if(NOT _baseline_core1_in_build OR NOT _baseline_core1_sha STREQUAL "965ccdb935542a113c1d58e12fccdb3ff326f3c02abebdda95cc7657403d7ad0")
        message(FATAL_ERROR "Core1 observation reference location/hash differs from the reviewed condition")
    endif()
    # Configure identity only: adapters.cpp checks this SHA-256 over guest-order memory; the bytes are never embedded.
    if(NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
        target_sources(TooieBaseline PRIVATE src/platform_support.cpp)  # The VI selection already links it.
    endif()
    target_include_directories(TooieBaseline PRIVATE "${CMAKE_SOURCE_DIR}/src")
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_CORE1_PUBLICATION=1)
    add_executable(BaselineGuestDigestTest EXCLUDE_FROM_ALL tests/baseline_guest_digest_test.cpp src/platform_support.cpp)
    target_include_directories(BaselineGuestDigestTest PRIVATE "${CMAKE_SOURCE_DIR}/tools/baseline" "${CMAKE_SOURCE_DIR}/src" "${RUNTIME_RECOMP_INCLUDE}")
    target_link_libraries(BaselineGuestDigestTest PRIVATE ${_baseline_crypto_library})
    set_target_properties(BaselineGuestDigestTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
endif()
if(TOOIE_BASELINE_BOOT_PI)
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_BOOT_PI=1)
endif()
if(TOOIE_BASELINE_BOOT_OBSERVER)
    if(NOT TOOIE_BASELINE_BOOT_PI OR NOT TOOIE_BASELINE_BOOT_PATCH_DIR)
        message(FATAL_ERROR "Boot observer requires the declared guest patch plus boot PI child")
    endif()
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_BOOT_OBSERVER=1)
endif()
if(TOOIE_BASELINE_BOOT_PATCH_DIR)
    if("boot_osInitialize" IN_LIST TOOIE_BASELINE_FATAL_PROVIDERS)
        message(FATAL_ERROR "Guest boot patch and fatal boot_osInitialize cannot both be selected")
    endif()
    get_filename_component(TOOIE_BASELINE_BOOT_PATCH_DIR "${TOOIE_BASELINE_BOOT_PATCH_DIR}" ABSOLUTE)
    cmake_path(IS_PREFIX _baseline_build_root "${TOOIE_BASELINE_BOOT_PATCH_DIR}" NORMALIZE _baseline_patch_in_build)
    if(NOT _baseline_patch_in_build)
        message(FATAL_ERROR "Boot patch must be in the existing build tree")
    endif()
    foreach(_input IN ITEMS boot.c boot.bin funcs.h recomp_overlays.inl receipt.json)
        if(NOT EXISTS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/${_input}")
            message(FATAL_ERROR "Missing prepared boot patch ${_input}")
        endif()
    endforeach()
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_core1_body REGEX "^RECOMP_FUNC void tooie_core1_osInitialize\\(")
    if((TOOIE_BASELINE_VI_CONTROLLER_CYCLE AND NOT _baseline_core1_body) OR (NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE AND _baseline_core1_body))
        message(FATAL_ERROR "Prepared core1 guest body must match the explicit initializer selection")
    endif()
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_heap_body REGEX "^RECOMP_FUNC void heap_realloc\\(")
    if((TOOIE_BASELINE_HEAP_PATCH AND NOT _baseline_heap_body) OR (NOT TOOIE_BASELINE_HEAP_PATCH AND _baseline_heap_body))
        message(FATAL_ERROR "Prepared heap body must match the explicit heap selection")
    endif()
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_honey_body REGEX "^RECOMP_FUNC void func_80800380_chhoneycarrier\\(")
    list(LENGTH _baseline_honey_body _baseline_honey_count)
    if(((TOOIE_BASELINE_HONEY_PATCH OR TOOIE_BASELINE_RENDER_BRIDGE) AND NOT _baseline_honey_count EQUAL 1) OR
        (NOT TOOIE_BASELINE_HONEY_PATCH AND NOT TOOIE_BASELINE_RENDER_BRIDGE AND NOT _baseline_honey_count EQUAL 0))
        message(FATAL_ERROR "Prepared Honey body must match the explicit guest selection")
    endif()
    if(TOOIE_BASELINE_HONEY_PATCH)
        file(READ "${TOOIE_BASELINE_BOOT_PATCH_DIR}/receipt.json" _baseline_honey_receipt)
        string(JSON _baseline_honey_condition GET "${_baseline_honey_receipt}" condition)
        string(JSON _baseline_honey_emit GET "${_baseline_honey_receipt}" honey_emit)
        if(NOT _baseline_honey_condition STREQUAL "BASELINE-BOOT-CORE1-M2-HONEY/code-only" OR
            NOT _baseline_honey_emit MATCHES "^[01]$" OR
            (TOOIE_BASELINE_HONEY_EMIT AND NOT _baseline_honey_emit EQUAL 1) OR
            (NOT TOOIE_BASELINE_HONEY_EMIT AND NOT _baseline_honey_emit EQUAL 0))
            message(FATAL_ERROR "Prepared Honey receipt/emission differs from selected mode")
        endif()
        foreach(_input IN ITEMS boot.c boot.bin funcs.h recomp_overlays.inl)
            string(JSON _expected GET "${_baseline_honey_receipt}" outputs "${_input}")
            file(SHA256 "${TOOIE_BASELINE_BOOT_PATCH_DIR}/${_input}" _actual)
            if(NOT _actual STREQUAL _expected)
                message(FATAL_ERROR "Prepared Honey receipt hash differs: ${_input}")
            endif()
        endforeach()
        find_package(Python3 REQUIRED COMPONENTS Interpreter)
        set(_baseline_honey_fixture "${CMAKE_BINARY_DIR}/baseline/honey-fixture/honey_draw_fixture.inc")
        add_custom_command(OUTPUT "${_baseline_honey_fixture}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_honey_fixture}" func_80800380_chhoneycarrier
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
        add_executable(BaselineHoneyDrawTest EXCLUDE_FROM_ALL tests/honey_draw_state_test.cpp "${_baseline_honey_fixture}")
        target_include_directories(BaselineHoneyDrawTest PRIVATE "${CMAKE_BINARY_DIR}/baseline/honey-fixture"
            "${RUNTIME_RECOMP_INCLUDE}" "${_baseline_rt64}/include")
        target_compile_definitions(BaselineHoneyDrawTest PRIVATE NOMINMAX)
        set_target_properties(BaselineHoneyDrawTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    endif()
    if(TOOIE_BASELINE_HEAP_PATCH)
        find_package(Python3 REQUIRED COMPONENTS Interpreter)
        set(_baseline_heap_fixture "${CMAKE_BINARY_DIR}/baseline/heap-fixture/heap_realloc_fixture.inc")
        add_custom_command(OUTPUT "${_baseline_heap_fixture}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_heap_fixture}"
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
        add_executable(BaselineHeapReallocTest EXCLUDE_FROM_ALL tests/heap_realloc_state_test.cpp "${_baseline_heap_fixture}")
        target_include_directories(BaselineHeapReallocTest PRIVATE "${CMAKE_BINARY_DIR}/baseline/heap-fixture" "${RUNTIME_RECOMP_INCLUDE}")
        target_compile_definitions(BaselineHeapReallocTest PRIVATE NOMINMAX)
        set_target_properties(BaselineHeapReallocTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    endif()
    add_library(BaselineBootPatch STATIC "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c")
    target_include_directories(BaselineBootPatch PRIVATE "${RUNTIME_RECOMP_INCLUDE}" "${TOOIE_BASELINE_GENERATED_DIR}")
    # minimum_host_imports.h declares the absolute native imports used by HOST and NPC665.
    if(TOOIE_BASELINE_HOST OR TOOIE_BASELINE_NPC665)
        target_include_directories(BaselineBootPatch PRIVATE "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host")
    endif()
    target_compile_options(BaselineBootPatch PRIVATE -fno-strict-aliasing)
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        target_compile_definitions(BaselineBootPatch PRIVATE osVirtualToPhysical=osVirtualToPhysical_recomp)
    endif()
    if(TOOIE_BASELINE_CAMERA_IDENTITY)
        # Guest cache leaf uses its original name; the ordinary runtime ABI has the standard suffix.
        target_compile_definitions(BaselineBootPatch PRIVATE osWritebackDCache=osWritebackDCache_recomp)
    endif()
    if(MSVC)
        target_compile_options(BaselineBootPatch PRIVATE "/FI${TOOIE_BASELINE_GENERATED_DIR}/funcs.h")
    else()
        target_compile_options(BaselineBootPatch PRIVATE -include "${TOOIE_BASELINE_GENERATED_DIR}/funcs.h")
    endif()
    add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.c" "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.h"
        COMMAND $<TARGET_FILE:file_to_c> "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.bin" baseline_boot_patch_bin
            "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.c" "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.h"
        DEPENDS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.bin" file_to_c VERBATIM)
    target_sources(TooieBaseline PRIVATE "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.c" "${CMAKE_BINARY_DIR}/baseline/baseline_boot_patch_bin.h")
    target_include_directories(TooieBaseline PRIVATE "${CMAKE_BINARY_DIR}/baseline")
    target_compile_definitions(TooieBaseline PRIVATE BASELINE_BOOT_PATCH=1
        "BASELINE_BOOT_PATCH_REGISTRY=\"${TOOIE_BASELINE_BOOT_PATCH_DIR}/recomp_overlays.inl\"")
    target_link_libraries(TooieBaseline PRIVATE BaselineBootPatch)
endif()
if(TARGET BaselineBootPatch)
    target_compile_definitions(BaselineBootPatch PRIVATE "TOOIE_BASELINE_HOST=$<BOOL:${TOOIE_BASELINE_HOST}>")
endif()
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_RENDER_BRIDGE=$<BOOL:${TOOIE_BASELINE_RENDER_BRIDGE}>")
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_RENDER_OBSERVER=$<BOOL:${TOOIE_BASELINE_RENDER_OBSERVER}>")
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_RENDER_SILO=$<BOOL:${TOOIE_BASELINE_SILO_CANDIDATE}>")
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_SILO_ACQUISITION_OBSERVER=$<BOOL:${TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER}>")
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_CAMERA_IDENTITY=$<BOOL:${TOOIE_BASELINE_CAMERA_IDENTITY}>" "BASELINE_SILO_FAMILY_OBSERVER=$<BOOL:${TOOIE_BASELINE_SILO_FAMILY_OBSERVER}>")
target_compile_definitions(rt64 PRIVATE "BASELINE_SILO_FAMILY_OBSERVER=$<BOOL:${TOOIE_BASELINE_SILO_FAMILY_OBSERVER}>")
target_include_directories(rt64 PRIVATE "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate")
target_compile_definitions(rt64 PRIVATE "BASELINE_PLAYER_BOUNDARY=$<BOOL:${TOOIE_BASELINE_PLAYER_BOUNDARY}>")
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_PLAYER_BOUNDARY=$<BOOL:${TOOIE_BASELINE_PLAYER_BOUNDARY}>")
target_compile_definitions(BaselineRecompiledFuncs PRIVATE "BASELINE_CAMERA_IDENTITY=$<BOOL:${TOOIE_BASELINE_CAMERA_IDENTITY}>")
target_compile_definitions(BaselineRecompiledFuncs PRIVATE "BASELINE_RENDER_BRIDGE=$<BOOL:${TOOIE_BASELINE_RENDER_BRIDGE}>")
set(_baseline_quiet_trot OFF)
set(_baseline_trot_toggle OFF)
set(_baseline_flap_flip OFF)
set(_baseline_first_person_aim OFF)
if(TOOIE_BASELINE_RENDER_BRIDGE)
    # Raw funcs.h must precede the image's eight-body funcs.h.
    target_include_directories(TooieBaseline PRIVATE "${TOOIE_BASELINE_GENERATED_DIR}" "${_baseline_bridge_dir}")
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_birth_body REGEX "^RECOMP_FUNC void func_800EBED4\\(")
    list(LENGTH _baseline_birth_body _baseline_birth_count)
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_bone_body REGEX "^RECOMP_FUNC void func_800DCF48\\(")
    list(LENGTH _baseline_bone_body _baseline_bone_count)
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_owner_body REGEX "^RECOMP_FUNC void func_80101808\\(")
    file(STRINGS "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" _baseline_draw_body REGEX "^RECOMP_FUNC void func_800DE448\\(")
    list(LENGTH _baseline_owner_body _baseline_owner_count)
    list(LENGTH _baseline_draw_body _baseline_draw_count)
    file(READ "${_baseline_bridge_dir}/receipt.json" _baseline_selected_receipt)
    string(JSON _baseline_selected_state GET "${_baseline_selected_receipt}" state_bytes)
    string(JSON _baseline_selected_count LENGTH "${_baseline_selected_receipt}" definitions)
    file(STRINGS "${_baseline_bridge_dir}/boot.c" _baseline_all_bodies REGEX "^RECOMP_FUNC void ")
    list(LENGTH _baseline_all_bodies _baseline_actual_body_count)
    if(TOOIE_BASELINE_CAMERA_IDENTITY)
        string(JSON _baseline_actor_enabled GET "${_baseline_selected_receipt}" actor_palette_enabled)
        string(JSON _baseline_helper_count LENGTH "${_baseline_selected_receipt}" helper_definitions)
        string(JSON _baseline_demo_type ERROR_VARIABLE _baseline_demo_error TYPE "${_baseline_selected_receipt}" demo_timing)
        set(_baseline_provider_expected 50)
        set(_baseline_helper_expected 12)
        if(_baseline_demo_type STREQUAL "OBJECT")
            set(_baseline_provider_expected 53)
            set(_baseline_helper_expected 15)
        endif()
        string(JSON _baseline_shadow_type ERROR_VARIABLE _baseline_shadow_error TYPE "${_baseline_selected_receipt}" shadow_projection)
        if(_baseline_shadow_type STREQUAL "OBJECT")
            if(NOT _baseline_demo_type STREQUAL "OBJECT")
                message(FATAL_ERROR "Shadow composition requires accepted demo")
            endif()
            set(_baseline_provider_expected 61)
            set(_baseline_helper_expected 23)
        endif()
        string(JSON _baseline_pre_type ERROR_VARIABLE _baseline_pre_error TYPE "${_baseline_selected_receipt}" pre_background)
        string(JSON _baseline_cpu_type ERROR_VARIABLE _baseline_cpu_error TYPE "${_baseline_selected_receipt}" cpu625)
        string(JSON _baseline_host_type ERROR_VARIABLE _baseline_host_error TYPE "${_baseline_selected_receipt}" minimum_host)
        string(JSON _baseline_music_type ERROR_VARIABLE _baseline_music_error TYPE "${_baseline_selected_receipt}" music_gain)
        if(TOOIE_BASELINE_HOST)
            if(NOT _baseline_host_type STREQUAL "OBJECT" OR NOT _baseline_actor_enabled OR NOT _baseline_pre_type STREQUAL "OBJECT")
                message(FATAL_ERROR "Minimum host requires its exact guest object and actor/PRE carrier")
            endif()
            if(NOT _baseline_music_type STREQUAL "OBJECT")
                message(FATAL_ERROR "HOST requires the distinct music guest composition")
            endif()
            string(JSON _baseline_music_state GET "${_baseline_selected_receipt}" music_gain state_bytes)
            string(JSON _baseline_music_bodies LENGTH "${_baseline_selected_receipt}" music_gain bodies)
            string(JSON _baseline_music_lower GET "${_baseline_selected_receipt}" music_gain bodies 0)
            string(JSON _baseline_music_update GET "${_baseline_selected_receipt}" music_gain bodies 1)
            string(JSON _baseline_music_object TYPE "${_baseline_selected_receipt}" objects music_gain)
            if(NOT _baseline_music_state EQUAL 20 OR NOT _baseline_music_bodies EQUAL 2 OR
               NOT _baseline_music_lower STREQUAL "func_80025ED0" OR NOT _baseline_music_update STREQUAL "func_800123BC" OR
               NOT _baseline_music_object STREQUAL "OBJECT")
                message(FATAL_ERROR "Music requires two named replacements, its object proof and20-byte request cache")
            endif()
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_minimum_host.py"
                "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_camera_bridge.py"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate/render_bridge.ld"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/music_gain.c"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/minimum_host_imports.h"
                "${CMAKE_SOURCE_DIR}/deps/banjo-tooie/build/us/banjotooie_decompressed.elf"
                "${_baseline_bridge_dir}/minimum_host_selection_layout.h")
            math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+7")
            math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+4")
        elseif(_baseline_host_type STREQUAL "OBJECT" OR _baseline_music_type STREQUAL "OBJECT")
            message(FATAL_ERROR "HOST guest image is ON while native selection is OFF")
        endif()
        string(JSON _baseline_npc_type ERROR_VARIABLE _baseline_npc_error TYPE "${_baseline_selected_receipt}" npc665)
        if(TOOIE_BASELINE_NPC665)
            if(NOT _baseline_npc_type STREQUAL "OBJECT" OR NOT _baseline_actor_enabled OR NOT _baseline_pre_type STREQUAL "OBJECT")
                message(FATAL_ERROR "NPC665 requires its exact guest object and actor/PRE carrier")
            endif()
            math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+8")
            math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+8")
        elseif(_baseline_npc_type STREQUAL "OBJECT")
            message(FATAL_ERROR "NPC665 guest image is ON while native selection is OFF")
        endif()
        string(JSON _baseline_b621_type ERROR_VARIABLE _baseline_b621_error TYPE "${_baseline_selected_receipt}" backpack621)
        if(TOOIE_BASELINE_BACKPACK621)
            if(NOT _baseline_b621_type STREQUAL "OBJECT" OR NOT _baseline_cpu_type STREQUAL "OBJECT" OR
               NOT _baseline_actor_enabled OR NOT _baseline_pre_type STREQUAL "OBJECT")
                message(FATAL_ERROR "Backpack621 requires exact612-state/eight-helper guest and CPU/actor/PRE carrier")
            endif()
            math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+9")
            math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+8")
            string(JSON _baseline_rate_state GET "${_baseline_selected_receipt}" graphics_rate state_bytes)
            if(NOT _baseline_rate_state EQUAL 48)
                message(FATAL_ERROR "Selected player requires exact two public-rate tails")
            endif()
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_graphics_rate.py"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate/graphics_rate.c"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate/demo_timing.h"
                "${_baseline_bridge_dir}/backpack621_selection_layout.h"
                "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_backpack621.py"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/backpack621-candidate/backpack621_owner.c"
                "${CMAKE_SOURCE_DIR}/tools/baseline/guest/backpack621-candidate/backpack621_owner.h")
        elseif(_baseline_b621_type STREQUAL "OBJECT")
            message(FATAL_ERROR "Backpack621 guest ON while native selection OFF")
        endif()
        if(TOOIE_BASELINE_CPU625)
            if(NOT _baseline_cpu_type STREQUAL "OBJECT" OR NOT _baseline_actor_enabled OR NOT _baseline_pre_type STREQUAL "OBJECT")
                message(FATAL_ERROR "CPU625 selection requires its exact guest object and accepted actor/PRE carrier")
            endif()
            math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+4")
            math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+4")
        elseif(_baseline_cpu_type STREQUAL "OBJECT")
            message(FATAL_ERROR "CPU625 guest image is ON while native selection is OFF")
        endif()
        if(_baseline_pre_type STREQUAL "OBJECT")
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_baseline_bridge_dir}/RAW_BINDING.json" "${_baseline_bridge_dir}/receipt.json")
            file(READ "${_baseline_bridge_dir}/RAW_BINDING.json" _baseline_raw_binding)
            string(JSON _baseline_raw_pre_type TYPE "${_baseline_raw_binding}" pre_background)
            string(JSON _baseline_raw_pre GET "${_baseline_raw_binding}" pre_background)
            string(JSON _baseline_expected_raw_sha GET "${_baseline_selected_receipt}" outputs "RAW_BINDING.json")
            file(SHA256 "${_baseline_bridge_dir}/RAW_BINDING.json" _baseline_actual_raw_sha)
            if(NOT _baseline_raw_pre_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_pre OR NOT _baseline_actual_raw_sha STREQUAL _baseline_expected_raw_sha)
                message(FATAL_ERROR "PRE raw selection or exact receipt RAW_BINDING hash mismatch")
            endif()
            if(NOT _baseline_demo_type STREQUAL "OBJECT" OR NOT _baseline_shadow_type STREQUAL "OBJECT")
                message(FATAL_ERROR "PRE composition requires accepted demo and shadow")
            endif()
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate/camera_actor_admission.h" "${_baseline_bridge_dir}/boot.bin")
            file(SHA256 "${_baseline_bridge_dir}/boot.bin" _baseline_image_sha)
            # Player-accepted shadow coefficient policy; qualified only on the 621 composition.
            string(JSON _baseline_shadow_coefficients ERROR_VARIABLE _baseline_shadow_coefficients_error GET "${_baseline_selected_receipt}" shadow_coefficients)
            set(_baseline_quiet_native OFF)
            if(TOOIE_BASELINE_HOST AND TOOIE_BASELINE_BACKPACK621 AND _baseline_shadow_coefficients STREQUAL "ON")
                set(_baseline_quiet_native ON)
            endif()
            string(JSON _baseline_quiet_type ERROR_VARIABLE _baseline_quiet_error TYPE "${_baseline_selected_receipt}" quiet_talon_trot)
            string(JSON _baseline_raw_quiet_type ERROR_VARIABLE _baseline_raw_quiet_error TYPE "${_baseline_raw_binding}" quiet_talon_trot)
            if(_baseline_quiet_error AND _baseline_raw_quiet_error AND NOT _baseline_quiet_native)
                # Both valid legacy objects lack the field: historical OFF only.
                set(_baseline_quiet_trot OFF)
            elseif(NOT _baseline_quiet_error AND NOT _baseline_raw_quiet_error AND
                   _baseline_quiet_type STREQUAL "BOOLEAN" AND _baseline_raw_quiet_type STREQUAL "BOOLEAN")
                string(JSON _baseline_quiet_trot GET "${_baseline_selected_receipt}" quiet_talon_trot)
                string(JSON _baseline_raw_quiet GET "${_baseline_raw_binding}" quiet_talon_trot)
                if(NOT _baseline_quiet_trot STREQUAL _baseline_quiet_native OR
                   NOT _baseline_raw_quiet STREQUAL _baseline_quiet_trot)
                    message(FATAL_ERROR "Quiet Trot raw/image/native selection mismatch")
                endif()
            else()
                message(FATAL_ERROR "Quiet Trot fields missing/partial/malformed; ON requires HOST and621 coefficient composition")
            endif()
            if(_baseline_quiet_trot)
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+1")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_quiet_talon_trot.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/quiet_talon_trot.c")
            endif()
            # Trot uses exactly the same selected-image predicate as Quiet Trot.
            string(JSON _baseline_trot_type ERROR_VARIABLE _baseline_trot_error TYPE "${_baseline_selected_receipt}" talon_trot_toggle)
            string(JSON _baseline_raw_trot_type ERROR_VARIABLE _baseline_raw_trot_error TYPE "${_baseline_raw_binding}" talon_trot_toggle)
            if(_baseline_trot_error AND _baseline_raw_trot_error AND NOT _baseline_quiet_native)
                set(_baseline_trot_toggle OFF)
            elseif(NOT _baseline_trot_error AND NOT _baseline_raw_trot_error AND
                   _baseline_trot_type STREQUAL "BOOLEAN" AND _baseline_raw_trot_type STREQUAL "BOOLEAN")
                string(JSON _baseline_trot_toggle GET "${_baseline_selected_receipt}" talon_trot_toggle)
                string(JSON _baseline_raw_trot GET "${_baseline_raw_binding}" talon_trot_toggle)
                if(NOT _baseline_trot_toggle STREQUAL _baseline_quiet_native OR
                   NOT _baseline_raw_trot STREQUAL _baseline_trot_toggle)
                    message(FATAL_ERROR "Trot raw/image/native selection mismatch")
                endif()
            else()
                message(FATAL_ERROR "Trot fields missing/partial/malformed; selected HOST/621 coefficient image requires explicit ON")
            endif()
            if(_baseline_trot_toggle)
                # This gate counts ALL translated functions: 4 providers + 2 helpers.
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+4+2")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+2")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_talon_trot_toggle.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/talon_trot_toggle.c"
                    "${_baseline_bridge_dir}/trot_toggle_selection_layout.h")
            endif()
            string(JSON _baseline_fps_type ERROR_VARIABLE _baseline_fps_error TYPE "${_baseline_selected_receipt}" first_person_aim)
            string(JSON _baseline_raw_fps_type ERROR_VARIABLE _baseline_raw_fps_error TYPE "${_baseline_raw_binding}" first_person_aim)
            if(_baseline_fps_error AND _baseline_raw_fps_error)
                set(_baseline_first_person_aim OFF)
            elseif(NOT _baseline_fps_error AND NOT _baseline_raw_fps_error AND
                   _baseline_fps_type STREQUAL "BOOLEAN" AND _baseline_raw_fps_type STREQUAL "BOOLEAN")
                string(JSON _baseline_first_person_aim GET "${_baseline_selected_receipt}" first_person_aim)
                string(JSON _baseline_raw_fps GET "${_baseline_raw_binding}" first_person_aim)
                if(NOT _baseline_raw_fps STREQUAL _baseline_first_person_aim OR
                   (_baseline_first_person_aim AND NOT _baseline_trot_toggle))
                    message(FATAL_ERROR "FPS raw/image/native component selection mismatch")
                endif()
            else()
                message(FATAL_ERROR "FPS raw/image selection fields partial/malformed")
            endif()
            if(_baseline_first_person_aim)
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+5+1")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+1")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_modern_fps.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/modern_fps_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/modern_fps_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/modern_fps.c"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/first_person_aim_abi.h")
            endif()
            string(JSON _baseline_flip_type ERROR_VARIABLE _baseline_flip_error TYPE "${_baseline_selected_receipt}" flap_flip_landing)
            string(JSON _baseline_raw_flip_type ERROR_VARIABLE _baseline_raw_flip_error TYPE "${_baseline_raw_binding}" flap_flip_landing)
            if(_baseline_flip_error AND _baseline_raw_flip_error AND NOT TOOIE_BASELINE_PLAYER)
                set(_baseline_flap_flip OFF)
            elseif(_baseline_flip_type STREQUAL "BOOLEAN" AND _baseline_raw_flip_type STREQUAL "BOOLEAN")
                string(JSON _baseline_flap_flip GET "${_baseline_selected_receipt}" flap_flip_landing)
                string(JSON _baseline_raw_flip GET "${_baseline_raw_binding}" flap_flip_landing)
                if(NOT _baseline_flap_flip STREQUAL _baseline_raw_flip OR (TOOIE_BASELINE_PLAYER AND NOT _baseline_flap_flip))
                    message(FATAL_ERROR "Flap Flip raw/image/player selection mismatch")
                endif()
            else()
                message(FATAL_ERROR "Flap Flip selection missing or malformed")
            endif()
            if(_baseline_flap_flip)
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+1")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_flap_flip.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host/flap_flip_landing.c"
                    "${_baseline_bridge_dir}/flap_flip_selection_layout.h")
            endif()
            # BK pipeline image selection, read first: in the current player composition it retires P04b.
            string(JSON _baseline_bk_type ERROR_VARIABLE _baseline_bk_error TYPE "${_baseline_selected_receipt}" bk_pipeline)
            set(_baseline_bk_receipt OFF)
            if(NOT _baseline_bk_error AND _baseline_bk_type STREQUAL "OBJECT")
                set(_baseline_bk_receipt ON)
            endif()
            # P04b ckpack copy storage: derived from CPU625 + Flap Flip (prepare_camera_bridge.prepare).
            # The image object and raw boolean must agree with that derivation; 4 providers, 4 helpers.
            string(JSON _baseline_ckcopy_type ERROR_VARIABLE _baseline_ckcopy_error TYPE "${_baseline_selected_receipt}" ckpack_copy_storage)
            string(JSON _baseline_raw_ckcopy_type ERROR_VARIABLE _baseline_raw_ckcopy_error TYPE "${_baseline_raw_binding}" ckpack_copy_storage)
            if(TOOIE_BASELINE_CPU625 AND _baseline_flap_flip AND NOT _baseline_bk_receipt)
                if(_baseline_ckcopy_error OR _baseline_raw_ckcopy_error OR
                   NOT _baseline_ckcopy_type STREQUAL "OBJECT" OR NOT _baseline_raw_ckcopy_type STREQUAL "BOOLEAN")
                    message(FATAL_ERROR "ckpack copy storage: CPU625+Flap Flip selection requires its exact image object and raw boolean")
                endif()
                string(JSON _baseline_raw_ckcopy GET "${_baseline_raw_binding}" ckpack_copy_storage)
                if(NOT _baseline_raw_ckcopy)
                    message(FATAL_ERROR "ckpack copy storage raw/image/native selection mismatch")
                endif()
                # 4 ckcopy helpers + the 2 N3 shadow-attachment helpers in the CPU625 section.
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+6")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+6")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_ckcopy.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/ckcopy_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/ckcopy_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/cpu625-candidate/ckcopy.c"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/cpu625-candidate/ckcopy_layout.h"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/cpu625-candidate/ckpack_rows.h"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate/shadow_state.h"
                    "${_baseline_bridge_dir}/ckcopy_selection_layout.h")
            else()
                if(NOT _baseline_ckcopy_error AND NOT _baseline_ckcopy_type STREQUAL "NULL")
                    message(FATAL_ERROR "ckpack copy storage image object present without the CPU625+Flap Flip selection")
                endif()
                if(NOT _baseline_raw_ckcopy_error)
                    string(JSON _baseline_raw_ckcopy GET "${_baseline_raw_binding}" ckpack_copy_storage)
                    if(NOT _baseline_raw_ckcopy_type STREQUAL "BOOLEAN" OR _baseline_raw_ckcopy)
                        message(FATAL_ERROR "ckpack copy storage raw ON or malformed without the CPU625+Flap Flip selection")
                    endif()
                endif()
            endif()
            # PC[8] secondary route (implementation-s2): derived from CPU625 + Flap Flip like ckpack.
            # Image and raw selection booleans must agree with that derivation; admission is its own
            # image boolean (S-A false). 5 providers and 5 helpers in the player helper section.
            string(JSON _baseline_secondary_type ERROR_VARIABLE _baseline_secondary_error TYPE "${_baseline_selected_receipt}" player_secondary)
            string(JSON _baseline_raw_secondary_type ERROR_VARIABLE _baseline_raw_secondary_error TYPE "${_baseline_raw_binding}" player_secondary)
            string(JSON _baseline_secondary_admit_type ERROR_VARIABLE _baseline_secondary_admit_error TYPE "${_baseline_selected_receipt}" player_secondary_admit)
            if(_baseline_secondary_error OR _baseline_raw_secondary_error OR _baseline_secondary_admit_error OR
               NOT _baseline_secondary_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_secondary_type STREQUAL "BOOLEAN" OR
               NOT _baseline_secondary_admit_type STREQUAL "BOOLEAN")
                message(FATAL_ERROR "secondary route: explicit image, raw and admission booleans required")
            endif()
            string(JSON _baseline_secondary GET "${_baseline_selected_receipt}" player_secondary)
            string(JSON _baseline_raw_secondary GET "${_baseline_raw_binding}" player_secondary)
            string(JSON _baseline_secondary_admit GET "${_baseline_selected_receipt}" player_secondary_admit)
            if(TOOIE_BASELINE_CPU625 AND _baseline_flap_flip)
                if(NOT _baseline_secondary OR NOT _baseline_raw_secondary)
                    message(FATAL_ERROR "secondary route raw/image/native selection mismatch")
                endif()
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+5")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+5")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/secondary_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/secondary_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/player_secondary.c"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/player_secondary.h"
                    "${_baseline_bridge_dir}/secondary_selection_layout.h")
            elseif(_baseline_secondary OR _baseline_raw_secondary OR _baseline_secondary_admit)
                message(FATAL_ERROR "secondary route ON without the CPU625+Flap Flip selection")
            endif()
            # BK pipeline packet1: derived from CPU625 + Flap Flip like the secondary route.
            # Image object and raw boolean must agree; 9 providers and 9 helpers in section2.
            string(JSON _baseline_bk_type ERROR_VARIABLE _baseline_bk_error TYPE "${_baseline_selected_receipt}" bk_pipeline)
            string(JSON _baseline_raw_bk_type ERROR_VARIABLE _baseline_raw_bk_error TYPE "${_baseline_raw_binding}" bk_pipeline)
            set(_baseline_bk_pipeline OFF)
            if(TOOIE_BASELINE_CPU625 AND _baseline_flap_flip AND _baseline_bk_receipt)
                if(_baseline_bk_error OR _baseline_raw_bk_error OR
                   NOT _baseline_bk_type STREQUAL "OBJECT" OR NOT _baseline_raw_bk_type STREQUAL "BOOLEAN")
                    message(FATAL_ERROR "BK pipeline: CPU625+Flap Flip selection requires its image object and raw boolean")
                endif()
                string(JSON _baseline_raw_bk GET "${_baseline_raw_binding}" bk_pipeline)
                if(NOT _baseline_raw_bk)
                    message(FATAL_ERROR "BK pipeline raw/image/native selection mismatch")
                endif()
                set(_baseline_bk_pipeline ON)
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+29")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+29")
                set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_pipeline_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_pipeline_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_graph_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_graph_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_sort_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_sort_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_attach_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_attach_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_attach.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_menu_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_menu_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/menu_scope.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_shadow_attach_hooks.py"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/bk_shadow_attach_thunks.hpp"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_shadow_attach.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_float.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_graph.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_cut.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_sort.inc"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_pipeline.c"
                    "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/bk_pipeline.h"
                    "${_baseline_bridge_dir}/bk_pipeline_selection_layout.h")
            else()
                # Previous composition (BK OFF, P04b kept) or a composition without the player route.
                if(_baseline_bk_receipt)
                    message(FATAL_ERROR "BK pipeline image object without the CPU625+Flap Flip selection")
                endif()
                if(NOT _baseline_raw_bk_error)
                    string(JSON _baseline_raw_bk GET "${_baseline_raw_binding}" bk_pipeline)
                    if(NOT _baseline_raw_bk_type STREQUAL "BOOLEAN" OR _baseline_raw_bk)
                        message(FATAL_ERROR "BK pipeline raw ON or malformed while the image selection is OFF")
                    endif()
                endif()
            endif()
            if(_baseline_shadow_coefficients STREQUAL "ON" AND NOT TOOIE_BASELINE_BACKPACK621)
                message(FATAL_ERROR "Shadow coefficient guest image requires the 621 composition")
            endif()
            if(_baseline_shadow_coefficients STREQUAL "ON" AND NOT _baseline_bk_pipeline)
                # tooie_shadow_mv_end: the coefficient route's silhouette MODELVIEW close helper.
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+1")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+1")
            endif()
            if(_baseline_bk_pipeline AND _baseline_shadow_type STREQUAL "OBJECT")
                # BK shadow: tooie_shadow_source and tooie_shadow_prepare retire (six helpers remain).
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}-2")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}-2")
            endif()
            if(TOOIE_BASELINE_BACKPACK621)
                # Installed only after actual fullgraph/control/source/ELF acceptance.
                set(_baseline_expected_image "e34920d5b259d17cfcf67e86b3f4f130462c3c11a5aaddf24afdd982e8977eb8")
                if(_baseline_shadow_coefficients STREQUAL "ON")
                    # Same composition; shadow_projection.o (TOOIE_SHADOW_COEFFICIENTS=1) and actor.o (TOOIE_HAND862=1) differ.
                    set(_baseline_expected_image "d4edc0fc90a7121906a969a87e0b0b239523a803b46a76ab60a78ec92c844525")
                    if(_baseline_quiet_trot)
                        set(_baseline_expected_image "3ab2614823ac33e1d6f271aeb0ba6a34f8457efcbf5b75da6d2c4b952f7c7e7e")
                        if(_baseline_trot_toggle)
                            set(_baseline_expected_image "2fb1ebec41abebdcdb3b3b6168e3940048c4fc090533c2b0a8ac47f8c7af79ce")
                        endif()
                    endif()
                endif()
                string(JSON _baseline_raw_b621_type TYPE "${_baseline_raw_binding}" backpack621)
                string(JSON _baseline_raw_b621 GET "${_baseline_raw_binding}" backpack621)
                string(JSON _baseline_raw_cpu_type TYPE "${_baseline_raw_binding}" cpu625)
                string(JSON _baseline_raw_cpu GET "${_baseline_raw_binding}" cpu625)
                if(NOT _baseline_raw_b621_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_b621 OR
                   NOT _baseline_raw_cpu_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_cpu)
                    message(FATAL_ERROR "Backpack621/CPU625 raw selection not explicit ON")
                endif()
            elseif(TOOIE_BASELINE_NPC665)
                # Unusable until final actual composed source/results/byte acceptance.
                set(_baseline_expected_image "8a0b86b7b8f6a1ef8672d1c1d6a0b3698a50c0faff347e19f3a54104dd4fcbbb")
                string(JSON _baseline_raw_npc_type TYPE "${_baseline_raw_binding}" npc665)
                string(JSON _baseline_raw_npc GET "${_baseline_raw_binding}" npc665)
                if(NOT _baseline_raw_npc_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_npc)
                    message(FATAL_ERROR "NPC665 raw selection is not explicit ON")
                endif()
                if(TOOIE_BASELINE_CPU625)
                    string(JSON _baseline_raw_cpu_type TYPE "${_baseline_raw_binding}" cpu625)
                    string(JSON _baseline_raw_cpu GET "${_baseline_raw_binding}" cpu625)
                    if(NOT _baseline_raw_cpu_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_cpu)
                        message(FATAL_ERROR "NPC665 carrier CPU625 raw selection differs")
                    endif()
                endif()
            elseif(TOOIE_BASELINE_CPU625)
                # Replace only after independent actual source/ELF/byte acceptance.
                set(_baseline_expected_image "63a564aa2af9a69424ef9154965da92488a81aa3d405671fbb633074dbf4761c")
                string(JSON _baseline_raw_cpu_type TYPE "${_baseline_raw_binding}" cpu625)
                string(JSON _baseline_raw_cpu GET "${_baseline_raw_binding}" cpu625)
                if(NOT _baseline_raw_cpu_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_cpu)
                    message(FATAL_ERROR "CPU625 raw selection is not explicit ON")
                endif()
            elseif(_baseline_actor_enabled)
                set(_baseline_expected_image "9b52d782634dbd33c91588acf3804ffd51180fd9f7a8b6f6946b7cdb462d9718")
            else()
                set(_baseline_expected_image "9f55304f37a88c83579c0c4e5ac02deab9baec9bf278d3a705c4d3a0fe49dae7")
            endif()
            string(JSON _baseline_raw_host_type ERROR_VARIABLE _baseline_raw_host_error TYPE "${_baseline_raw_binding}" minimum_host)
            string(JSON _baseline_raw_host ERROR_VARIABLE _baseline_raw_host_value_error GET "${_baseline_raw_binding}" minimum_host)
            if(TOOIE_BASELINE_HOST)
                if(NOT _baseline_raw_host_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_host)
                    message(FATAL_ERROR "HOST raw selection is not explicit ON")
                endif()
                string(JSON _baseline_raw_music_type TYPE "${_baseline_raw_binding}" music_gain)
                string(JSON _baseline_raw_music GET "${_baseline_raw_binding}" music_gain)
                if(NOT _baseline_raw_music_type STREQUAL "BOOLEAN" OR NOT _baseline_raw_music)
                    message(FATAL_ERROR "Music raw selection is not explicit ON with HOST")
                endif()
                # NPC image identity includes HOST and therefore takes priority.
                if(TOOIE_BASELINE_BACKPACK621)
                    # Keep explicit pending621 image gate; no HOST hash override.
                elseif(TOOIE_BASELINE_NPC665)
                    # Keep the explicit pending NPC image gate above.
                elseif(TOOIE_BASELINE_CPU625)
                    set(_baseline_expected_image "896ddc57ba43db4f5ef368d27eb9e9fc55015854ec12282cb2664d59f53c07e1")
                else()
                    set(_baseline_expected_image "HOST_CPU_OFF_UNQUALIFIED")
                endif()
            elseif(_baseline_raw_host_type STREQUAL "BOOLEAN" AND _baseline_raw_host)
                message(FATAL_ERROR "HOST raw hooks are ON while native selection is OFF")
            endif()
            if(_baseline_first_person_aim)
                # Qualified translated FPS behavior and exact composed image.
                set(_baseline_expected_image "a0ce3e34290565647df70cb54bc72de2101ca2828c86309162ba91c1df4642c7")
            endif()
            if(_baseline_flap_flip)
                set(_baseline_expected_image "290755f1ecd95da325877c5dab99ed807c8bc373db04ec1c8a3a85fc633f6aaf")
            endif()
            # Generated patch C has independent pins only for the selected player image.
            set(_baseline_expected_generated_hashes)
            if(TOOIE_BASELINE_HOST)
                # New music composition; historical image branches above stay unchanged.
                set(_baseline_expected_image "MUSIC_HOST_COMPOSITION_UNQUALIFIED")
                if(TOOIE_BASELINE_CPU625 AND TOOIE_BASELINE_NPC665 AND TOOIE_BASELINE_BACKPACK621 AND
                   _baseline_shadow_coefficients STREQUAL "ON" AND _baseline_quiet_trot AND _baseline_trot_toggle AND
                   _baseline_first_person_aim AND _baseline_flap_flip)
                    set(_baseline_expected_image "263e1d27d21ebd9d1604f7096cf6f97466b1b74041dbd745cce278980b21b3d8")
                    # Root-measured: two patch-only N64Recomp runs over this image's retained
                    # ELF/syms, after the eight table sorts, equal each other and these bytes.
                    # Re-pin together with the image above; never from a fresh receipt.
                    set(_baseline_expected_generated_hashes
                        9c11485f136f2a0b62bdda8ce7732f7d17b3fe17825d81903332529509f540f0
                        f17f4e168916681cce802092058ba35bdec693b17b3259ab2456249f407d3497
                        313f6493f8d4115d7e7299388df7ace1565c1f098edafa3505eb7ea7d268a296)
                endif()
            endif()
            if(NOT _baseline_image_sha STREQUAL _baseline_expected_image)
                message(FATAL_ERROR "PRE exact separately qualified actorON/OFF image mismatch")
            endif()
            if(_baseline_expected_generated_hashes)
                # Hash the files actually compiled/included, which must be this image's composition.
                file(REAL_PATH "${TOOIE_BASELINE_BOOT_PATCH_DIR}" _baseline_compiled_patch_dir)
                file(REAL_PATH "${_baseline_bridge_dir}" _baseline_image_patch_dir)
                if(NOT _baseline_compiled_patch_dir STREQUAL _baseline_image_patch_dir)
                    message(FATAL_ERROR "Compiled guest patch sources are not the selected image composition")
                endif()
                set(_baseline_generated_inputs boot.c recomp_overlays.inl funcs.h)
                foreach(_input _expected IN ZIP_LISTS _baseline_generated_inputs _baseline_expected_generated_hashes)
                    # An edit reruns configure, so this gate precedes any rebuild that uses it.
                    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_baseline_compiled_patch_dir}/${_input}")
                    file(SHA256 "${_baseline_compiled_patch_dir}/${_input}" _actual)
                    if(NOT _actual STREQUAL _expected)
                        message(FATAL_ERROR "Selected generated guest patch source differs: ${_input}")
                    endif()
                endforeach()
            endif()
            if(_baseline_actor_enabled)
                math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+4")
                math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+3")
            endif()
            math(EXPR _baseline_provider_expected "${_baseline_provider_expected}+3")
            math(EXPR _baseline_helper_expected "${_baseline_helper_expected}+3")
        endif()
        if(_baseline_shadow_type STREQUAL "OBJECT" AND _baseline_actor_enabled AND NOT _baseline_pre_type STREQUAL "OBJECT")
            message(FATAL_ERROR "Combined actor/shadow requires reviewed PRE condition")
        endif()
        if(TOOIE_BASELINE_PLAYER_BOUNDARY AND NOT TOOIE_BASELINE_SILO_ACQUISITION_OBSERVER AND _baseline_actor_enabled AND
           (NOT _baseline_pre_type STREQUAL "OBJECT" OR NOT _baseline_shadow_type STREQUAL "OBJECT"))
            message(FATAL_ERROR "Quiet actor palette requires exact qualified PRE/shadow condition")
        endif()
        if(NOT _baseline_selected_state EQUAL 23036 OR NOT _baseline_selected_count EQUAL _baseline_provider_expected OR
           NOT _baseline_actual_body_count EQUAL _baseline_provider_expected OR NOT _baseline_helper_count EQUAL _baseline_helper_expected)
            message(FATAL_ERROR "Combined camera/helper/player provider/helper/body counts or layout5 extent23036 differ from selected demo condition")
        endif()
    elseif(TOOIE_BASELINE_SILO_CANDIDATE)
        string(JSON _baseline_helper_count LENGTH "${_baseline_selected_receipt}" helper_definitions)
        string(JSON _baseline_helper_name GET "${_baseline_selected_receipt}" helper_definitions 0)
        file(STRINGS "${_baseline_bridge_dir}/boot.c" _baseline_helper_body REGEX "^RECOMP_FUNC void (tooie_silo_preflight|tooie_player_begin|tooie_player_end|tooie_player_bone_push|tooie_player_bone_pop|tooie_player_leaf_begin|tooie_player_leaf_end)\\(")
        list(LENGTH _baseline_helper_body _baseline_helper_actual_count)
        math(EXPR _baseline_replacement_actual_count "${_baseline_actual_body_count} - ${_baseline_helper_actual_count}")
        if(NOT _baseline_selected_state EQUAL 23036 OR NOT _baseline_selected_count EQUAL 13 OR
           NOT _baseline_replacement_actual_count EQUAL 13 OR NOT _baseline_actual_body_count EQUAL 20 OR
           NOT _baseline_helper_count EQUAL 7 OR NOT _baseline_helper_actual_count EQUAL 7 OR
           NOT _baseline_helper_name STREQUAL "tooie_silo_preflight")
            message(FATAL_ERROR "Held candidate requires thirteen replacements, seven named helpers and layout5 extent23036")
        endif()
    else()
        if(NOT _baseline_actual_body_count EQUAL _baseline_selected_count)
            message(FATAL_ERROR "Selected bridge receipt/body definition count differs")
        endif()
        if(NOT _baseline_selected_state EQUAL 4180 OR NOT _baseline_selected_count EQUAL 8)
            message(FATAL_ERROR "Default bridge requires accepted eight-body extent4180")
        endif()
    endif()
    if(NOT _baseline_birth_count EQUAL 1 OR NOT _baseline_bone_count EQUAL 1 OR NOT _baseline_owner_count EQUAL 1 OR
       NOT _baseline_draw_count EQUAL 1 OR NOT EXISTS "${_baseline_bridge_dir}/render_bridge_layout.h")
        message(FATAL_ERROR "Renderer bridge image/body/layout admission failed")
    endif()
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_baseline_bone_fixture_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/bone-handler")
    set(_baseline_bone_fixture "${_baseline_bone_fixture_dir}/dcf48_fixture.inc")
    set(_baseline_bone_fixture_functions func_800DCF48)
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        # Definition first supplies the real direct-call declaration and body.
        set(_baseline_bone_fixture_functions tooie_silo_preflight tooie_player_bone_push tooie_player_bone_pop func_800DCF48)
        if(_baseline_bk_pipeline)
            # The BK bone group helpers precede their caller for the same reason.
            list(INSERT _baseline_bone_fixture_functions 3 tooie_bk_set_model_matrix_group tooie_bk_pop_model_matrix_group)
        endif()
    endif()
    add_custom_command(OUTPUT "${_baseline_bone_fixture}"
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
            "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_bone_fixture}" ${_baseline_bone_fixture_functions}
        DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
    file(READ "${_baseline_bridge_dir}/receipt.json" _baseline_bridge_receipt)
    string(JSON _baseline_bone_frame GET "${_baseline_bridge_receipt}" bone_frame_bytes)
    add_executable(BaselineBoneHandlerTest EXCLUDE_FROM_ALL tests/baseline_bone_handler_test.cpp "${_baseline_bone_fixture}")
    target_include_directories(BaselineBoneHandlerTest BEFORE PRIVATE "${_baseline_bone_fixture_dir}")
    target_include_directories(BaselineBoneHandlerTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
    target_compile_definitions(BaselineBoneHandlerTest PRIVATE NOMINMAX "TOOIE_DCF48_FRAME_BYTES=${_baseline_bone_frame}")
    set_target_properties(BaselineBoneHandlerTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    # Pinned original bodies remain separate, unmodified differential references; extraction enforces the pins.
    set(_baseline_original_raw_dir "${CMAKE_BINARY_DIR}/baseline/raw")
    file(GLOB _baseline_original_fixture_sources CONFIGURE_DEPENDS "${_baseline_original_raw_dir}/funcs_*.c")
    # CMake owns these extractions; the guest receipt owns the composition folder.
    set(_baseline_draw_fixture_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/draw-boundaries")
    set(_baseline_draw_fixture "${_baseline_draw_fixture_dir}/candidate_draw_boundaries_fixture.inc")
    set(_baseline_original_owner_fixture "${_baseline_draw_fixture_dir}/original_101808_fixture.inc")
    set(_baseline_original_draw_fixture "${_baseline_draw_fixture_dir}/original_de448_fixture.inc")
    set(_baseline_draw_fixture_functions func_80101808 func_800DE448)
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        list(APPEND _baseline_draw_fixture_functions tooie_player_begin tooie_player_bone_push tooie_player_bone_pop tooie_player_end func_80092898 func_800F3880
            tooie_player_leaf_begin tooie_player_leaf_end)
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE AND _baseline_secondary)
        list(APPEND _baseline_draw_fixture_functions tooie_secondary_route_begin tooie_secondary_route_end
            tooie_secondary_route_arm tooie_secondary_route_disarm tooie_player_secondary_begin)
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE AND _baseline_bk_pipeline)
        list(PREPEND _baseline_draw_fixture_functions tooie_bk_set_model_matrix_group tooie_bk_pop_model_matrix_group
            tooie_bk_frame_begin tooie_bk_root_begin tooie_bk_root_end tooie_bk_scope_end
            tooie_bk_actor_draw_begin tooie_bk_de448_begin tooie_bk_de448_end tooie_bk_list_begin tooie_bk_list_end)
    endif()
    if(TOOIE_BASELINE_NPC665)
        list(APPEND _baseline_draw_fixture_functions tooie_npc665_end)
    endif()
    if(TOOIE_BASELINE_CPU625)
        list(APPEND _baseline_draw_fixture_functions tooie_cpu625_retire)
    endif()
    if(TOOIE_BASELINE_BACKPACK621)
        list(APPEND _baseline_draw_fixture_functions tooie_backpack621_retire)
    endif()
    if(TOOIE_BASELINE_CAMERA_IDENTITY)
        list(APPEND _baseline_draw_fixture_functions tooie_camera_construction_begin tooie_camera_construction_end tooie_actor_palette_begin tooie_actor_palette_end func_8008B10C anctrl_setSmoothTransition)
        if(_baseline_first_person_aim)
            list(APPEND _baseline_draw_fixture_functions func_80800380_chhoneycarrier
                tooie_shadow_mode_begin tooie_shadow_mode_end tooie_shadow_complete
                tooie_shadow_reset tooie_shadow_de498 tooie_shadow_rectangle_args tooie_shadow_mv_end)
        endif()
    endif()
    set(_baseline_skeletal_fixture OFF)
    # Full supported composition; earlier checks already force camera/CPU625/actor/PRE/shadow.
    if(TOOIE_BASELINE_SILO_CANDIDATE AND TOOIE_BASELINE_NPC665 AND TOOIE_BASELINE_BACKPACK621 AND
       TOOIE_BASELINE_HOST AND _baseline_first_person_aim AND _baseline_flap_flip)
        set(_baseline_skeletal_fixture ON)
        list(APPEND _baseline_draw_fixture_functions
            tooie_npc665_admit tooie_npc665_bone_push tooie_npc665_bone_pop
            tooie_npc665_leaf_begin tooie_npc665_leaf_end
            tooie_actor_cpu_root_begin tooie_actor_feather_leaf_id
            func_800E44FC func_800E42F0 func_800E4640 func_800E4628
            func_800DD024)
        if(_baseline_raw_ckcopy)
            # These bodies/cases belong to the selected P04b/P04a/N3 composition only.
            list(APPEND _baseline_draw_fixture_functions
                tooie_ckcopy_root_begin tooie_ckcopy_segment tooie_ckcopy_root_end tooie_ckcopy_release
                tooie_cpu625_begin tooie_cpu625_admit tooie_cpu625_end
                tooie_cpu625_attach_begin tooie_cpu625_attach_end tooie_shadow_prepare)
        endif()
    endif()
    if(_baseline_bk_pipeline)
        # BK shadow: source/prepare/MODELVIEW-close helpers are not in the selected image.
        list(REMOVE_ITEM _baseline_draw_fixture_functions tooie_shadow_source tooie_shadow_prepare tooie_shadow_mv_end)
    endif()
    add_custom_command(OUTPUT "${_baseline_draw_fixture}" "${_baseline_original_owner_fixture}" "${_baseline_original_draw_fixture}"
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
            "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_draw_fixture}" ${_baseline_draw_fixture_functions}
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
            --source-sha256 0bdd8282ac23dbb1ced9f07afc65270f3e0c81b0b90a79e83efd439d148e343d
            "${_baseline_original_raw_dir}" "${_baseline_original_owner_fixture}" func_80101808
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
            --source-sha256 3dea3ef1220749f9678a391553adf1d4cf967d7482d494325554fe10b08e5af2
            "${_baseline_original_raw_dir}" "${_baseline_original_draw_fixture}" func_800DE448
        DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c"
            ${_baseline_original_fixture_sources} VERBATIM)
    string(JSON _baseline_owner_frame GET "${_baseline_bridge_receipt}" pair_frames func_80101808)
    string(JSON _baseline_draw_frame GET "${_baseline_bridge_receipt}" pair_frames func_800DE448)
    # Extra guest depth below the pair wrappers, from this selected receipt.
    # These calls are siblings except de448_end -> root_end/scope_end.
    set(_baseline_bk_draw_nested 0)
    if(TOOIE_BASELINE_SILO_CANDIDATE AND _baseline_bk_pipeline)
        foreach(_bk_helper IN ITEMS actor_draw_begin de448_begin de448_end root_end scope_end)
            string(JSON _bk_${_bk_helper}_frame GET "${_baseline_bridge_receipt}"
                shared_objects bk frames tooie_bk_${_bk_helper})
        endforeach()
        set(_bk_close_frames ${_bk_root_end_frame} ${_bk_scope_end_frame})
        list(SORT _bk_close_frames COMPARE NATURAL ORDER DESCENDING)
        list(GET _bk_close_frames 0 _bk_close_frame)
        math(EXPR _bk_close_nested "${_bk_de448_end_frame}+${_bk_close_frame}")
        set(_bk_draw_frames ${_bk_actor_draw_begin_frame} ${_bk_de448_begin_frame}
            ${_bk_close_nested})
        list(SORT _bk_draw_frames COMPARE NATURAL ORDER DESCENDING)
        list(GET _bk_draw_frames 0 _baseline_bk_draw_nested)
    endif()
    add_executable(BaselineDrawBoundariesTest EXCLUDE_FROM_ALL tests/baseline_draw_boundaries_state_test.cpp
        "${_baseline_draw_fixture}" "${_baseline_original_owner_fixture}" "${_baseline_original_draw_fixture}")
    if(TOOIE_BASELINE_NPC665)
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_NPC665_FIXTURE=1)
    endif()
    if(_baseline_bk_pipeline)
        # BK shadow: the legacy shadow admission/MODELVIEW cases are BK-OFF only (BaselineBkShadowTest).
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_BK_SHADOW_FIXTURE=1)
    endif()
    target_include_directories(BaselineDrawBoundariesTest BEFORE PRIVATE "${_baseline_draw_fixture_dir}")
    target_include_directories(BaselineDrawBoundariesTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
    target_compile_definitions(BaselineDrawBoundariesTest PRIVATE NOMINMAX
        "TOOIE_DRAW_101808_FRAME_BYTES=${_baseline_owner_frame}" "TOOIE_DRAW_DE448_FRAME_BYTES=${_baseline_draw_frame}"
        "TOOIE_DRAW_BK_NESTED_FRAME_BYTES=${_baseline_bk_draw_nested}")
    if(_baseline_skeletal_fixture)
        # Every measured frame from the selected receipt this target already uses, plus nested chains.
        set(_skeletal_frames_all)
        foreach(_skeletal_owner IN ITEMS npc665 bone pair silo player actor leaf lifecycle)
            if(_skeletal_owner STREQUAL "npc665")
                string(JSON _skeletal_table GET "${_baseline_bridge_receipt}" objects npc665 frames)
            else()
                string(JSON _skeletal_table GET "${_baseline_bridge_receipt}" shared_objects ${_skeletal_owner} frames)
            endif()
            string(JSON _skeletal_count LENGTH "${_skeletal_table}")
            if(NOT _skeletal_count GREATER 0)
                message(FATAL_ERROR "Skeletal fixture frame table is empty: ${_skeletal_owner}")
            endif()
            math(EXPR _skeletal_last "${_skeletal_count}-1")
            foreach(_skeletal_index RANGE ${_skeletal_last})
                string(JSON _skeletal_name MEMBER "${_skeletal_table}" ${_skeletal_index})
                string(JSON _skeletal_bytes GET "${_skeletal_table}" "${_skeletal_name}")
                list(APPEND _skeletal_frames_all ${_skeletal_bytes})
            endforeach()
        endforeach()
        string(JSON _skeletal_admit GET "${_baseline_bridge_receipt}" objects npc665 frames tooie_npc665_admit)
        string(JSON _skeletal_end GET "${_baseline_bridge_receipt}" objects npc665 frames tooie_npc665_end)
        math(EXPR _skeletal_admit "${_baseline_draw_frame}+${_skeletal_admit}")
        math(EXPR _skeletal_end "${_baseline_draw_frame}+${_skeletal_end}")
        math(EXPR _skeletal_nested "2*${_baseline_draw_frame}+${_baseline_owner_frame}+${_baseline_bk_draw_nested}")
        list(APPEND _skeletal_frames_all ${_skeletal_admit} ${_skeletal_end} ${_skeletal_nested})
        string(JSON _title53_begin GET "${_baseline_bridge_receipt}" shared_objects actor frames tooie_actor_cpu_root_begin)
        string(JSON _title53_end GET "${_baseline_bridge_receipt}" shared_objects actor frames tooie_actor_palette_end)
        math(EXPR _title53_begin "${_baseline_draw_frame}+${_title53_begin}")
        math(EXPR _title53_end "${_baseline_draw_frame}+${_title53_end}")
        list(APPEND _skeletal_frames_all ${_title53_begin} ${_title53_end})
        if(_baseline_bk_pipeline)
            # Actual DD024 -> list_begin -> group; list_end is the alternative close path.
            string(JSON _bk_dd024_frame GET "${_baseline_bridge_receipt}" objects camera_hook_leaves frames func_800DD024)
            string(JSON _bk_list_begin_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_list_begin)
            string(JSON _bk_group_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_set_model_matrix_group)
            string(JSON _bk_list_end_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_list_end)
            math(EXPR _bk_list_chain "${_bk_list_begin_frame}+${_bk_group_frame}")
            if(_bk_list_end_frame GREATER _bk_list_chain)
                set(_bk_list_chain ${_bk_list_end_frame})
            endif()
            math(EXPR _bk_dd024_chain "${_bk_dd024_frame}+${_bk_list_chain}")
            list(APPEND _skeletal_frames_all ${_bk_dd024_chain})
            target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_BK_DRAW_FIXTURE=1
                "TOOIE_BK_DD024_FRAME_BYTES=${_bk_dd024_chain}")
        endif()
        list(SORT _skeletal_frames_all COMPARE NATURAL ORDER DESCENDING)
        list(GET _skeletal_frames_all 0 _skeletal_max)
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE
            "TOOIE_SKELETAL_FIXTURE=\"baseline_skeletal_cases.inc\""
            "TOOIE_SKELETAL_MAX_FRAME_BYTES=${_skeletal_max}"
            TOOIE_CAMERA_PRODUCTION_FIXTURE=1
            "TOOIE_CAMERA_FIXTURE_BOOT_IMAGE=\"${_baseline_bridge_dir}/boot.bin\"")
        if(_baseline_raw_ckcopy)
            target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_CKCOPY_FIXTURE=1)
        endif()
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE AND _baseline_secondary)
        string(JSON _secondary_begin_frame GET "${_baseline_bridge_receipt}" shared_objects secondary frames tooie_player_secondary_begin)
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_PLAYER_SECONDARY_FIXTURE=1
            "TOOIE_PLAYER_SECONDARY_ADMIT=$<BOOL:${_baseline_secondary_admit}>"
            "TOOIE_PLAYER_SECONDARY_BEGIN_FRAME_BYTES=${_secondary_begin_frame}")
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        string(JSON _player_state GET "${_baseline_bridge_receipt}" state_vram)
        set(_baseline_lifecycle_fixture_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/player-lifecycle")
        set(_lifecycle_init "${_baseline_lifecycle_fixture_dir}/player_init_original_fixture.inc")
        set(_lifecycle_free "${_baseline_lifecycle_fixture_dir}/player_free_original_fixture.inc")
        set(_lifecycle_candidate "${_baseline_lifecycle_fixture_dir}/player_lifecycle_candidate_fixture.inc")
        add_custom_command(OUTPUT "${_lifecycle_init}" "${_lifecycle_free}" "${_lifecycle_candidate}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                --source-sha256 f19504e5fa3af80b912bb128d1d13ac1569644cfeb97bca881e73a97f5c7d04e
                "${_baseline_original_raw_dir}" "${_lifecycle_init}" func_80092898
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                --source-sha256 dde11db9e52bd9251c4b9a56d34afc97eff8c6551cf5c1cf04af140cad84f296
                "${_baseline_original_raw_dir}" "${_lifecycle_free}" func_800F3880
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_lifecycle_candidate}" func_80092898 func_800F3880
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c"
                ${_baseline_original_fixture_sources} VERBATIM)
        string(JSON _init_frame GET "${_baseline_bridge_receipt}" lifecycle_frames func_80092898)
        string(JSON _free_frame GET "${_baseline_bridge_receipt}" lifecycle_frames func_800F3880)
        add_executable(BaselinePlayerLifecycleTest EXCLUDE_FROM_ALL tests/baseline_player_lifecycle_test.cpp
            "${_lifecycle_init}" "${_lifecycle_free}" "${_lifecycle_candidate}")
        target_include_directories(BaselinePlayerLifecycleTest BEFORE PRIVATE "${_baseline_lifecycle_fixture_dir}")
        target_include_directories(BaselinePlayerLifecycleTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
        target_compile_definitions(BaselinePlayerLifecycleTest PRIVATE NOMINMAX "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
            "TOOIE_TROT_SELECTED=$<BOOL:${_baseline_trot_toggle}>"
            "TOOIE_PLAYER_INIT_FRAME_BYTES=${_init_frame}" "TOOIE_PLAYER_FREE_FRAME_BYTES=${_free_frame}")
        set_target_properties(BaselinePlayerLifecycleTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        string(JSON _player_begin_frame GET "${_baseline_bridge_receipt}" player_frames tooie_player_begin)
        string(JSON _player_push_frame GET "${_baseline_bridge_receipt}" player_frames tooie_player_bone_push)
        string(JSON _player_pop_frame GET "${_baseline_bridge_receipt}" player_frames tooie_player_bone_pop)
        target_compile_definitions(BaselineBoneHandlerTest PRIVATE
            "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
            "TOOIE_PLAYER_BONE_PUSH_FRAME_BYTES=${_player_push_frame}"
            "TOOIE_PLAYER_BONE_POP_FRAME_BYTES=${_player_pop_frame}")
        if(_baseline_bk_pipeline)
            # B4: in the BK selection DCF48's only label is the BK bone group, and the draw
            # boundaries no longer reach the secondary/NPC665/title53 row admissions. Those row
            # cases keep running in the BK-OFF composition.
            string(JSON _bk_set_group_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_set_model_matrix_group)
            string(JSON _bk_pop_group_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_pop_model_matrix_group)
            set(_bk_group_frame ${_bk_set_group_frame})
            if(_bk_pop_group_frame GREATER _bk_group_frame)
                set(_bk_group_frame ${_bk_pop_group_frame})
            endif()
            target_compile_definitions(BaselineBoneHandlerTest PRIVATE TOOIE_BK_B4_FIXTURE=1
                "TOOIE_BK_GROUP_FRAME_BYTES=${_bk_group_frame}")
            target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_BK_B4_FIXTURE=1)
        endif()
        string(JSON _player_end_frame GET "${_baseline_bridge_receipt}" player_frames tooie_player_end)
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE
            "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
            "TOOIE_PLAYER_BEGIN_FRAME_BYTES=${_player_begin_frame}"
            "TOOIE_PLAYER_END_FRAME_BYTES=${_player_end_frame}")
    endif()
    if(TOOIE_BASELINE_CAMERA_IDENTITY)
        string(JSON _actor_begin_frame GET "${_baseline_bridge_receipt}" actor_frames tooie_actor_palette_begin)
        string(JSON _actor_end_frame GET "${_baseline_bridge_receipt}" actor_frames tooie_actor_palette_end)
        target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_ACTOR_PALETTE_FIXTURE=1
            "TOOIE_ACTOR_PALETTE_BEGIN_FRAME_BYTES=${_actor_begin_frame}" "TOOIE_ACTOR_PALETTE_END_FRAME_BYTES=${_actor_end_frame}")
        if(_baseline_first_person_aim)
            target_compile_definitions(BaselineDrawBoundariesTest PRIVATE TOOIE_REQUIRED_STOP_FIXTURE=1)
        endif()
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        set(_baseline_leaf_fixture_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/leaf-handler")
        set(_baseline_leaf_original_fixture "${_baseline_leaf_fixture_dir}/dd998_original_fixture.inc")
        set(_baseline_leaf_candidate_fixture "${_baseline_leaf_fixture_dir}/dd998_candidate_fixture.inc")
        set(_baseline_leaf_helpers_fixture "${_baseline_leaf_fixture_dir}/player_leaf_helpers_fixture.inc")
        set(_baseline_leaf_helpers tooie_player_bone_push tooie_player_bone_pop tooie_player_leaf_begin tooie_player_leaf_end)
        if(TOOIE_BASELINE_NPC665)
            list(APPEND _baseline_leaf_helpers tooie_npc665_leaf_begin tooie_npc665_leaf_end)
        endif()
        if(TOOIE_BASELINE_BACKPACK621)
            list(APPEND _baseline_leaf_helpers tooie_backpack621_leaf_begin tooie_backpack621_leaf_end)
        endif()
        if(_baseline_bk_pipeline)
            # DD998's BK list node replaces the row leaf labels; its helpers precede the candidate.
            list(APPEND _baseline_leaf_helpers tooie_bk_set_model_matrix_group tooie_bk_pop_model_matrix_group
                tooie_bk_list_begin tooie_bk_list_end)
        endif()
        add_custom_command(OUTPUT "${_baseline_leaf_original_fixture}" "${_baseline_leaf_candidate_fixture}" "${_baseline_leaf_helpers_fixture}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                --source-sha256 3dea3ef1220749f9678a391553adf1d4cf967d7482d494325554fe10b08e5af2
                "${_baseline_original_raw_dir}" "${_baseline_leaf_original_fixture}" func_800DD998
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_leaf_candidate_fixture}" func_800DD998
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_leaf_helpers_fixture}"
                ${_baseline_leaf_helpers}
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" ${_baseline_original_fixture_sources} VERBATIM)
        string(JSON _baseline_leaf_frame GET "${_baseline_bridge_receipt}" leaf_frame_bytes)
        string(JSON _baseline_leaf_helper_frame GET "${_baseline_bridge_receipt}" player_frames tooie_player_leaf_begin)
        add_executable(BaselineLeafHandlerTest EXCLUDE_FROM_ALL tests/baseline_leaf_handler_test.cpp
            "${_baseline_leaf_original_fixture}" "${_baseline_leaf_candidate_fixture}" "${_baseline_leaf_helpers_fixture}")
        target_include_directories(BaselineLeafHandlerTest BEFORE PRIVATE "${_baseline_leaf_fixture_dir}")
        target_include_directories(BaselineLeafHandlerTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
        target_compile_definitions(BaselineLeafHandlerTest PRIVATE NOMINMAX "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
            "TOOIE_TEST_PLAYER_PHYSICAL_BYTES=$<IF:$<BOOL:${TOOIE_BASELINE_CAMERA_IDENTITY}>,0x5BEC0u,0x8FC0u>"
            "TOOIE_DD998_FRAME_BYTES=${_baseline_leaf_frame}" "TOOIE_DD998_HELPER_FRAME_BYTES=${_baseline_leaf_helper_frame}")
        if(_baseline_bk_pipeline)
            # Candidate depth under BK: DD998 -> tooie_bk_list_begin -> tooie_bk_set_model_matrix_group.
            string(JSON _baseline_bk_list_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_list_begin)
            string(JSON _baseline_bk_group_frame GET "${_baseline_bridge_receipt}" shared_objects bk frames tooie_bk_set_model_matrix_group)
            math(EXPR _baseline_bk_leaf_helper_frame "${_baseline_bk_list_frame}+${_baseline_bk_group_frame}")
            target_compile_definitions(BaselineLeafHandlerTest PRIVATE TOOIE_BK_LEAF_FIXTURE=1
                "TOOIE_BK_LEAF_HELPER_FRAME_BYTES=${_baseline_bk_leaf_helper_frame}")
        endif()
        set_target_properties(BaselineLeafHandlerTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        if(_baseline_bk_pipeline)
            # B4 + silhouette attachment: actual BK-selected DE448/80101808 bodies and BK owner helpers
            # (helpers first: each definition supplies its callers' declaration).
            set(_baseline_bk_boundary_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/bk-boundaries")
            set(_baseline_bk_boundary_fixture "${_baseline_bk_boundary_dir}/bk_boundaries_fixture.inc")
            set(_baseline_bk_boundary_helpers tooie_bk_scope_end tooie_bk_menu_model_begin tooie_bk_menu_model_end tooie_bk_root_end tooie_bk_root_begin tooie_bk_de448_begin
                tooie_bk_de448_end tooie_bk_actor_draw_begin tooie_bk_attachment_begin tooie_bk_attachment_end
                tooie_bk_selector_begin tooie_bk_selector_child tooie_bk_selector_end)
            add_custom_command(OUTPUT "${_baseline_bk_boundary_fixture}"
                COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                    "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_bk_boundary_fixture}"
                    ${_baseline_bk_boundary_helpers} func_800DE448 func_80101808
                DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
            # Deepest BK chain below a boundary: any helper alone, or a helper plus the helper it calls.
            foreach(_bk_helper IN LISTS _baseline_bk_boundary_helpers)
                string(JSON _bk_frame_${_bk_helper} GET "${_baseline_bridge_receipt}" shared_objects bk frames ${_bk_helper})
            endforeach()
            math(EXPR _bk_end_root "${_bk_frame_tooie_bk_de448_end}+${_bk_frame_tooie_bk_root_end}")
            math(EXPR _bk_end_scope "${_bk_frame_tooie_bk_de448_end}+${_bk_frame_tooie_bk_scope_end}")
            math(EXPR _bk_attach_scope "${_bk_frame_tooie_bk_attachment_end}+${_bk_frame_tooie_bk_scope_end}")
            math(EXPR _bk_menu_scope "${_bk_frame_tooie_bk_menu_model_end}+${_bk_frame_tooie_bk_scope_end}")
            set(_baseline_bk_boundary_helper_frame 0)
            foreach(_bk_bytes IN ITEMS ${_bk_end_root} ${_bk_end_scope} ${_bk_attach_scope} ${_bk_menu_scope})
                if(_bk_bytes GREATER _baseline_bk_boundary_helper_frame)
                    set(_baseline_bk_boundary_helper_frame ${_bk_bytes})
                endif()
            endforeach()
            foreach(_bk_helper IN LISTS _baseline_bk_boundary_helpers)
                if(_bk_frame_${_bk_helper} GREATER _baseline_bk_boundary_helper_frame)
                    set(_baseline_bk_boundary_helper_frame ${_bk_frame_${_bk_helper}})
                endif()
            endforeach()
            add_executable(BaselineBkBoundariesTest EXCLUDE_FROM_ALL tests/baseline_bk_boundaries_test.cpp
                "${_baseline_bk_boundary_fixture}")
            target_include_directories(BaselineBkBoundariesTest BEFORE PRIVATE "${_baseline_bk_boundary_dir}")
            target_include_directories(BaselineBkBoundariesTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
            target_compile_definitions(BaselineBkBoundariesTest PRIVATE NOMINMAX
                "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
                "TOOIE_DRAW_101808_FRAME_BYTES=${_baseline_owner_frame}" "TOOIE_DRAW_DE448_FRAME_BYTES=${_baseline_draw_frame}"
                "TOOIE_BK_HELPER_FRAME_BYTES=${_baseline_bk_boundary_helper_frame}")
            set_target_properties(BaselineBkBoundariesTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        endif()
        if(_baseline_bk_pipeline)
            # packet6: actual BK shadow scope, bit40 root/float and camera DEFB0/compositor helpers
            # (helpers first: each definition supplies its callers' declaration).
            set(_baseline_bk_shadow_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/bk-shadow")
            set(_baseline_bk_shadow_fixture "${_baseline_bk_shadow_dir}/bk_shadow_fixture.inc")
            set(_baseline_bk_shadow_helpers tooie_bk_scope_end tooie_bk_root_end tooie_bk_frame_begin
                tooie_bk_root_begin tooie_bk_root_join tooie_bk_skin_segment tooie_bk_skin_capture
                tooie_bk_de448_begin tooie_bk_de448_end tooie_bk_shadow_route tooie_bk_shadow_light_event
                tooie_bk_shadow_begin tooie_bk_shadow_end tooie_bk_shadow_project)
            set(_baseline_bk_shadow_camera tooie_shadow_reset tooie_shadow_de498 tooie_shadow_rectangle_args
                tooie_shadow_mode_begin tooie_shadow_mode_end tooie_shadow_complete)
            add_custom_command(OUTPUT "${_baseline_bk_shadow_fixture}"
                COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                    "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_bk_shadow_fixture}"
                    ${_baseline_bk_shadow_helpers} ${_baseline_bk_shadow_camera}
                DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
            # Deepest measured chain: any helper alone, or a BK helper plus the BK helper it calls.
            set(_bk_shadow_frame 0)
            foreach(_bk_helper IN LISTS _baseline_bk_shadow_helpers)
                string(JSON _bkf_${_bk_helper} GET "${_baseline_bridge_receipt}" shared_objects bk frames ${_bk_helper})
                if(_bkf_${_bk_helper} GREATER _bk_shadow_frame)
                    set(_bk_shadow_frame ${_bkf_${_bk_helper}})
                endif()
            endforeach()
            foreach(_camera_helper IN LISTS _baseline_bk_shadow_camera)
                string(JSON _camera_frame GET "${_baseline_bridge_receipt}" objects shadow_projection frames ${_camera_helper})
                if(_camera_frame GREATER _bk_shadow_frame)
                    set(_bk_shadow_frame ${_camera_frame})
                endif()
            endforeach()
            math(EXPR _bk_join_root "${_bkf_tooie_bk_root_join}+${_bkf_tooie_bk_root_end}")
            math(EXPR _bk_end_root "${_bkf_tooie_bk_de448_end}+${_bkf_tooie_bk_root_end}")
            math(EXPR _bk_end_scope "${_bkf_tooie_bk_de448_end}+${_bkf_tooie_bk_scope_end}")
            math(EXPR _bk_shadow_scope "${_bkf_tooie_bk_shadow_end}+${_bkf_tooie_bk_scope_end}")
            string(JSON _bk_shadow_project_caller GET "${_baseline_bridge_receipt}" objects shadow_projection frames tooie_shadow_de498)
            math(EXPR _bk_shadow_project_chain "${_bk_shadow_project_caller}+${_bkf_tooie_bk_shadow_project}")
            foreach(_bk_bytes IN ITEMS ${_bk_join_root} ${_bk_end_root} ${_bk_end_scope} ${_bk_shadow_scope} ${_bk_shadow_project_chain})
                if(_bk_bytes GREATER _bk_shadow_frame)
                    set(_bk_shadow_frame ${_bk_bytes})
                endif()
            endforeach()
            add_executable(BaselineBkShadowTest EXCLUDE_FROM_ALL tests/baseline_bk_shadow_test.cpp
                "${_baseline_bk_shadow_fixture}")
            target_include_directories(BaselineBkShadowTest BEFORE PRIVATE "${_baseline_bk_shadow_dir}")
            target_include_directories(BaselineBkShadowTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
            target_compile_definitions(BaselineBkShadowTest PRIVATE NOMINMAX
                "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
                "TOOIE_BK_SHADOW_FIXTURE_FRAME_BYTES=${_bk_shadow_frame}")
            if(_baseline_first_person_aim)
                target_compile_definitions(BaselineBkShadowTest PRIVATE TOOIE_REQUIRED_STOP_FIXTURE=1)
            endif()
            set_target_properties(BaselineBkShadowTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        endif()
    endif()
    if(TOOIE_BASELINE_SILO_CANDIDATE AND _baseline_secondary)
        # PC[8] secondary route/admission helpers retranslated from the selected composition boot.c.
        set(_baseline_secondary_fixture_dir "${CMAKE_BINARY_DIR}/baseline/fixtures/player-secondary")
        set(_baseline_secondary_candidate "${_baseline_secondary_fixture_dir}/player_secondary_candidate_fixture.inc")
        add_custom_command(OUTPUT "${_baseline_secondary_candidate}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_secondary_candidate}"
                tooie_secondary_route_begin tooie_secondary_route_end tooie_secondary_route_arm
                tooie_secondary_route_disarm tooie_player_secondary_begin
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" VERBATIM)
        add_executable(BaselinePlayerSecondaryTest EXCLUDE_FROM_ALL tests/baseline_player_secondary_test.cpp
            "${_baseline_secondary_candidate}")
        target_include_directories(BaselinePlayerSecondaryTest BEFORE PRIVATE "${_baseline_secondary_fixture_dir}")
        target_include_directories(BaselinePlayerSecondaryTest PRIVATE "${_baseline_bridge_dir}" "${RUNTIME_RECOMP_INCLUDE}")
        target_compile_definitions(BaselinePlayerSecondaryTest PRIVATE NOMINMAX "TOOIE_PLAYER_STATE_ADDRESS=${_player_state}"
            "TOOIE_PLAYER_SECONDARY_ADMIT=$<BOOL:${_baseline_secondary_admit}>"
            "TOOIE_TEST_SECONDARY_BYTES=211968u" "TOOIE_TEST_LOWER_BYTES=0x5A5C0u")
        set_target_properties(BaselinePlayerSecondaryTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    endif()
    if(TOOIE_BASELINE_BACKPACK621)
        set(_baseline_rate_fixture_dir "${_baseline_bridge_dir}/graphics-rate-fixture")
        set(_baseline_rate_fixture "${_baseline_rate_fixture_dir}/graphics_rate_candidate_fixture.inc")
        file(READ "${_baseline_bridge_dir}/receipt.json" _baseline_rate_receipt)
        string(JSON _baseline_rate_tail GET "${_baseline_rate_receipt}" graphics_rate state)
        string(JSON _baseline_rate_demo GET "${_baseline_rate_receipt}" graphics_rate demo_state)
        string(JSON _baseline_rate_frame GET "${_baseline_rate_receipt}" objects graphics_rate frames func_800E7EF4)
        add_custom_command(OUTPUT "${_baseline_rate_fixture}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_baseline_rate_fixture_dir}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${_baseline_bridge_dir}/boot.c" "${_baseline_rate_fixture}" func_800E7EF4
            DEPENDS tests/extract_heap_realloc.py "${_baseline_bridge_dir}/boot.c"
                "${_baseline_bridge_dir}/receipt.json" VERBATIM)
        add_executable(BaselineGraphicsRateTest EXCLUDE_FROM_ALL
            tests/baseline_graphics_rate_test.cpp "${_baseline_rate_fixture}")
        target_include_directories(BaselineGraphicsRateTest PRIVATE
            "${_baseline_rate_fixture_dir}" "${RUNTIME_RECOMP_INCLUDE}")
        target_link_libraries(BaselineGraphicsRateTest PRIVATE rt64)
        if(NOT _baseline_posix)
            target_link_directories(BaselineGraphicsRateTest PRIVATE "${_baseline_sdl}/lib/x64")
        endif()
        if(MSVC)
            target_link_options(BaselineGraphicsRateTest PRIVATE /ENTRY:mainCRTStartup)
        endif()
        target_include_directories(BaselineGraphicsRateTest PRIVATE
            "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
            "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume"
            ${SDL2_INCLUDE_DIRS})
        target_compile_definitions(BaselineGraphicsRateTest PRIVATE NOMINMAX HLSL_CPU SDL_MAIN_HANDLED
            "TOOIE_GRAPHICS_RATE_TAIL_ADDRESS=${_baseline_rate_tail}u"
            "TOOIE_DEMO_TIMING_STATE_ADDRESS=${_baseline_rate_demo}u"
            "TOOIE_GRAPHICS_RATE_FRAME_BYTES=${_baseline_rate_frame}u")
        set_target_properties(BaselineGraphicsRateTest PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        add_test(NAME baseline_graphics_rate COMMAND BaselineGraphicsRateTest)
    endif()
    if(TOOIE_BASELINE_HOST)
        set(_baseline_wide_fixture_dir "${_baseline_bridge_dir}/widescreen-owner-fixture")
        set(_baseline_wide_fixtures
            "${_baseline_wide_fixture_dir}/widescreen_owner_candidate.inc"
            "${_baseline_wide_fixture_dir}/widescreen_owner_negative.inc"
            "${_baseline_wide_fixture_dir}/widescreen_owner_functions.h"
            "${_baseline_wide_fixture_dir}/widescreen_owner_facts.h")
        add_custom_command(OUTPUT ${_baseline_wide_fixtures}
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/prepare_widescreen_owner_fixture.py"
                --candidate "${_baseline_bridge_dir}/boot.c" --elf "${_baseline_bridge_dir}/boot.elf"
                --output "${_baseline_wide_fixture_dir}"
            DEPENDS tests/prepare_widescreen_owner_fixture.py tests/extract_heap_realloc.py
                "${_baseline_bridge_dir}/boot.c" "${_baseline_bridge_dir}/boot.elf"
                "${_baseline_bridge_dir}/data.syms.toml" VERBATIM)
        foreach(_wide_target IN ITEMS BaselineWidescreenOwnerTest BaselineWidescreenOwnerNegativeTest)
            add_executable(${_wide_target} EXCLUDE_FROM_ALL tests/baseline_widescreen_owner_test.cpp ${_baseline_wide_fixtures})
            target_include_directories(${_wide_target} PRIVATE "${_baseline_wide_fixture_dir}" "${RUNTIME_RECOMP_INCLUDE}")
            target_compile_definitions(${_wide_target} PRIVATE NOMINMAX)
            target_compile_features(${_wide_target} PRIVATE cxx_std_20)
            set_target_properties(${_wide_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        endforeach()
        target_compile_definitions(BaselineWidescreenOwnerNegativeTest PRIVATE WIDE_OWNER_NEGATIVE_ACTIVE)
        add_test(NAME baseline_widescreen_owner COMMAND BaselineWidescreenOwnerTest)
        add_test(NAME baseline_widescreen_owner_negative_active COMMAND BaselineWidescreenOwnerNegativeTest)
        set_tests_properties(baseline_widescreen_owner_negative_active PROPERTIES WILL_FAIL TRUE)
    endif()
    if(_baseline_trot_toggle)
        set(_baseline_trot_fixture_dir "${_baseline_bridge_dir}/talon-trot-toggle-fixture")
        set(_baseline_trot_fixtures
            "${_baseline_trot_fixture_dir}/candidate_fixture.inc"
            "${_baseline_trot_fixture_dir}/candidate_guard_mutant.inc"
            "${_baseline_trot_fixture_dir}/original_fixture.inc"
            "${_baseline_trot_fixture_dir}/fixture_functions.h"
            "${_baseline_trot_fixture_dir}/fixture_facts.h")
        file(GLOB _baseline_trot_originals CONFIGURE_DEPENDS "${CMAKE_BINARY_DIR}/baseline/raw/funcs_*.c")
        add_custom_command(OUTPUT ${_baseline_trot_fixtures}
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/prepare_trot_toggle_fixture.py"
                --candidate "${_baseline_bridge_dir}/boot.c" --elf "${_baseline_bridge_dir}/boot.elf"
                --originals "${CMAKE_BINARY_DIR}/baseline/raw" --output "${_baseline_trot_fixture_dir}"
            DEPENDS tests/prepare_trot_toggle_fixture.py tests/extract_heap_realloc.py "${_baseline_bridge_dir}/boot.c"
                "${_baseline_bridge_dir}/boot.elf" ${_baseline_trot_originals} VERBATIM)
        foreach(_trot_target IN ITEMS BaselineTrotToggleTest BaselineTrotToggleNegativeTest)
            add_executable(${_trot_target} EXCLUDE_FROM_ALL tests/baseline_trot_toggle_test.cpp ${_baseline_trot_fixtures})
            target_include_directories(${_trot_target} PRIVATE "${_baseline_trot_fixture_dir}" "${RUNTIME_RECOMP_INCLUDE}")
            target_compile_definitions(${_trot_target} PRIVATE NOMINMAX)
            target_compile_features(${_trot_target} PRIVATE cxx_std_20)
            set_target_properties(${_trot_target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        endforeach()
        target_compile_definitions(BaselineTrotToggleNegativeTest PRIVATE FB04_NEGATIVE_GUARD)
        add_test(NAME baseline_trot_toggle COMMAND BaselineTrotToggleTest)
        add_test(NAME baseline_trot_toggle_negative_guard COMMAND BaselineTrotToggleNegativeTest)
        set_tests_properties(baseline_trot_toggle_negative_guard PROPERTIES WILL_FAIL TRUE)
    endif()
    # Quiet leaf candidate comes from the selected image; originals remain in baseline/raw.
    if(_baseline_quiet_trot)
        set(_baseline_quiet_fixture_dir "${_baseline_bridge_dir}/quiet-talon-trot-fixture")
        file(MAKE_DIRECTORY "${_baseline_quiet_fixture_dir}")
        set(_baseline_quiet_candidate "${_baseline_quiet_fixture_dir}/candidate_fixture.inc")
        set(_baseline_quiet_leaf "${_baseline_quiet_fixture_dir}/original_bsbtrot_fixture.inc")
        set(_baseline_quiet_wrapper "${_baseline_quiet_fixture_dir}/original_de38_fixture.inc")
        set(_baseline_quiet_raw_dir "${CMAKE_BINARY_DIR}/baseline/raw")
        file(GLOB _baseline_quiet_originals CONFIGURE_DEPENDS "${_baseline_quiet_raw_dir}/funcs_*.c")
        add_custom_command(OUTPUT "${_baseline_quiet_candidate}" "${_baseline_quiet_leaf}" "${_baseline_quiet_wrapper}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c" "${_baseline_quiet_candidate}" func_808000DC_bsbtrot
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                --source-sha256 cbf67d584c268b63400fb7764cde14783b26d6b602c4abcbce9a4241272fceb8
                "${_baseline_quiet_raw_dir}" "${_baseline_quiet_leaf}" func_808000DC_bsbtrot
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tests/extract_heap_realloc.py"
                --source-sha256 2e52f0c3bf808ce278701524e0632ae5041985f6189b204df16c7a387f00d565
                "${_baseline_quiet_raw_dir}" "${_baseline_quiet_wrapper}" func_8009DE38
            DEPENDS tests/extract_heap_realloc.py "${TOOIE_BASELINE_BOOT_PATCH_DIR}/boot.c"
                ${_baseline_quiet_originals} VERBATIM)
        string(JSON _baseline_quiet_frame GET "${_baseline_bridge_receipt}" objects quiet_talon_trot frames func_808000DC_bsbtrot)
        if(NOT _baseline_quiet_frame EQUAL 40)
            message(FATAL_ERROR "Quiet Talon Trot qualified frame differs")
        endif()
        add_executable(BaselineQuietTalonTrotTest EXCLUDE_FROM_ALL tests/baseline_quiet_talon_trot_test.cpp
            "${_baseline_quiet_candidate}" "${_baseline_quiet_leaf}" "${_baseline_quiet_wrapper}")
        target_include_directories(BaselineQuietTalonTrotTest PRIVATE
            "${_baseline_quiet_fixture_dir}" "${RUNTIME_RECOMP_INCLUDE}")
        target_compile_definitions(BaselineQuietTalonTrotTest PRIVATE NOMINMAX
            "FB05_CANDIDATE_FRAME_BYTES=${_baseline_quiet_frame}"
            FB05_ORIGINAL_LEAF_FRAME_BYTES=24 FB05_ORIGINAL_WRAPPER_FRAME_BYTES=32)
        set_target_properties(BaselineQuietTalonTrotTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
        add_test(NAME baseline_quiet_talon_trot COMMAND BaselineQuietTalonTrotTest)
        add_test(NAME baseline_quiet_talon_trot_negative_pitch COMMAND BaselineQuietTalonTrotTest --negative pitch)
        set_tests_properties(baseline_quiet_talon_trot_negative_pitch PROPERTIES WILL_FAIL TRUE)
    endif()
    set_target_properties(BaselineDrawBoundariesTest PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    if(TOOIE_BASELINE_SILO_CANDIDATE)
        foreach(_target IN ITEMS BaselineBoneHandlerTest BaselineDrawBoundariesTest)
            _baseline_force_include(${_target} "${CMAKE_SOURCE_DIR}/tools/baseline/guest/silo-candidate/candidategetter_stub.h")
        endforeach()
    endif()
endif()
target_include_directories(TooieBaseline PRIVATE
    "${TOOIE_BASELINE_GENERATED_DIR}" "${RUNTIME_RECOMP_INCLUDE}" "${SDL2_INCLUDE_DIRS}"
    "${_baseline_rt64}/include" "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
    "${_baseline_rt64}/src/contrib/plume" "${_baseline_rt64}/src/contrib/hlslpp/include"
    "${_baseline_rt64}/src/contrib/mupen64plus-core/src/api"
    "${_baseline_rt64}/src/contrib/imgui" "${_baseline_rt64}/src/contrib/dxc/inc")
target_compile_definitions(TooieBaseline PRIVATE SDL_MAIN_HANDLED HLSL_CPU NOMINMAX __PRFCHWINTRIN_H)
target_compile_definitions(TooieBaseline PRIVATE "BASELINE_QUIET_TROT=$<BOOL:${_baseline_quiet_trot}>"
    "BASELINE_TROT_TOGGLE=$<BOOL:${_baseline_trot_toggle}>"
    "BASELINE_FIRST_PERSON_AIM=$<BOOL:${_baseline_first_person_aim}>"
    "BASELINE_FLAP_FLIP=$<BOOL:${_baseline_flap_flip}>")
target_link_libraries(TooieBaseline PRIVATE BaselineRecompiledFuncs librecomp ultramodern rt64
    Threads::Threads ${_baseline_sdl_link} ${_baseline_platform_libraries})
if(_baseline_macho)
    # main() serves the CoreFoundation run loop while the runtime runs on a helper thread (see main.cpp).
    target_link_libraries(TooieBaseline PRIVATE "-framework CoreFoundation")
endif()
# Qualification is a manual reviewed step; build targets never create/refresh it.
if(TOOIE_BASELINE_CAMERA_IDENTITY)
    if(NOT (MSVC OR _baseline_posix) OR NOT TOOIE_BASELINE_TERMINAL_FENCE OR NOT _baseline_map)
        message(FATAL_ERROR "Selected raw gate requires a map-producing composition")
    endif()
    if(_baseline_elf)
        set(TOOIE_BASELINE_BINUTILS_DIR "" CACHE PATH "Explicit GNU binutils directory whose objdump the ELF gates use")
        set(_baseline_objdump "${TOOIE_BASELINE_BINUTILS_DIR}/objdump")
        if(NOT IS_ABSOLUTE "${TOOIE_BASELINE_BINUTILS_DIR}" OR NOT EXISTS "${_baseline_objdump}")
            message(FATAL_ERROR "ELF gates require an explicit absolute TOOIE_BASELINE_BINUTILS_DIR containing objdump")
        endif()
        execute_process(COMMAND "${_baseline_objdump}" --version
            RESULT_VARIABLE _baseline_objdump_result OUTPUT_VARIABLE _baseline_objdump_version)
        if(NOT _baseline_objdump_result EQUAL 0 OR NOT _baseline_objdump_version MATCHES "^GNU objdump ")
            message(FATAL_ERROR "TOOIE_BASELINE_BINUTILS_DIR/objdump must be GNU objdump")
        endif()
        set(_baseline_binding_format --format elf)
        set(_baseline_binding_tools "${TOOIE_BASELINE_BINUTILS_DIR}")
    elseif(_baseline_macho)
        set(TOOIE_BASELINE_MACHO_TOOLS_DIR "" CACHE PATH "Explicit directory whose llvm-objdump the Mach-O gates use, for example the Xcode toolchain usr/bin")
        set(_baseline_objdump "${TOOIE_BASELINE_MACHO_TOOLS_DIR}/llvm-objdump")
        if(NOT IS_ABSOLUTE "${TOOIE_BASELINE_MACHO_TOOLS_DIR}" OR NOT EXISTS "${_baseline_objdump}")
            message(FATAL_ERROR "Mach-O gates require an explicit absolute TOOIE_BASELINE_MACHO_TOOLS_DIR containing llvm-objdump")
        endif()
        execute_process(COMMAND "${_baseline_objdump}" --version
            RESULT_VARIABLE _baseline_objdump_result OUTPUT_VARIABLE _baseline_objdump_version)
        if(NOT _baseline_objdump_result EQUAL 0 OR NOT _baseline_objdump_version MATCHES "LLVM")
            message(FATAL_ERROR "TOOIE_BASELINE_MACHO_TOOLS_DIR/llvm-objdump must be LLVM objdump")
        endif()
        set(_baseline_binding_format --format macho)
        set(_baseline_binding_tools "${TOOIE_BASELINE_MACHO_TOOLS_DIR}")
    else()
        set(_baseline_binding_format)
        set(_baseline_binding_tools "${TOOIE_DEPS_ROOT}/LLVM-19.1.3-Windows-X64/bin")
    endif()
    set(_baseline_binding_tool "${CMAKE_SOURCE_DIR}/tools/baseline/verify_baseline_binding.py")
    set(_baseline_qualification "${CMAKE_BINARY_DIR}/baseline/raw-qualification/qualified.json")
    set(_baseline_native_receipt "${CMAKE_BINARY_DIR}/baseline/raw-qualification/native.json")
    list(LENGTH _baseline_guest _baseline_raw_count)
    set(_baseline_binding_args ${_baseline_binding_format} --build "${CMAKE_BINARY_DIR}" --raw "${TOOIE_BASELINE_GENERATED_DIR}"
        --archive "$<TARGET_FILE:BaselineRecompiledFuncs>" --tools "${_baseline_binding_tools}"
        --snapshot "${_baseline_qualification}" --expected-count "${_baseline_raw_count}")
    add_custom_target(BaselineRawContentGate
        COMMAND "${Python3_EXECUTABLE}" "${_baseline_binding_tool}" archive ${_baseline_binding_args}
        DEPENDS BaselineRecompiledFuncs VERBATIM)
    add_dependencies(TooieBaseline BaselineRawContentGate)
    add_custom_command(TARGET TooieBaseline POST_BUILD
        COMMAND "${Python3_EXECUTABLE}" "${_baseline_binding_tool}" native ${_baseline_binding_args}
            --exe "$<TARGET_FILE:TooieBaseline>" --map "${_baseline_map}" --receipt "${_baseline_native_receipt}"
        VERBATIM)
    if(_baseline_posix)
        # launch_engineering.py is Windows-only; POSIX hosts run the embedded guest equality gate at link.
        add_custom_command(TARGET TooieBaseline POST_BUILD
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/baseline/verify_guest_binding.py"
                ${_baseline_binding_format} --build "${CMAKE_BINARY_DIR}" "$<TARGET_FILE:TooieBaseline>" "${_baseline_map}"
                "${_baseline_bridge_dir}/boot.bin" "${_baseline_bridge_dir}/render_bridge_layout.h"
            VERBATIM)
    endif()
endif()

if(NOT _baseline_posix)
    # Original RT64 exposes bare SDL2/SDL2main imports from its directory scope.
    target_link_directories(TooieBaseline PRIVATE "${_baseline_sdl}/lib/x64")
    add_custom_command(TARGET TooieBaseline POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_sdl}/lib/x64/SDL2.dll" "$<TARGET_FILE_DIR:TooieBaseline>"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_dxc}/dxcompiler.dll" "$<TARGET_FILE_DIR:TooieBaseline>"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_dxc}/dxil.dll" "$<TARGET_FILE_DIR:TooieBaseline>"
        VERBATIM)
endif()
message(STATUS "Baseline: declared runtime sources + RT64 generic repairs=${TOOIE_BASELINE_RT64_GENERIC_FIXES}; raw=${TOOIE_BASELINE_GENERATED_DIR}; fatal carriers=${TOOIE_BASELINE_FATAL_PROVIDERS}; fatal imports=${TOOIE_BASELINE_FATAL_IMPORTS}")
message(STATUS "Baseline boot patch=${TOOIE_BASELINE_BOOT_PATCH_DIR}; boot PI=${TOOIE_BASELINE_BOOT_PI}; observer=${TOOIE_BASELINE_BOOT_OBSERVER}")
enable_testing()
add_executable(platform_support_test EXCLUDE_FROM_ALL tests/platform_support_test.cpp src/platform_support.cpp)
target_include_directories(platform_support_test PRIVATE src)
target_link_libraries(platform_support_test PRIVATE ${_baseline_platform_libraries})
set_target_properties(platform_support_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
add_test(NAME platform_support COMMAND platform_support_test "${CMAKE_BINARY_DIR}/baseline/platform-support-test")
if(TOOIE_BASELINE_PLAYER)
    if(_baseline_posix)
        # mkdtemp under the system temp folder; drvfs rejects required no-replace rename.
        add_test(NAME baseline_player_startup COMMAND BaselinePlayerStartupTest)
    else()
        add_test(NAME baseline_player_startup COMMAND BaselinePlayerStartupTest "${CMAKE_BINARY_DIR}/baseline/player-test")
    endif()
    set_tests_properties(baseline_player_startup PROPERTIES TIMEOUT 30)
    add_executable(baseline_input_host_test EXCLUDE_FROM_ALL
        tests/baseline_input_host_test.cpp tools/baseline/minimum_host.cpp
        tools/baseline/issue_evidence.cpp src/platform_support.cpp
        src/frontend_input_preference.cpp src/frontend_config.cpp src/widescreen.cpp src/virtual_clock.cpp)
    target_compile_definitions(baseline_input_host_test PRIVATE BASELINE_PLAYER=1 SDL_MAIN_HANDLED NOMINMAX)
    target_compile_options(baseline_input_host_test PRIVATE -UNDEBUG)
    _baseline_force_include(baseline_input_host_test "${CMAKE_SOURCE_DIR}/tests/baseline_input_focus.h")
    target_include_directories(baseline_input_host_test PRIVATE
        "${CMAKE_SOURCE_DIR}/tools/baseline" "${CMAKE_SOURCE_DIR}/src"
        "${_baseline_rt64}/src/contrib" "${_player_generated}" "${SDL2_INCLUDE_DIRS}"
        "${RUNTIME_RECOMP_INCLUDE}" "${RUNTIME_ROOT}/ultramodern/include")
    target_link_libraries(baseline_input_host_test PRIVATE
        ${_baseline_sdl_link} ${_baseline_startup_libraries} ${_baseline_platform_libraries})
    set_target_properties(baseline_input_host_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    if(NOT _baseline_posix)
        add_custom_command(TARGET baseline_input_host_test POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_sdl}/lib/x64/SDL2.dll"
                "$<TARGET_FILE_DIR:baseline_input_host_test>" VERBATIM)
    endif()
    add_test(NAME baseline_input_host COMMAND baseline_input_host_test)
    set_tests_properties(baseline_input_host PROPERTIES ENVIRONMENT "SDL_VIDEODRIVER=dummy" TIMEOUT 30)
    add_executable(baseline_output_rate_test EXCLUDE_FROM_ALL tests/baseline_output_rate_test.cpp
        tools/baseline/minimum_presentation.cpp src/widescreen.cpp
        tools/baseline/issue_evidence.cpp src/platform_support.cpp)
    target_link_libraries(baseline_output_rate_test PRIVATE ${_baseline_platform_libraries})
    target_link_libraries(baseline_output_rate_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_output_rate_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_output_rate_test PRIVATE BASELINE_PLAYER=1 NOMINMAX HLSL_CPU SDL_MAIN_HANDLED)
    target_compile_options(baseline_output_rate_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_output_rate_test PRIVATE src tools/baseline
        "${CMAKE_SOURCE_DIR}/tools/baseline/guest/minimum-host"
        "${RUNTIME_ROOT}/ultramodern/include" "${RUNTIME_RECOMP_INCLUDE}"
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
        "${RUNTIME_ROOT}/thirdparty"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume"
        ${SDL2_INCLUDE_DIRS})
    set_target_properties(baseline_output_rate_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    add_test(NAME baseline_output_rate COMMAND baseline_output_rate_test)
    add_executable(baseline_issue_evidence_test EXCLUDE_FROM_ALL tests/baseline_issue_evidence_test.cpp
        src/platform_support.cpp)
    target_compile_definitions(baseline_issue_evidence_test PRIVATE BASELINE_PLAYER=1 NOMINMAX)
    target_compile_options(baseline_issue_evidence_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_issue_evidence_test PRIVATE src tools/baseline "${_baseline_rt64}/src/contrib")
    target_link_libraries(baseline_issue_evidence_test PRIVATE Threads::Threads ${_baseline_platform_libraries})
    set_target_properties(baseline_issue_evidence_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/baseline/issue-evidence-test")
    add_test(NAME baseline_issue_evidence COMMAND baseline_issue_evidence_test "${CMAKE_BINARY_DIR}/baseline/issue-evidence-test")
    set_tests_properties(baseline_issue_evidence PROPERTIES TIMEOUT 30)
    add_executable(baseline_issue_evidence_guest_test EXCLUDE_FROM_ALL tests/baseline_issue_evidence_guest_test.cpp)
    target_compile_definitions(baseline_issue_evidence_guest_test PRIVATE NOMINMAX)
    target_include_directories(baseline_issue_evidence_guest_test PRIVATE tools/baseline
        "${RUNTIME_RECOMP_INCLUDE}" "${_baseline_bridge_dir}")
    set_target_properties(baseline_issue_evidence_guest_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    add_test(NAME baseline_issue_evidence_guest COMMAND baseline_issue_evidence_guest_test)
    # Visible-branch continuity (bk_pipeline.h): selector choice, appearance rows, body latch, direct commit.
    add_executable(baseline_bk_branch_history_test EXCLUDE_FROM_ALL tests/baseline_bk_branch_history_test.cpp)
    target_compile_definitions(baseline_bk_branch_history_test PRIVATE NOMINMAX)
    target_compile_options(baseline_bk_branch_history_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_bk_branch_history_test PRIVATE tools/baseline)
    set_target_properties(baseline_bk_branch_history_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    add_test(NAME baseline_bk_branch_history COMMAND baseline_bk_branch_history_test)
endif()
if(TOOIE_BASELINE_CORE1_PUBLICATION)
    add_test(NAME baseline_guest_digest COMMAND BaselineGuestDigestTest)
endif()

if(TOOIE_BASELINE_RT64_GENERIC_FIXES)
    # Reuse the maintained S20 fixture against this baseline's actual RT64 archive.
    add_executable(baseline_rt64_owner_S_test tests/rt64_scene_match_policy_test.cpp)
    target_link_libraries(baseline_rt64_owner_S_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_rt64_owner_S_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_rt64_owner_S_test PRIVATE TOOIE_V10_ARM=0 HLSL_CPU)
    target_compile_options(baseline_rt64_owner_S_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_rt64_owner_S_test PRIVATE src
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume")
    set(_baseline_owner_map "${CMAKE_BINARY_DIR}/baseline/rt64_generic/S_RETAINED.map")
    # verify_rt64_generic_map.py is MSVC-only; on ELF this registered test fails closed until ported.
    _baseline_link_map(baseline_rt64_owner_S_test "${_baseline_owner_map}")
    add_test(NAME baseline_rt64_owner_S COMMAND baseline_rt64_owner_S_test)
    add_test(NAME baseline_rt64_owner_map COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tools/baseline/verify_rt64_generic_map.py" --map "${_baseline_owner_map}")

    # Same-scene projection eligibility regression against the sole selected archive.
    add_executable(baseline_rt64_projection_match_test tests/rt64_projection_match_test.cpp)
    target_link_libraries(baseline_rt64_projection_match_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_rt64_projection_match_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_rt64_projection_match_test PRIVATE TOOIE_V10_ARM=0 HLSL_CPU)
    target_compile_options(baseline_rt64_projection_match_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_rt64_projection_match_test PRIVATE "${CMAKE_SOURCE_DIR}" src
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume")
    set(_baseline_projection_map "${CMAKE_BINARY_DIR}/baseline/rt64_generic/PROJECTION_REUSE.map")
    _baseline_link_map(baseline_rt64_projection_match_test "${_baseline_projection_map}")
    add_test(NAME baseline_rt64_projection_match COMMAND baseline_rt64_projection_match_test)
    add_test(NAME baseline_rt64_projection_match_map COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_SOURCE_DIR}/tools/baseline/verify_rt64_generic_map.py" --map "${_baseline_projection_map}")

    # Preserve the combined projection supplied by the guest at frame endpoints.
    add_executable(baseline_rt64_projection_preservation_test tests/rt64_projection_preservation_test.cpp)
    target_link_libraries(baseline_rt64_projection_preservation_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_rt64_projection_preservation_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_rt64_projection_preservation_test PRIVATE
        TOOIE_V10_ARM=0 HLSL_CPU TOOIE_RT64_PROJECTION_RESIDUAL_ONLY=1)
    target_compile_options(baseline_rt64_projection_preservation_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_rt64_projection_preservation_test PRIVATE src
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume")
    add_test(NAME baseline_rt64_projection_preservation COMMAND baseline_rt64_projection_preservation_test)
    if(NOT _baseline_posix)
        add_custom_command(TARGET baseline_rt64_projection_preservation_test POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_sdl}/lib/x64/SDL2.dll" "$<TARGET_FILE_DIR:baseline_rt64_projection_preservation_test>"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_dxc}/dxcompiler.dll" "$<TARGET_FILE_DIR:baseline_rt64_projection_preservation_test>"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_baseline_dxc}/dxil.dll" "$<TARGET_FILE_DIR:baseline_rt64_projection_preservation_test>"
            VERBATIM)
    endif()

    # Six-F4 BK float camera route: camera_float.h against E443C's product and RT64's routing.
    add_executable(baseline_menu_scope_test tests/baseline_menu_scope_test.cpp)
    target_compile_options(baseline_menu_scope_test PRIVATE -UNDEBUG)
    add_test(NAME baseline_menu_scope COMMAND baseline_menu_scope_test)
    add_executable(baseline_transition_scope_test tests/baseline_transition_scope_test.cpp)
    target_compile_options(baseline_transition_scope_test PRIVATE -UNDEBUG)
    add_test(NAME baseline_transition_scope COMMAND baseline_transition_scope_test)
    add_executable(baseline_camera_float_test tests/baseline_camera_float_test.cpp)
    target_link_libraries(baseline_camera_float_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_camera_float_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_camera_float_test PRIVATE HLSL_CPU)
    target_compile_options(baseline_camera_float_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_camera_float_test PRIVATE
        "${CMAKE_SOURCE_DIR}/tools/baseline/guest/camera-candidate"
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/contrib"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume")
    add_test(NAME baseline_camera_float COMMAND baseline_camera_float_test)
endif()
if(TOOIE_BASELINE_MATRIX_TRACE)
    # F4 player correspondence rows: collector against synthetic RT64 draw data and frame maps.
    add_executable(baseline_rt64_player_rows_test EXCLUDE_FROM_ALL tests/baseline_rt64_player_rows_test.cpp)
    target_link_libraries(baseline_rt64_player_rows_test PRIVATE rt64)
    if(NOT _baseline_posix)
        target_link_directories(baseline_rt64_player_rows_test PRIVATE "${_baseline_sdl}/lib/x64")
    endif()
    target_compile_definitions(baseline_rt64_player_rows_test PRIVATE HLSL_CPU NOMINMAX)
    target_compile_options(baseline_rt64_player_rows_test PRIVATE -UNDEBUG)
    target_include_directories(baseline_rt64_player_rows_test PRIVATE src tools/baseline
        "${_baseline_rt64}/src" "${_baseline_rt64}/src/hle" "${_baseline_rt64}/src/render"
        "${_baseline_rt64}/src/common" "${_baseline_rt64}/src/contrib"
        "${_baseline_rt64}/src/contrib/hlslpp/include" "${_baseline_rt64}/src/contrib/plume")
    add_test(NAME baseline_rt64_player_rows COMMAND baseline_rt64_player_rows_test)
endif()
if(TOOIE_BASELINE_LIFECYCLE_FIXTURE)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_baseline_lifecycle_dir "${CMAKE_BINARY_DIR}/baseline/lifecycle")
    set(_baseline_lifecycle_input "${CMAKE_BINARY_DIR}/baseline/thread-refusals/threads.cpp")
    set(_baseline_lifecycle_mode --baseline-threads-only)
    set(_baseline_lifecycle_sources "${_baseline_lifecycle_dir}/threads.cpp")
    set(_baseline_lifecycle_patches "${_baseline_lifecycle_dir}/threads.patch")
    if(TOOIE_BASELINE_EXTERNAL_WAIT_FIXTURE)
        set(_baseline_lifecycle_mode --baseline-external-wait)
        list(APPEND _baseline_lifecycle_sources "${_baseline_lifecycle_dir}/mesgqueue.cpp")
        list(APPEND _baseline_lifecycle_patches "${_baseline_lifecycle_dir}/mesgqueue.patch")
    endif()
    if(NOT TOOIE_BASELINE_TERMINAL_FENCE)
    add_custom_command(OUTPUT ${_baseline_lifecycle_sources}
        BYPRODUCTS ${_baseline_lifecycle_patches} "${_baseline_lifecycle_dir}/manifest.json"
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/prepare_runtime_continuous.py"
            ${_baseline_lifecycle_mode} --runtime "${RUNTIME_ROOT}"
            --cleanup-threads "${_baseline_lifecycle_input}" --output-directory "${_baseline_lifecycle_dir}"
        DEPENDS tools/prepare_runtime_continuous.py patches/runtime/producer-quiescent-cleanup.patch
            patches/runtime/mesgqueue-lifecycle-wait.patch "${_baseline_lifecycle_input}" "${RUNTIME_ROOT}/ultramodern/src/threads.cpp"
            "${RUNTIME_ROOT}/ultramodern/src/mesgqueue.cpp" VERBATIM)
    endif()
    add_executable(continuous_lifecycle_test EXCLUDE_FROM_ALL tests/continuous_lifecycle_test.cpp
        ${_baseline_lifecycle_sources} src/runtime_lifecycle.cpp)
    # Copy the selected native target's effective settings, without duplicating
    # inherited directory options or changing any shared target property.
    foreach(_property IN ITEMS COMPILE_OPTIONS COMPILE_DEFINITIONS CXX_STANDARD
        CXX_STANDARD_REQUIRED CXX_EXTENSIONS MSVC_RUNTIME_LIBRARY POSITION_INDEPENDENT_CODE)
        get_target_property(_native_property ultramodern ${_property})
        if(NOT _native_property STREQUAL "_native_property-NOTFOUND")
            set_property(TARGET continuous_lifecycle_test PROPERTY ${_property} "${_native_property}")
        endif()
    endforeach()
    get_target_property(_native_includes ultramodern INCLUDE_DIRECTORIES)
    target_include_directories(continuous_lifecycle_test BEFORE PRIVATE ${_native_includes} "${CMAKE_SOURCE_DIR}/src")
    set_source_files_properties(tests/continuous_lifecycle_test.cpp PROPERTIES
        COMPILE_DEFINITIONS TOOIE_BASELINE_LIFECYCLE_NO_TIMERS=1)
    target_link_libraries(continuous_lifecycle_test PRIVATE librecomp ultramodern
        Threads::Threads ${_baseline_platform_libraries})
    set_target_properties(continuous_lifecycle_test PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    if(MSVC)
        target_link_options(continuous_lifecycle_test PRIVATE "/MAP:${CMAKE_BINARY_DIR}/baseline/lifecycle/continuous_lifecycle_test.map")
    endif()
    foreach(mode IN ITEMS normal parked failure create-stop)
        add_test(NAME continuous_lifecycle_${mode} COMMAND continuous_lifecycle_test ${mode})
        set_tests_properties(continuous_lifecycle_${mode} PROPERTIES TIMEOUT 15)
    endforeach()
    if(TOOIE_BASELINE_EXTERNAL_WAIT_FIXTURE)
        add_test(NAME continuous_lifecycle_external-wait COMMAND continuous_lifecycle_test external-wait)
        set_tests_properties(continuous_lifecycle_external-wait PROPERTIES TIMEOUT 15)
    endif()
endif()

if(TOOIE_BASELINE_SAVE_DRAIN_FIXTURE OR TOOIE_BASELINE_SAVE_COMPOSITION)
    if(NOT TOOIE_BASELINE_TERMINAL_FENCE)
        message(FATAL_ERROR "Saver fixture consumes the selected terminal-fence runtime children")
    endif()
    if(NOT TOOIE_BASELINE_VI_CONTROLLER_CYCLE)
        message(FATAL_ERROR "Saver fixture requires the selected VI/controller baseline graph")
    endif()
    set(_baseline_save_child "${CMAKE_BINARY_DIR}/runtime-continuous/pi.cpp")
    file(SHA256 "${_baseline_save_child}" _baseline_save_sha)
    if(NOT _baseline_save_sha STREQUAL "e44d154c455cbd1d4d9a1cf61dc9d4c2ca74274b1515f6c0f23e735ce7a868ba")
        message(FATAL_ERROR "Existing saver materialization differs from the reviewed child")
    endif()
    # The unchanged fixture includes full PI; lazy archives must supply no second PI owner.
    add_executable(continuous_save_drain_test EXCLUDE_FROM_ALL tests/continuous_save_drain_test.cpp
        src/runtime_lifecycle.cpp src/runtime_save_root.cpp)
    set_source_files_properties(tests/continuous_save_drain_test.cpp PROPERTIES
        COMPILE_DEFINITIONS "TOOIE_SAVE_RUNTIME_SOURCE=\"${_baseline_save_child}\"")
    foreach(_property IN ITEMS COMPILE_OPTIONS COMPILE_DEFINITIONS CXX_STANDARD
        CXX_STANDARD_REQUIRED CXX_EXTENSIONS MSVC_RUNTIME_LIBRARY POSITION_INDEPENDENT_CODE)
        get_target_property(_native_property librecomp ${_property})
        if(NOT _native_property STREQUAL "_native_property-NOTFOUND")
            set_property(TARGET continuous_save_drain_test PROPERTY ${_property} "${_native_property}")
        endif()
    endforeach()
    get_target_property(_native_includes librecomp INCLUDE_DIRECTORIES)
    target_include_directories(continuous_save_drain_test BEFORE PRIVATE ${_native_includes} "${CMAKE_SOURCE_DIR}/src")
    target_link_libraries(continuous_save_drain_test PRIVATE librecomp ultramodern
        Threads::Threads ${_baseline_platform_libraries})
    set_target_properties(continuous_save_drain_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_baseline_executable_dir}")
    if(MSVC)
        target_link_options(continuous_save_drain_test PRIVATE "/MAP:${_baseline_executable_dir}/continuous_save_drain_test.map")
    endif()
    foreach(mode IN ITEMS final-write wait-producer disabled empty write-failure owned-admitted owned-refused startup-held owned-failure)
        add_test(NAME continuous_save_drain_${mode} COMMAND continuous_save_drain_test ${mode}
            "${CMAKE_BINARY_DIR}/baseline/save-drain-fixture/${mode}/save.bin")
        set_tests_properties(continuous_save_drain_${mode} PROPERTIES TIMEOUT 15)
    endforeach()
endif()

if(TOOIE_BASELINE_LIFECYCLE_FIXTURE AND
   TOOIE_BASELINE_EXTERNAL_WAIT_FIXTURE AND
   TOOIE_BASELINE_SAVE_DRAIN_FIXTURE)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_ws_dir "${CMAKE_BINARY_DIR}/baseline/wait-save-composition")
    set(_ws_threads "${CMAKE_BINARY_DIR}/baseline/lifecycle/threads.cpp")
    set(_ws_pi "${CMAKE_BINARY_DIR}/runtime-continuous/pi.cpp")
    file(SHA256 "${_ws_threads}" _ws_threads_sha)
    file(SHA256 "${_ws_pi}" _ws_pi_sha)
    if(NOT _ws_threads_sha STREQUAL "a1227291c933fa003706575e407ad8b0a469f04fe44125b7de03ad16faff8469"
       OR NOT _ws_pi_sha STREQUAL "e44d154c455cbd1d4d9a1cf61dc9d4c2ca74274b1515f6c0f23e735ce7a868ba")
        message(FATAL_ERROR "Wait/save fixture owner pins differ")
    endif()
    add_custom_command(
        OUTPUT "${_ws_dir}/mesgqueue.cpp" "${_ws_dir}/runtime_lifecycle.cpp"
        BYPRODUCTS "${_ws_dir}/manifest.json"
        COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/tools/baseline/prepare_wait_save_composition_fixture.py"
            --source-root "${CMAKE_SOURCE_DIR}"
            --binary-root "${CMAKE_BINARY_DIR}"
            --output-directory "${_ws_dir}"
        DEPENDS tools/baseline/prepare_wait_save_composition_fixture.py
            "${CMAKE_BINARY_DIR}/baseline/lifecycle/mesgqueue.cpp"
            src/runtime_lifecycle.cpp
        VERBATIM)
    add_executable(continuous_wait_save_composition_test EXCLUDE_FROM_ALL
        tests/continuous_wait_save_composition_test.cpp
        "${_ws_threads}" "${_ws_dir}/mesgqueue.cpp"
        "${_ws_dir}/runtime_lifecycle.cpp" src/runtime_save_root.cpp)
    set_source_files_properties(tests/continuous_wait_save_composition_test.cpp
        PROPERTIES COMPILE_DEFINITIONS
        "TOOIE_SAVE_RUNTIME_SOURCE=\"${_ws_pi}\";TOOIE_BASELINE_LIFECYCLE_NO_TIMERS=1")
    foreach(_property IN ITEMS COMPILE_OPTIONS COMPILE_DEFINITIONS CXX_STANDARD
            CXX_STANDARD_REQUIRED CXX_EXTENSIONS MSVC_RUNTIME_LIBRARY POSITION_INDEPENDENT_CODE)
        get_target_property(_native_property librecomp ${_property})
        if(NOT _native_property STREQUAL "_native_property-NOTFOUND")
            set_property(TARGET continuous_wait_save_composition_test
                PROPERTY ${_property} "${_native_property}")
        endif()
    endforeach()
    get_target_property(_ws_lib_includes librecomp INCLUDE_DIRECTORIES)
    get_target_property(_ws_ultra_includes ultramodern INCLUDE_DIRECTORIES)
    target_include_directories(continuous_wait_save_composition_test BEFORE PRIVATE
        ${_ws_lib_includes} ${_ws_ultra_includes} "${CMAKE_SOURCE_DIR}/src")
    target_link_libraries(continuous_wait_save_composition_test PRIVATE
        librecomp ultramodern Threads::Threads ${_baseline_platform_libraries})
    set_target_properties(continuous_wait_save_composition_test PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${_ws_dir}")
    _baseline_link_map(continuous_wait_save_composition_test "${_ws_dir}/continuous_wait_save_composition_test.map")
    add_test(NAME continuous_wait_save_composition
        COMMAND continuous_wait_save_composition_test "${_ws_dir}/run-01")
    set_tests_properties(continuous_wait_save_composition PROPERTIES TIMEOUT 15)
endif()
