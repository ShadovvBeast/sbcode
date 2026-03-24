// src/extensions/siro_agent.zig — Siro AI Agent Extension
//
// The central AI-integrated development extension for SBCode.
// Provides: chat, inline editing, diff review, specs, steering,
// hooks, MCP server management, autocomplete, and account management.
//
// Based on extensions/siro.siro-agent/package.json (88 commands, 27 keybindings).

const ext = @import("extension");

// =============================================================================
// Commands — organized by functional area
// =============================================================================

const commands = [_]ext.CommandContribution{
    // -- Chat & Sessions --
    .{ .id = 5000, .label = "Siro: Focus Chat Input", .shortcut = "Ctrl+Shift+L", .category = .general },
    .{ .id = 5001, .label = "Siro: New Session", .shortcut = "Ctrl+T", .category = .general },
    .{ .id = 5002, .label = "Siro: View Chat History", .category = .general },
    .{ .id = 5003, .label = "Siro: Start New Chat Session", .category = .general },
    .{ .id = 5004, .label = "Siro: Load Chat Session", .category = .general },
    .{ .id = 5005, .label = "Siro: Add Code Block to Chat", .category = .general },
    .{ .id = 5006, .label = "Siro: Next Chat Session Tab", .category = .general },
    .{ .id = 5007, .label = "Siro: Previous Chat Session Tab", .category = .general },
    .{ .id = 5008, .label = "Siro: Close Chat Session Tab", .category = .general },
    .{ .id = 5009, .label = "Siro: Find in Chat", .category = .general },
    .{ .id = 5010, .label = "Siro: Toggle Autonomy Mode", .shortcut = "Ctrl+M", .category = .general },

    // -- Inline Editing & Diff --
    .{ .id = 5020, .label = "Siro: Inline Chat", .shortcut = "Ctrl+I", .category = .editor },
    .{ .id = 5021, .label = "Siro: Accept Diff", .shortcut = "Shift+Ctrl+Enter", .category = .editor },
    .{ .id = 5022, .label = "Siro: Reject Diff", .shortcut = "Shift+Ctrl+Backspace", .category = .editor },
    .{ .id = 5023, .label = "Siro: Accept Diff Block", .shortcut = "Alt+Ctrl+Y", .category = .editor },
    .{ .id = 5024, .label = "Siro: Reject Diff Block", .shortcut = "Alt+Ctrl+N", .category = .editor },
    .{ .id = 5025, .label = "Siro: Quick Edit", .category = .editor },
    .{ .id = 5026, .label = "Siro: Discuss Hunk", .category = .editor },

    // -- Code Actions --
    .{ .id = 5030, .label = "Siro: Write Comments for Code", .category = .edit },
    .{ .id = 5031, .label = "Siro: Write Docstring for Code", .category = .edit },
    .{ .id = 5032, .label = "Siro: Fix Code", .category = .edit },
    .{ .id = 5033, .label = "Siro: Optimize Code", .category = .edit },
    .{ .id = 5034, .label = "Siro: Fix Grammar", .category = .edit },
    .{ .id = 5035, .label = "Siro: Rewrite Range", .category = .edit },

    // -- Agent --
    .{ .id = 5040, .label = "Siro: Ask Agent", .category = .general },
    .{ .id = 5041, .label = "Siro: Cancel Running Agent", .category = .general },
    .{ .id = 5042, .label = "Siro: Clear Output", .category = .general },
    .{ .id = 5043, .label = "Siro: Select Files as Context", .category = .general },
    .{ .id = 5044, .label = "Siro: Record References", .category = .general },

    // -- Autocomplete --
    .{ .id = 5050, .label = "Siro: Toggle Tab Autocomplete", .shortcut = "Ctrl+K Ctrl+A", .category = .editor },

    // -- Specs --
    .{ .id = 5060, .label = "Spec: Create New Spec", .category = .file },
    .{ .id = 5061, .label = "Spec: Delete Spec", .category = .file },
    .{ .id = 5062, .label = "Spec: Rename Spec", .category = .file },
    .{ .id = 5063, .label = "Spec: Navigate to Requirements", .category = .go },
    .{ .id = 5064, .label = "Spec: Navigate to Design", .category = .go },
    .{ .id = 5065, .label = "Spec: Navigate to Tasks", .category = .go },
    .{ .id = 5066, .label = "Spec: Navigate to Bugfix", .category = .go },
    .{ .id = 5067, .label = "Spec: Update Document", .shortcut = "Ctrl+Shift+Enter", .category = .edit },
    .{ .id = 5068, .label = "Spec: Create Document", .category = .edit },
    .{ .id = 5069, .label = "Spec: Run All Tasks", .shortcut = "Ctrl+Alt+Enter", .category = .run },
    .{ .id = 5070, .label = "Spec: Previous Document", .category = .go },
    .{ .id = 5071, .label = "Spec: Next Document", .category = .go },

    // -- Steering --
    .{ .id = 5080, .label = "Steering: Create Initial Steering", .category = .file },
    .{ .id = 5081, .label = "Steering: Create or Import Skills", .category = .file },
    .{ .id = 5082, .label = "Steering: Delete Steering", .category = .file },
    .{ .id = 5083, .label = "Steering: Refine Steering File", .category = .edit },
    .{ .id = 5084, .label = "Steering: Import Steering", .category = .file },
    .{ .id = 5085, .label = "Skills: Delete Skill", .category = .file },

    // -- Hooks --
    .{ .id = 5090, .label = "Hooks: Open Hook UI", .category = .general },
    .{ .id = 5091, .label = "Hooks: Delete Hook", .category = .general },
};

const commands2 = [_]ext.CommandContribution{
    // -- MCP Server Management --
    .{ .id = 5100, .label = "MCP: Open Workspace Config", .category = .general },
    .{ .id = 5101, .label = "MCP: Open User Config", .category = .general },
    .{ .id = 5102, .label = "MCP: Open Active Config", .category = .general },
    .{ .id = 5103, .label = "MCP: Retry Connection", .category = .general },
    .{ .id = 5104, .label = "MCP: Reauthenticate", .category = .general },
    .{ .id = 5105, .label = "MCP: Reconnect Server", .category = .general },
    .{ .id = 5106, .label = "MCP: Disable Server", .category = .general },
    .{ .id = 5107, .label = "MCP: Enable Server", .category = .general },
    .{ .id = 5108, .label = "MCP: Show Logs", .category = .general },
    .{ .id = 5109, .label = "MCP: Test Tool", .category = .general },
    .{ .id = 5110, .label = "MCP: Disable All Server Tools", .category = .general },
    .{ .id = 5111, .label = "MCP: Enable All Server Tools", .category = .general },
    .{ .id = 5112, .label = "MCP: Disable Tool", .category = .general },
    .{ .id = 5113, .label = "MCP: Enable Tool", .category = .general },
    .{ .id = 5114, .label = "MCP: Reset Approved Env Variables", .category = .general },
    .{ .id = 5115, .label = "MCP: Install from Registry", .category = .general },
    .{ .id = 5116, .label = "MCP: Reload Registry", .category = .general },
    .{ .id = 5117, .label = "MCP: Refresh Remote Tools", .category = .general },

    // -- Powers --
    .{ .id = 5120, .label = "Powers: Configure", .category = .general },

    // -- Account & Auth --
    .{ .id = 5130, .label = "Siro: Sign In", .category = .general },
    .{ .id = 5131, .label = "Siro: Delete Account", .category = .general },
    .{ .id = 5132, .label = "Siro: Show Account Dashboard", .category = .general },

    // -- Terminal --
    .{ .id = 5140, .label = "Siro: Debug Terminal", .shortcut = "Ctrl+Shift+R", .category = .terminal },
    .{ .id = 5141, .label = "Siro: Enable Shell Integration", .category = .terminal },

    // -- SCM --
    .{ .id = 5150, .label = "Siro: Generate Commit Message", .category = .general },

    // -- Experiments & Debug --
    .{ .id = 5160, .label = "Siro: Open Experiments", .category = .general },
    .{ .id = 5161, .label = "Siro: Create Debug Log Zip", .category = .general },
    .{ .id = 5162, .label = "Siro: Capture Log", .category = .general },
    .{ .id = 5163, .label = "Siro: Capture LLM Log", .category = .general },
    .{ .id = 5164, .label = "Siro: Reset Onboarding State", .category = .general },
    .{ .id = 5165, .label = "Siro: Set Onboarding State", .category = .general },
    .{ .id = 5166, .label = "Siro: Open Metadata", .category = .general },
    .{ .id = 5167, .label = "Siro: Purge Metadata", .category = .general },
    .{ .id = 5168, .label = "Siro: Execution UI Control", .category = .general },
    .{ .id = 5169, .label = "Siro: Accept Checkpoint Diff", .category = .general },

    // -- Onboarding --
    .{ .id = 5170, .label = "Siro: View Home", .category = .general },
    .{ .id = 5171, .label = "Siro: View Let's Build", .category = .general },
    .{ .id = 5172, .label = "Siro: Start Onboarding", .category = .general },
    .{ .id = 5173, .label = "Siro: Complete Onboarding", .category = .general },
};

// =============================================================================
// Keybindings — most important shortcuts from the 27 in package.json
// =============================================================================

const keybindings = [_]ext.KeybindingContribution{
    // Ctrl+Shift+L — Focus chat input
    .{ .key_code = 0x4C, .ctrl = true, .shift = true, .command_id = 5000 },
    // Ctrl+T — New session (in chat context)
    .{ .key_code = 0x54, .ctrl = true, .command_id = 5001 },
    // Ctrl+M — Toggle autonomy mode
    .{ .key_code = 0x4D, .ctrl = true, .command_id = 5010 },
    // Ctrl+I — Inline chat
    .{ .key_code = 0x49, .ctrl = true, .command_id = 5020 },
    // Shift+Ctrl+Enter — Accept diff
    .{ .key_code = 0x0D, .ctrl = true, .shift = true, .command_id = 5021 },
    // Shift+Ctrl+Backspace — Reject diff
    .{ .key_code = 0x08, .ctrl = true, .shift = true, .command_id = 5022 },
    // Alt+Ctrl+Y — Accept diff block
    .{ .key_code = 0x59, .ctrl = true, .alt = true, .command_id = 5023 },
    // Alt+Ctrl+N — Reject diff block
    .{ .key_code = 0x4E, .ctrl = true, .alt = true, .command_id = 5024 },
    // Ctrl+L — Focus chat (without new session)
    .{ .key_code = 0x4C, .ctrl = true, .command_id = 5000 },
    // Ctrl+Shift+R — Debug terminal
    .{ .key_code = 0x52, .ctrl = true, .shift = true, .command_id = 5140 },
    // Ctrl+Shift+Enter — Spec: Update document (context-dependent)
    .{ .key_code = 0x0D, .ctrl = true, .shift = true, .alt = false, .command_id = 5067 },
    // Ctrl+Alt+Enter — Spec: Run all tasks
    .{ .key_code = 0x0D, .ctrl = true, .alt = true, .command_id = 5069 },
};

// =============================================================================
// Status items
// =============================================================================

const status_items = [_]ext.StatusItemContribution{
    .{
        .id = "siro.agent",
        .label = "Siro",
        .alignment = .right,
        .priority = 200,
        .command_id = 5000,
    },
    .{
        .id = "siro.autonomy",
        .label = "Supervised",
        .alignment = .right,
        .priority = 199,
        .command_id = 5010,
    },
    .{
        .id = "siro.autocomplete",
        .label = "Autocomplete",
        .alignment = .right,
        .priority = 198,
        .command_id = 5050,
    },
};

// =============================================================================
// Extension descriptor
// =============================================================================

// We combine both command arrays at comptime for the extension descriptor.
// Zig comptime allows array concatenation.
const all_commands = commands ++ commands2;

pub const extension = ext.Extension{
    .id = "sbcode.siro-agent",
    .name = "Siro Agent",
    .version = "0.2.54",
    .description = "AI-integrated spec-based development: chat, inline editing, diff review, specs, steering, hooks, MCP, autocomplete",
    .capabilities = .{ .commands = true, .keybindings = true, .status_items = true },
    .commands = &all_commands,
    .keybindings = &keybindings,
    .status_items = &status_items,
};

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "siro_agent extension metadata" {
    // 88 commands total (50 in commands + 38 in commands2)
    try testing.expect(extension.commands.len == 88);
    try testing.expect(extension.keybindings.len == 12);
    try testing.expect(extension.status_items.len == 3);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.keybindings);
    try testing.expect(extension.capabilities.status_items);
}

test "siro_agent command IDs are in 5000 range" {
    for (extension.commands) |cmd| {
        try testing.expect(cmd.id >= 5000);
        try testing.expect(cmd.id < 5200);
    }
}

test "siro_agent keybindings reference valid command IDs" {
    for (extension.keybindings) |kb| {
        var found = false;
        for (extension.commands) |cmd| {
            if (cmd.id == kb.command_id) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

test "siro_agent status items have valid priorities" {
    for (extension.status_items) |si| {
        try testing.expect(si.priority > 0);
        try testing.expect(si.alignment == .right);
    }
}
