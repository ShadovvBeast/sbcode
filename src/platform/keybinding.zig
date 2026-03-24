// src/platform/keybinding.zig — Context-aware keybinding registry and dispatch
//
// Pure data module: maps virtual key + modifier combinations to command indices,
// with context-sensitive priority resolution. More specific contexts (editor,
// sidebar, panel) override global bindings for the same key combo.
//
// Zero allocator usage — all storage is stack/comptime sized.

pub const MAX_KEYBINDINGS = 512;

/// Keybinding context — determines when a binding is active.
/// More specific contexts take priority over `.global` when the
/// current focus matches.
pub const Context = enum(u8) {
    /// Always active (lowest priority). Fallback when no specific context matches.
    global = 0,
    /// Active when the text editor area has focus.
    editor = 1,
    /// Active when the sidebar (explorer, search, extensions, etc.) has focus.
    sidebar = 2,
    /// Active when the bottom panel (terminal, output, etc.) has focus.
    panel = 3,
    /// Active when the command palette overlay is open.
    command_palette = 4,
    /// Active when the file picker overlay is open.
    file_picker = 5,
    /// Active when the find/replace overlay is open.
    find_overlay = 6,
    /// Active when the Siro AI panel has focus.
    siro = 7,
};

pub const Keybinding = struct {
    key_code: u16,
    ctrl: bool,
    shift: bool,
    alt: bool,
    command_index: u16,
    context: Context = .global,
};

pub const KeybindingService = struct {
    bindings: [MAX_KEYBINDINGS]Keybinding = undefined,
    binding_count: u32 = 0,

    /// Register a keybinding with explicit context.
    ///
    /// Postconditions:
    ///   - Keybinding is appended to self.bindings
    ///   - Returns true on success, false if registry is full
    pub fn registerCtx(self: *KeybindingService, key_code: u16, ctrl: bool, shift: bool, alt: bool, command_index: u16, context: Context) bool {
        if (self.binding_count >= MAX_KEYBINDINGS) return false;
        self.bindings[self.binding_count] = .{
            .key_code = key_code,
            .ctrl = ctrl,
            .shift = shift,
            .alt = alt,
            .command_index = command_index,
            .context = context,
        };
        self.binding_count += 1;
        return true;
    }

    /// Register a global keybinding (backward-compatible convenience).
    pub fn register(self: *KeybindingService, key_code: u16, ctrl: bool, shift: bool, alt: bool, command_index: u16) bool {
        return self.registerCtx(key_code, ctrl, shift, alt, command_index, .global);
    }

    /// Context-aware lookup. Returns the command for the most specific matching
    /// context. An exact context match always beats a `.global` match.
    ///
    /// Resolution order:
    ///   1. Exact match on (key + modifiers + active_context) → return immediately
    ///   2. Otherwise, fall back to the first `.global` match
    pub fn lookup(self: *const KeybindingService, key_code: u16, ctrl: bool, shift: bool, alt: bool, active_context: Context) ?u16 {
        var global_match: ?u16 = null;
        for (self.bindings[0..self.binding_count]) |b| {
            if (b.key_code == key_code and
                b.ctrl == ctrl and
                b.shift == shift and
                b.alt == alt)
            {
                if (b.context == active_context) {
                    return b.command_index; // exact context wins immediately
                }
                if (b.context == .global and global_match == null) {
                    global_match = b.command_index;
                }
            }
        }
        return global_match;
    }
};

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

const testing = @import("std").testing;

test "KeybindingService default initialization" {
    const svc = KeybindingService{};
    try testing.expectEqual(@as(u32, 0), svc.binding_count);
}

test "register and lookup a single keybinding" {
    var svc = KeybindingService{};
    try testing.expect(svc.register(0x53, true, false, false, 0));
    try testing.expectEqual(@as(u32, 1), svc.binding_count);

    const result = svc.lookup(0x53, true, false, false, .global);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u16, 0), result.?);
}

test "lookup returns null for unregistered keybinding" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 0);
    try testing.expect(svc.lookup(0x4F, true, false, false, .global) == null);
}

test "lookup requires exact modifier match" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 0);

    try testing.expect(svc.lookup(0x53, false, false, false, .global) == null);
    try testing.expect(svc.lookup(0x53, true, true, false, .global) == null);
    try testing.expect(svc.lookup(0x53, true, false, true, .global) == null);
    try testing.expect(svc.lookup(0x53, false, true, false, .global) == null);
}

test "multiple keybindings with different modifiers" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 10);
    _ = svc.register(0x53, true, true, false, 20);

    try testing.expectEqual(@as(u16, 10), svc.lookup(0x53, true, false, false, .global).?);
    try testing.expectEqual(@as(u16, 20), svc.lookup(0x53, true, true, false, .global).?);
}

test "first registered global binding wins on duplicate" {
    var svc = KeybindingService{};
    _ = svc.register(0x50, true, false, false, 1);
    _ = svc.register(0x50, true, false, false, 2);

    try testing.expectEqual(@as(u16, 1), svc.lookup(0x50, true, false, false, .global).?);
}

test "register returns false when full" {
    var svc = KeybindingService{};
    var i: u16 = 0;
    while (i < MAX_KEYBINDINGS) : (i += 1) {
        try testing.expect(svc.register(i, false, false, false, i));
    }
    try testing.expectEqual(@as(u32, MAX_KEYBINDINGS), svc.binding_count);
    try testing.expect(!svc.register(0xFF, false, false, false, 999));
    try testing.expectEqual(@as(u32, MAX_KEYBINDINGS), svc.binding_count);
}

test "lookup on empty service returns null" {
    const svc = KeybindingService{};
    try testing.expect(svc.lookup(0x41, false, false, false, .global) == null);
}

test "register preserves all fields correctly" {
    var svc = KeybindingService{};
    _ = svc.registerCtx(0x1B, false, true, true, 42, .editor);

    const b = svc.bindings[0];
    try testing.expectEqual(@as(u16, 0x1B), b.key_code);
    try testing.expectEqual(false, b.ctrl);
    try testing.expectEqual(true, b.shift);
    try testing.expectEqual(true, b.alt);
    try testing.expectEqual(@as(u16, 42), b.command_index);
    try testing.expectEqual(Context.editor, b.context);
}

test "all modifier combinations are distinguishable" {
    var svc = KeybindingService{};
    _ = svc.register(0x41, false, false, false, 0);
    _ = svc.register(0x41, true, false, false, 1);
    _ = svc.register(0x41, false, true, false, 2);
    _ = svc.register(0x41, false, false, true, 3);
    _ = svc.register(0x41, true, true, false, 4);
    _ = svc.register(0x41, true, false, true, 5);
    _ = svc.register(0x41, false, true, true, 6);
    _ = svc.register(0x41, true, true, true, 7);

    try testing.expectEqual(@as(u16, 0), svc.lookup(0x41, false, false, false, .global).?);
    try testing.expectEqual(@as(u16, 1), svc.lookup(0x41, true, false, false, .global).?);
    try testing.expectEqual(@as(u16, 2), svc.lookup(0x41, false, true, false, .global).?);
    try testing.expectEqual(@as(u16, 3), svc.lookup(0x41, false, false, true, .global).?);
    try testing.expectEqual(@as(u16, 4), svc.lookup(0x41, true, true, false, .global).?);
    try testing.expectEqual(@as(u16, 5), svc.lookup(0x41, true, false, true, .global).?);
    try testing.expectEqual(@as(u16, 6), svc.lookup(0x41, false, true, true, .global).?);
    try testing.expectEqual(@as(u16, 7), svc.lookup(0x41, true, true, true, .global).?);
}

// ---------------------------------------------------------------------------
// Context-aware priority tests
// ---------------------------------------------------------------------------

test "specific context overrides global for same key combo" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 10); // Ctrl+S → 10 (global)
    _ = svc.registerCtx(0x53, true, false, false, 20, .editor); // Ctrl+S → 20 (editor)

    // In editor context, the editor-specific binding wins
    try testing.expectEqual(@as(u16, 20), svc.lookup(0x53, true, false, false, .editor).?);
    // In sidebar context, falls back to global
    try testing.expectEqual(@as(u16, 10), svc.lookup(0x53, true, false, false, .sidebar).?);
    // In global context, returns global
    try testing.expectEqual(@as(u16, 10), svc.lookup(0x53, true, false, false, .global).?);
}

test "context-specific binding without global fallback" {
    var svc = KeybindingService{};
    _ = svc.registerCtx(0x4C, true, true, false, 50, .siro); // Ctrl+Shift+L → 50 (siro only)

    // In siro context, found
    try testing.expectEqual(@as(u16, 50), svc.lookup(0x4C, true, true, false, .siro).?);
    // In editor context, not found (no global fallback)
    try testing.expect(svc.lookup(0x4C, true, true, false, .editor) == null);
}

test "multiple contexts for same key combo" {
    var svc = KeybindingService{};
    _ = svc.register(0x46, true, false, false, 1); // Ctrl+F → 1 (global: find)
    _ = svc.registerCtx(0x46, true, false, false, 2, .editor); // Ctrl+F → 2 (editor: find in file)
    _ = svc.registerCtx(0x46, true, false, false, 3, .sidebar); // Ctrl+F → 3 (sidebar: filter)

    try testing.expectEqual(@as(u16, 2), svc.lookup(0x46, true, false, false, .editor).?);
    try testing.expectEqual(@as(u16, 3), svc.lookup(0x46, true, false, false, .sidebar).?);
    try testing.expectEqual(@as(u16, 1), svc.lookup(0x46, true, false, false, .panel).?); // falls back to global
}

test "global register defaults context to global" {
    var svc = KeybindingService{};
    _ = svc.register(0x42, true, false, false, 99);
    try testing.expectEqual(Context.global, svc.bindings[0].context);
}
