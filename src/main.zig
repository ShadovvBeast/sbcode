// src/main.zig — Entry point
//
// Thin entry point that creates a stack-allocated App, initializes it,
// runs the main loop, and exits cleanly.

const w32 = @import("win32");
const App = @import("app").App;

pub fn wWinMain(
    hInstance: w32.HINSTANCE,
    hPrevInstance: ?w32.HINSTANCE,
    lpCmdLine: [*:0]u16,
    nCmdShow: i32,
) i32 {
    _ = hInstance;
    _ = hPrevInstance;
    _ = lpCmdLine;
    _ = nCmdShow;

    var app: App = .{};

    if (!app.init()) {
        return 1;
    }

    while (app.running) {
        app.tick();
    }

    return 0;
}
