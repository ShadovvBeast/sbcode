// src/main.zig — Entry point
//
// Thin entry point that creates a stack-allocated App, initializes it,
// runs the main loop, and exits cleanly.

const w32 = @import("win32");
const App = @import("app").App;

/// Global App instance — stored as a file-level var (static storage) to avoid
/// stack overflow. The App struct is ~50MB+ due to TextBuffer (4MB), SyntaxHighlighter
/// (48MB), etc. Windows default stack is 1MB; even enlarged stacks can't hold it.
/// File-level var is zero-allocation static storage — satisfies the project's
/// "zero heap allocations" constraint.
var app: App = .{};

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

    if (!app.init()) {
        return 1;
    }

    while (app.running) {
        app.tick();
    }

    return 0;
}
