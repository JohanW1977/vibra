find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick Network DBus Gui)

set(PLUGIN_SRCS
    plugin.cpp
    vibrabackend.cpp
)

add_library(plasma_vibra_plugin SHARED ${PLUGIN_SRCS})

target_link_libraries(plasma_vibra_plugin
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::DBus
    Qt6::Gui
    KF6::I18n
)

set_target_properties(plasma_vibra_plugin PROPERTIES
    AUTOMOC ON
)

target_compile_definitions(plasma_vibra_plugin PRIVATE
    QT_SIGNALS_SLOTS_KEYWORDS
)

# Install the plugin next to the plasmoid so Plasma 6 can find it via the
# package's "imports" search path: contents/imports/org/kde/plasma/vibra/
set(PLUGIN_INSTALL_DIR
    "${KDE_INSTALL_FULL_DATADIR}/plasma/plasmoids/org.kde.plasma.vibra/contents/imports/org/kde/plasma/vibra"
)

install(TARGETS plasma_vibra_plugin DESTINATION "${PLUGIN_INSTALL_DIR}")
install(FILES qmldir              DESTINATION "${PLUGIN_INSTALL_DIR}")
