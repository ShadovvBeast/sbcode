// src/platform/keybinding.zig — Keybinding registry and dispatch
//
// Pure data module: maps virtual key + modifier combinations to command indices.
// Zero allocator usage — all storage is stack/comptime sized.

pub const MAX_KEYBINDINGS = 512;

pub const Keybinding = struct {
    key_code: u16,
    ctrl: bool,
    shift: bool,
    alt: bool,
    command_index: u16,
};

pub const KeybindingService = struct {
    bindings: [MAX_KEYBINDINGS]Keybinding = undefined,
    binding_count: u32 = 0,

    /// Register a keybinding.
    ///
    /// Preconditions:
    ///   - self.binding_count < MAX_KEYBINDINGS
    ///
    /// Postconditions:
    ///   - Keybinding is appended to self.bindings
    ///   - self.binding_count is incremented
    ///   - Returns true on success, false if registry is full
    pub fn register(self: *KeybindingService, key_code: u16, ctrl: bool, shift: bool, alt: bool, command_index: u16) bool {
        if (self.binding_count >= MAX_KEYBINDINGS) return false;
        self.bindings[self.binding_count] = .{
            .key_code = key_code,
            .ctrl = ctrl,
            .shift = shift,
            .alt = alt,
            .command_index = command_index,
        };
        self.binding_count += 1;
        return true;
    }

    /// Lookup command index for a key event.
    ///
    /// Postconditions:
    ///   - Returns command_index if exact match found (key + all modifiers), null otherwise
    ///   - First match wins (priority by registration order)
    pub fn lookup(self: *const KeybindingService, key_code: u16, ctrl: bool, shift: bool, alt: bool) ?u16 {
        for (self.bindings[0..self.binding_count]) |b| {
            if (b.key_code == key_code and
                b.ctrl == ctrl and
                b.shift == shift and
                b.alt == alt)
            {
                return b.command_index;
            }
        }
        return null;
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
    // Register Ctrl+S → command 0
    try testing.expect(svc.register(0x53, true, false, false, 0));
    try testing.expectEqual(@as(u32, 1), svc.binding_count);

    // Lookup should find it
    const result = svc.lookup(0x53, true, false, false);
    try testing.expect(result != null);
    try testing.expectEqual(@as(u16, 0), result.?);
}

test "lookup returns null for unregistered keybinding" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 0); // Ctrl+S

    // Lookup Ctrl+O — not registered
    try testing.expect(svc.lookup(0x4F, true, false, false) == null);
}

test "lookup requires exact modifier match" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 0); // Ctrl+S

    // Same key, different modifiers → no match
    try testing.expect(svc.lookup(0x53, false, false, false) == null);
    try testing.expect(svc.lookup(0x53, true, true, false) == null);
    try testing.expect(svc.lookup(0x53, true, false, true) == null);
    try testing.expect(svc.lookup(0x53, false, true, false) == null);
}

test "multiple keybindings with different modifiers" {
    var svc = KeybindingService{};
    _ = svc.register(0x53, true, false, false, 10); // Ctrl+S → 10
    _ = svc.register(0x53, true, true, false, 20); // Ctrl+Shift+S → 20

    try testing.expectEqual(@as(u16, 10), svc.lookup(0x53, true, false, false).?);
    try testing.expectEqual(@as(u16, 20), svc.lookup(0x53, true, true, false).?);
}

test "first registered binding wins on duplicate" {
    var svc = KeybindingService{};
    _ = svc.register(0x50, true, false, false, 1); // Ctrl+P → 1
    _ = svc.register(0x50, true, false, false, 2); // Ctrl+P → 2 (duplicate)

    // First match wins
    try testing.expectEqual(@as(u16, 1), svc.lookup(0x50, true, false, false).?);
}

test "register returns false when full" {
    var svc = KeybindingService{};

    // Fill to capacity
    var i: u16 = 0;
    while (i < MAX_KEYBINDINGS) : (i += 1) {
        try testing.expect(svc.register(i, false, false, false, i));
    }
    try testing.expectEqual(@as(u32, MAX_KEYBINDINGS), svc.binding_count);

    // Next register should fail
    try testing.expect(!svc.register(0xFF, false, false, false, 999));
    try testing.expectEqual(@as(u32, MAX_KEYBINDINGS), svc.binding_count);
}

test "lookup on empty service returns null" {
    const svc = KeybindingService{};
    try testing.expect(svc.lookup(0x41, false, false, false) == null);
}

test "register preserves all fields correctly" {
    var svc = KeybindingService{};
    _ = svc.register(0x1B, false, true, true, 42); // Shift+Alt+Escape → 42

    const b = svc.bindings[0];
    try testing.expectEqual(@as(u16, 0x1B), b.key_code);
    try testing.expectEqual(false, b.ctrl);
    try testing.expectEqual(true, b.shift);
    try testing.expectEqual(true, b.alt);
    try testing.expectEqual(@as(u16, 42), b.command_index);
}

test "all modifier combinations are distinguishable" {
    var svc = KeybindingService{};
    // Register all 8 modifier combos for the same key
    _ = svc.register(0x41, false, false, false, 0);
    _ = svc.register(0x41, true, false, false, 1);
    _ = svc.register(0x41, false, true, false, 2);
    _ = svc.register(0x41, false, false, true, 3);
    _ = svc.register(0x41, true, true, false, 4);
    _ = svc.register(0x41, true, false, true, 5);
    _ = svc.register(0x41, false, true, true, 6);
    _ = svc.register(0x41, true, true, true, 7);

    try testing.expectEqual(@as(u16, 0), svc.lookup(0x41, false, false, false).?);
    try testing.expectEqual(@as(u16, 1), svc.lookup(0x41, true, false, false).?);
    try testing.expectEqual(@as(u16, 2), svc.lookup(0x41, false, true, false).?);
    try testing.expectEqual(@as(u16, 3), svc.lookup(0x41, false, false, true).?);
    try testing.expectEqual(@as(u16, 4), svc.lookup(0x41, true, true, false).?);
    try testing.expectEqual(@as(u16, 5), svc.lookup(0x41, true, false, true).?);
    try testing.expectEqual(@as(u16, 6), svc.lookup(0x41, false, true, true).?);
    try testing.expectEqual(@as(u16, 7), svc.lookup(0x41, true, true, true).?);
}
