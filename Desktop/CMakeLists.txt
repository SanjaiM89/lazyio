cmake_minimum_required(VERSION 3.21)

# Overridable from CI: cmake -DLAZYIO_VERSION=1.2.3 (or 1.2.3-beta.1, 0.0.0-dev).
# project() needs strict X.Y.Z, so derive the numeric prefix for it and keep
# the full string for display/filenames via the LAZYIO_VERSION define.
set(LAZYIO_VERSION "1.0.0" CACHE STRING "Lazyio release version")
string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+" LAZYIO_VERSION_NUM "${LAZYIO_VERSION}")
if(NOT LAZYIO_VERSION_NUM)
  set(LAZYIO_VERSION_NUM "0.0.0")
endif()

project(Lazyio VERSION ${LAZYIO_VERSION_NUM} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# --- Qt 6 packages (all required at runtime on Linux/Windows/macOS) ---
find_package(Qt6 REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2
    Multimedia Network WebSockets Widgets Svg
)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/apibridge.cpp
    src/apibridge.h
    src/traybridge.cpp
    src/traybridge.h
    src/themebridge.h
)

# Windows: GUI subsystem (no console). macOS: bundle with icon.
if(WIN32)
    set(APP_TYPE WIN32)
elseif(APPLE)
    set(APP_TYPE MACOSX_BUNDLE)
    set(MACOSX_BUNDLE_ICON_FILE lazyio.icns)
    set_source_files_properties(resources/icons/lazyio.icns PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
endif()

qt_add_executable(lazyio ${APP_TYPE} ${SOURCES})

qt_add_resources(lazyio "app_resources"
    PREFIX "/"
    FILES
        qml/Main.qml
        qml/js/api.js
        qml/js/fuzzy.js
        qml/components/SideBar.qml
        qml/components/HeaderBar.qml
        qml/components/QueuePanel.qml
        qml/components/PlayerBar.qml
        qml/components/TrackRow.qml
        qml/components/CoverImage.qml
        qml/components/SongMenu.qml
        qml/components/Modals.qml
        qml/components/LyricsPane.qml
        qml/components/Card.qml
        qml/views/HomeView.qml
        qml/views/SongsView.qml
        qml/views/AlbumsView.qml
        qml/views/AlbumDetail.qml
        qml/views/ArtistsView.qml
        qml/views/PlaylistsView.qml
        qml/views/SearchView.qml
        qml/views/VideosView.qml
        qml/views/UploadView.qml
        qml/views/ArtistDetail.qml
        qml/views/PlaylistDetail.qml
        qml/player/FullPlayer.qml
        resources/fonts/PlusJakartaSans.ttf
        resources/fonts/MaterialSymbols.ttf
        resources/icons/png/lazyio-16.png
        resources/icons/png/lazyio-32.png
        resources/icons/png/lazyio-48.png
        resources/icons/png/lazyio-64.png
        resources/icons/png/lazyio-128.png
        resources/icons/png/lazyio-256.png
        resources/icons/png/lazyio-512.png
)

if(APPLE)
    target_sources(lazyio PRIVATE resources/icons/lazyio.icns)
endif()

target_link_libraries(lazyio PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2
    Qt6::Multimedia Qt6::Network Qt6::WebSockets Qt6::Widgets Qt6::Svg
)

target_compile_definitions(lazyio PRIVATE LAZYIO_VERSION="${LAZYIO_VERSION}")

# Linux desktop entry (installs with `cmake --install`)
if(UNIX AND NOT APPLE)
    install(FILES resources/lazyio.desktop DESTINATION share/applications)
    install(FILES resources/icons/png/lazyio-256.png DESTINATION share/icons/hicolor/256x256/apps RENAME lazyio.png)
endif()

install(TARGETS lazyio
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
