cmake_minimum_required(VERSION 3.20)
project(plasma-vibra VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ── Qt6 / KF6 / Plasma 6 ────────────────────────────────────────────────────
find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick Network DBus Gui)
find_package(KF6 REQUIRED COMPONENTS I18n)
find_package(Plasma REQUIRED)

# ── vibra (bundled CLI via ExternalProject) ──────────────────────────────────
# Build vibra in its own isolated CMake build so its targets don't pollute
# our scope. The resulting binary is copied into contents/bin/vibra.
include(ExternalProject)

ExternalProject_Add(vibra_ext
    SOURCE_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/vibra"
    BINARY_DIR  "${CMAKE_CURRENT_BINARY_DIR}/vibra_build"
    INSTALL_COMMAND ""   # no install, we copy manually
    CMAKE_ARGS
        -DCMAKE_BUILD_TYPE=Release
        -DLIBRARY_ONLY=OFF
    BUILD_BYPRODUCTS
        "${CMAKE_CURRENT_BINARY_DIR}/vibra_build/cli/vibra"
)

# Copy vibra binary into contents/bin/ after it is built
add_custom_command(
    OUTPUT  "${CMAKE_CURRENT_SOURCE_DIR}/contents/bin/vibra"
    DEPENDS vibra_ext
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/contents/bin"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_BINARY_DIR}/vibra_build/cli/vibra"
            "${CMAKE_CURRENT_SOURCE_DIR}/contents/bin/vibra"
    COMMENT "Copying vibra binary into plasmoid contents/bin/"
)

add_custom_target(copy_vibra ALL
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/contents/bin/vibra"
)

# ── QML plugin ───────────────────────────────────────────────────────────────
add_subdirectory(plugin)

# ── Plasmoid package install ─────────────────────────────────────────────────
plasma_install_package(. org.kde.plasma.vibra)
