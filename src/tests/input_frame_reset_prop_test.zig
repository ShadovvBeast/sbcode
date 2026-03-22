// Property-based test for InputState frame reset
// **Validates: Requirement 15.1**
//
// Property 18: InputState Frame Reset
// For any InputState with arbitrary accumulated values, calling beginFrame
// shall reset all per-frame transient state: left_button_pressed and
// left_button_released to false, key_event_count and text_input_len to 0,
// scroll_delta to 0, and mouse_dx and mouse_dy to 0.
// Persistent state (mouse_x, mouse_y, left_button) must be preserved.

const std = @import("std");
const input = @import("input");
const InputState = input.InputState;
const KeyEvent = input.KeyEvent;
const expect = std.testing.expect;

// --- Custom comptime LCG-based pseudo-random generator (zero dependencies) ---

const Lcg = struct {
    state: u64,

    const A: u64 = 6364136223846793005;
    const C: u64 = 1442695040888963407;

    fn init(seed: u64) Lcg {
        return .{ .state = seed };
    }

    fn next(self: *Lcg) u64 {
        self.state = self.state *% A +% C;
        return self.state;
    }

    fn bounded(self: *Lcg, bound: u64) u64 {
        return self.next() % bound;
    }

    fn nextI32(self: *Lcg) i32 {
        return @as(i32, @bitCast(@as(u32, @truncate(self.next()))));
    }

    fn nextBool(self: *Lcg) bool {
        return self.bounded(2) == 0;
    }

    fn nextU8(self: *Lcg) u8 {
        return @as(u8, @truncate(self.next()));
    }

    fn nextU16(self: *Lcg) u16 {
        return @as(u16, @truncate(self.next()));
    }
};

// --- Populate an InputState with random transient state ---

fn populateRandomState(state: *InputState, rng: *Lcg) void {
    // Set persistent state to random values
    state.mouse_x = rng.nextI32();
    state.mouse_y = rng.nextI32();
    state.left_button = rng.nextBool();

    // Set transient state to random non-zero values
    state.mouse_dx = rng.nextI32() | 1; // ensure non-zero
    state.mouse_dy = rng.nextI32() | 1;
    state.left_button_pressed = true;
    state.left_button_released = true;
    state.scroll_delta = rng.nextI32() | 1;

    // Push random key events (1 to MAX_KEY_EVENTS)
    const num_keys = @as(u32, @intCast(rng.bounded(input.MAX_KEY_EVENTS))) + 1;
    var i: u32 = 0;
    while (i < num_keys) : (i += 1) {
        _ = state.pushKeyEvent(.{
            .vk = rng.nextU16(),
            .scancode = rng.nextU16(),
            .pressed = rng.nextBool(),
            .ctrl = rng.nextBool(),
            .shift = rng.nextBool(),
            .alt = rng.nextBool(),
        });
    }

    // Push random text input (1 to MAX_TEXT_INPUT)
    const num_chars = @as(u32, @intCast(rng.bounded(input.MAX_TEXT_INPUT))) + 1;
    var j: u32 = 0;
    while (j < num_chars) : (j += 1) {
        _ = state.pushTextInput(rng.nextU8());
    }
}

// --- Core property test logic ---

fn runFrameResetPropertyTest(rng: *Lcg) !void {
    var state = InputState{};

    // Populate with random transient and persistent state
    populateRandomState(&state, rng);

    // Capture persistent state before reset
    const saved_mouse_x = state.mouse_x;
    const saved_mouse_y = state.mouse_y;
    const saved_left_button = state.left_button;

    // Call beginFrame
    state.beginFrame();

    // 1. mouse_dx == 0 and mouse_dy == 0
    try expect(state.mouse_dx == 0);
    try expect(state.mouse_dy == 0);

    // 2. left_button_pressed == false and left_button_released == false
    try expect(state.left_button_pressed == false);
    try expect(state.left_button_released == false);

    // 3. scroll_delta == 0
    try expect(state.scroll_delta == 0);

    // 4. key_event_count == 0
    try expect(state.key_event_count == 0);

    // 5. text_input_len == 0
    try expect(state.text_input_len == 0);

    // 6. mouse_x, mouse_y, and left_button are PRESERVED
    try expect(state.mouse_x == saved_mouse_x);
    try expect(state.mouse_y == saved_mouse_y);
    try expect(state.left_button == saved_left_button);
}

// --- Property tests across multiple seeds ---

test "Property 18: InputState frame reset — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFrameResetPropertyTest(&rng);
    }
}

test "Property 18: InputState frame reset — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFrameResetPropertyTest(&rng);
    }
}

test "Property 18: InputState frame reset — multiple consecutive resets" {
    // Verify that calling beginFrame multiple times in a row is idempotent
    comptime var seed: u64 = 500;
    inline while (seed < 530) : (seed += 1) {
        var rng = Lcg.init(seed);
        var state = InputState{};
        populateRandomState(&state, &rng);

        const saved_mouse_x = state.mouse_x;
        const saved_mouse_y = state.mouse_y;
        const saved_left_button = state.left_button;

        // Reset multiple times
        state.beginFrame();
        state.beginFrame();
        state.beginFrame();

        // Transient state still reset
        try expect(state.mouse_dx == 0);
        try expect(state.mouse_dy == 0);
        try expect(state.left_button_pressed == false);
        try expect(state.left_button_released == false);
        try expect(state.scroll_delta == 0);
        try expect(state.key_event_count == 0);
        try expect(state.text_input_len == 0);

        // Persistent state still preserved
        try expect(state.mouse_x == saved_mouse_x);
        try expect(state.mouse_y == saved_mouse_y);
        try expect(state.left_button == saved_left_button);
    }
}
