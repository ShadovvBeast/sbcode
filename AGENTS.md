# SBCode Agents Instructions

This file provides instructions for AI coding agents working with the SBCode codebase.

## Project Overview

SBCode is a native code editor written in pure Zig targeting Win32 + OpenGL 1.x. Single binary, zero dependencies, zero heap allocations.

## Architecture

Layered module design — each layer depends only on layers below it:

```
Application    main.zig, app.zig
Workbench      workbench/, layout, command_palette, activity_bar, sidebar, panel, status_bar
Editor         editor/, buffer, cursor, syntax, viewport, tabs
Platform       platform/, file_service, keybinding, config, http, input
Base           base/, ring_buffer, fixed_list, strings, event, rect, color, uri, json
Bindings       platform/win32.zig, platform/gl.zig
```

## Coding Standards

- Pure Zig 0.15.2+ syntax throughout
- Zero heap allocations — all storage is stack or comptime-sized
- `callconv(.c)` for all Win32/GL extern declarations (not `.C`)
- Comptime generics replace dependency injection
- Tagged unions replace polymorphic interfaces
- No standard library I/O at runtime
- All containers are comptime-parameterized with fixed capacity
- Named module imports via `b.createModule` in build.zig

## Module System

All inter-module dependencies are declared in `build.zig` as named imports. Modules reference each other via `@import("module_name")`, not file paths. When adding a new module:

1. Create the source file in the appropriate layer directory
2. Define the module in `build.zig` with `b.createModule`
3. Add it as an import to any modules that depend on it
4. Add it to the test step's imports
5. Add `_ = @import("module_name");` to `src/tests/root.zig`

## Testing

- `zig build test` runs all tests
- 17 property-based test suites in `src/tests/`
- Property tests use a custom comptime LCG pseudo-random generator (no external deps)
- Platform modules with Win32 externs have minimal tests (struct init, constants only)
- Pure data modules have full unit tests and property tests
- Every new data structure should have at least one property test

## Build

```bash
zig build          # Build sbcode.exe
zig build test     # Run all tests
```

Target: x86_64-windows. Links: opengl32, gdi32, user32, kernel32, winhttp, bcrypt. No libc.

## Key Files

- `build.zig` — Build configuration, all module definitions and dependency wiring
- `src/tests/root.zig` — Test root, imports all modules to run their embedded tests
- `src/app.zig` — Application lifecycle, window creation, GL context, main loop
- `src/workbench/workbench.zig` — Central orchestrator, update/render, input dispatch
- `src/platform/win32.zig` — All Win32 type and function declarations
- `src/platform/gl.zig` — All OpenGL 1.x constant and function declarations
