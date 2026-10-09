# Hurrican — macOS (Apple Silicon) Port: Technical Notes

> Apple Silicon port by @mmoroca & Brave AI, 2026
> Upstream PR: https://github.com/HurricanGame/Hurrican/pull/96

## Summary

Hurrican was previously only tested on Linux and MinGW/Windows. macOS uses an
OpenGL-over-Metal compatibility layer that enforces **core profile**, which broke
several assumptions in the rendering code. Seven changes were needed to get the
game running on Apple Silicon (M1 Pro tested).

## Build

    brew install sdl2 sdl2_image sdl2_mixer cmake libepoxy
    git clone --recurse-submodules https://github.com/mmoroca/Hurrican.git
    cd Hurrican/Hurrican
    mkdir build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/homebrew -DRENDERER=GL3 ..
    cmake --build . --parallel
    cd ..
    ./build/hurrican

## Changes

| # | File | Change | Why |
|---|------|--------|-----|
| 1 | `src/DX8Graphics.cpp` | NULL check for `glGetString(GL_EXTENSIONS)` | Returns NULL on macOS; `strlen(NULL)` → segfault |
| 2 | `src/DX8Graphics.cpp` | Create & bind a VAO after `SDL_GL_CreateContext` | Mandatory in core profile; `glDrawArrays` is a no-op without one |
| 3 | `src/DX8Graphics.cpp` | Upload vertex data to a VBO; use buffer offsets in `glVertexAttribPointer` | Client-side vertex arrays not supported in core profile |
| 4 | `src/SDLPort/cshader.cpp` | `#version 130` → `#version 330` (GL3 path) | macOS only supports 330+; 110/130 are rejected by the Metal backend |
| 5 | `src/SDLPort/cfbo.cpp` | `glActiveTexture(GL_TEXTURE0)` in `CFbo::BindTexture()` | Texture unit was left on `GL_TEXTURE1` from alpha-texture binding; FBO texture bound to wrong unit → black screen |
| 6 | `src/SDLPort/texture.cpp` | `GL_RGBA8` as internal format in `glTexImage2D` | Unsized formats (`GL_RGBA`) not valid as internal format in core profile |
| 7 | `data/shaders/320/shader_render.frag` | `texture2D()` → `texture()` | Renamed in GLSL 330+ |

## App Packaging (`packapp.sh`)

The `packapp.sh` script produces a self-contained `.app` + `.dmg`:

- Embeds all Homebrew dependencies (`libepoxy`, `sdl2-compat`, `sdl2_mixer`,
  `sdl2_image`, `libSDL3`) into `Contents/Frameworks/`
- Rewrites install names to `@rpath` / `@loader_path`
- Includes a `launcher` wrapper script that handles working directory
  (needed because macOS sets CWD to `/` when launching from Finder)
- Generates an `.icns` icon from the game logo
- Ad-hoc code signing (no Developer ID required)
- Produces a DMG with a `README.txt` disclaimer

## Known Limitations

- **Apple Silicon only** (arm64). No universal binary yet.
- **Ad-hoc signed**: first launch requires right-click → Open.
- **No notarization**: Gatekeeper will warn on first open (expected).

## Next Steps

| Priority | Task | Notes |
|----------|------|-------|
| High | Monitor PR #96 upstream | Respond to maintainer feedback if requested |
| High | Add `packapp.sh` to repo + CMake `make app` target | Reproducible DMG generation |
| Medium | GitHub Actions CI (`macos-latest`) | Auto-build + DMG artifact on every release |
| Medium | Universal binary (arm64 + x86_64) | Requires Homebrew for both archs (`/opt/homebrew` + `/usr/local`) |
| Medium | Homebrew Cask | `brew install --cask hurrican` — requires upstream merge first |
| Low | Migrate to `SDL_Renderer` API | Eliminates all core-profile issues (VAO, VBO, shader versions); significant refactor |
| Low | Add macOS to README "Supported platforms" | Upstream decision, suggested in PR description |   