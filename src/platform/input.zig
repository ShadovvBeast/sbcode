// src/platform/input.zig — Per-frame input state (no allocation)
//
// Pure data module: aggregates mouse, keyboard, and text input per frame.
// Zero allocator usage — all storage is stack/comptime sized.

pub const MAX_TEXT_INPUT = 256;
pub const MAX_KEY_EVENTS = 64;

pub const KeyEvent = struct {
    vk: u16,
    scancode: u16,
    pressed: bool,
    ctrl: bool,
    shift: bool,
    alt: bool,
};

pub const InputState = struct {
    // Mouse position
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,

    // Mouse deltas (reset each frame)
    mouse_dx: i32 = 0,
    mouse_dy: i32 = 0,

    // Mouse button held state (persists across frames)
    left_button: bool = false,

    // Mouse button edge triggers (reset each frame)
    left_button_pressed: bool = false,
    left_button_released: bool = false,

    // Scroll (reset each frame)
    scroll_delta: i32 = 0,

    // Keyboard events (reset each frame)
    key_events: [MAX_KEY_EVENTS]KeyEvent = undefined,
    key_event_count: u32 = 0,

    // Text input from WM_CHAR (reset each frame)
    text_input: [MAX_TEXT_INPUT]u8 = undefined,
    text_input_len: u32 = 0,

    /// Reset per-frame transient state. Called at start of each tick.
    /// Keeps mouse_x, mouse_y, and left_button (held state).
    pub fn beginFrame(self: *InputState) void {
        self.left_button_pressed = false;
        self.left_button_released = false;
        self.scroll_delta = 0;
        self.mouse_dx = 0;
        self.mouse_dy = 0;
        self.key_event_count = 0;
        self.text_input_len = 0;
    }

    /// Append a key event. Returns true if stored, false if buffer is full.
    pub fn pushKeyEvent(self: *InputState, event: KeyEvent) bool {
        if (self.key_event_count >= MAX_KEY_EVENTS) return false;
        self.key_events[self.key_event_count] = event;
        self.key_event_count += 1;
        return true;
    }

    /// Append a text input character. Returns true if stored, false if buffer is full.
    pub fn pushTextInput(self: *InputState, char: u8) bool {
        if (self.text_input_len >= MAX_TEXT_INPUT) return false;
        self.text_input[self.text_input_len] = char;
        self.text_input_len += 1;
        return true;
    }
};

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

const testing = @import("std").testing;

test "InputState default initialization" {
    const state = InputState{};
    try testing.expectEqual(@as(i32, 0), state.mouse_x);
    try testing.expectEqual(@as(i32, 0), state.mouse_y);
    try testing.expectEqual(@as(i32, 0), state.mouse_dx);
    try testing.expectEqual(@as(i32, 0), state.mouse_dy);
    try testing.expectEqual(false, state.left_button);
    try testing.expectEqual(false, state.left_button_pressed);
    try testing.expectEqual(false, state.left_button_released);
    try testing.expectEqual(@as(i32, 0), state.scroll_delta);
    try testing.expectEqual(@as(u32, 0), state.key_event_count);
    try testing.expectEqual(@as(u32, 0), state.text_input_len);
}

test "beginFrame resets transient state but keeps position and held button" {
    var state = InputState{};
    // Set up some state
    state.mouse_x = 100;
    state.mouse_y = 200;
    state.mouse_dx = 5;
    state.mouse_dy = -3;
    state.left_button = true;
    state.left_button_pressed = true;
    state.left_button_released = false;
    state.scroll_delta = 120;
    _ = state.pushKeyEvent(.{ .vk = 65, .scancode = 30, .pressed = true, .ctrl = false, .shift = false, .alt = false });
    _ = state.pushTextInput('a');

    state.beginFrame();

    // Persistent state preserved
    try testing.expectEqual(@as(i32, 100), state.mouse_x);
    try testing.expectEqual(@as(i32, 200), state.mouse_y);
    try testing.expectEqual(true, state.left_button);

    // Transient state reset
    try testing.expectEqual(@as(i32, 0), state.mouse_dx);
    try testing.expectEqual(@as(i32, 0), state.mouse_dy);
    try testing.expectEqual(false, state.left_button_pressed);
    try testing.expectEqual(false, state.left_button_released);
    try testing.expectEqual(@as(i32, 0), state.scroll_delta);
    try testing.expectEqual(@as(u32, 0), state.key_event_count);
    try testing.expectEqual(@as(u32, 0), state.text_input_len);
}

test "pushKeyEvent stores events up to capacity" {
    var state = InputState{};
    const event = KeyEvent{ .vk = 65, .scancode = 30, .pressed = true, .ctrl = true, .shift = false, .alt = false };

    // Fill to capacity
    var i: u32 = 0;
    while (i < MAX_KEY_EVENTS) : (i += 1) {
        try testing.expect(state.pushKeyEvent(event));
    }
    try testing.expectEqual(@as(u32, MAX_KEY_EVENTS), state.key_event_count);

    // Verify stored event fields
    try testing.expectEqual(@as(u16, 65), state.key_events[0].vk);
    try testing.expectEqual(true, state.key_events[0].ctrl);

    // Overflow returns false
    try testing.expect(!state.pushKeyEvent(event));
    try testing.expectEqual(@as(u32, MAX_KEY_EVENTS), state.key_event_count);
}

test "pushTextInput stores characters up to capacity" {
    var state = InputState{};

    // Fill to capacity
    var i: u32 = 0;
    while (i < MAX_TEXT_INPUT) : (i += 1) {
        try testing.expect(state.pushTextInput('x'));
    }
    try testing.expectEqual(@as(u32, MAX_TEXT_INPUT), state.text_input_len);

    // Verify stored content
    try testing.expectEqual(@as(u8, 'x'), state.text_input[0]);
    try testing.expectEqual(@as(u8, 'x'), state.text_input[MAX_TEXT_INPUT - 1]);

    // Overflow returns false
    try testing.expect(!state.pushTextInput('y'));
    try testing.expectEqual(@as(u32, MAX_TEXT_INPUT), state.text_input_len);
}

test "pushKeyEvent preserves event data correctly" {
    var state = InputState{};
    const e1 = KeyEvent{ .vk = 0x41, .scancode = 30, .pressed = true, .ctrl = false, .shift = true, .alt = false };
    const e2 = KeyEvent{ .vk = 0x1B, .scancode = 1, .pressed = false, .ctrl = true, .shift = false, .alt = true };

    try testing.expect(state.pushKeyEvent(e1));
    try testing.expect(state.pushKeyEvent(e2));

    try testing.expectEqual(@as(u32, 2), state.key_event_count);
    try testing.expectEqual(@as(u16, 0x41), state.key_events[0].vk);
    try testing.expectEqual(true, state.key_events[0].shift);
    try testing.expectEqual(@as(u16, 0x1B), state.key_events[1].vk);
    try testing.expectEqual(true, state.key_events[1].alt);
}

test "pushTextInput stores sequential characters" {
    var state = InputState{};
    try testing.expect(state.pushTextInput('H'));
    try testing.expect(state.pushTextInput('i'));
    try testing.expectEqual(@as(u32, 2), state.text_input_len);
    try testing.expectEqual(@as(u8, 'H'), state.text_input[0]);
    try testing.expectEqual(@as(u8, 'i'), state.text_input[1]);
}

test "beginFrame allows reuse after reset" {
    var state = InputState{};
    _ = state.pushKeyEvent(.{ .vk = 65, .scancode = 30, .pressed = true, .ctrl = false, .shift = false, .alt = false });
    _ = state.pushTextInput('a');
    state.beginFrame();

    // Can push again after reset
    try testing.expect(state.pushKeyEvent(.{ .vk = 66, .scancode = 48, .pressed = true, .ctrl = false, .shift = false, .alt = false }));
    try testing.expectEqual(@as(u32, 1), state.key_event_count);
    try testing.expectEqual(@as(u16, 66), state.key_events[0].vk);

    try testing.expect(state.pushTextInput('b'));
    try testing.expectEqual(@as(u32, 1), state.text_input_len);
    try testing.expectEqual(@as(u8, 'b'), state.text_input[0]);
}
