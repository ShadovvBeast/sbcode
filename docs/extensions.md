# SBCode Extension Development Guide

SBCode extensions are pure Zig modules compiled directly into the binary. No runtime loading, no JS, no heap allocations. Extensions declare their contributions as comptime data and get wired into the editor at build time.

This guide covers everything you need to write, test, and integrate an extension.

## Quick Start

Create `src/extensions/my_lang.zig`:

```zig
const ext = @import("extension");
const syntax = @import("syntax");

fn tokenizeMyLang(ls: *syntax.LineSyntax, text: []const u8) void {
    // Your tokenizer logic here
    var pos: u16 = 0;
    const len: u16 = @intCast(text.len);
    // ... emit tokens via ls.addToken(start, length, kind)
    _ = pos;
    _ = len;
    ls.addToken(0, @intCast(text.len), .plain);
}

pub const extension = ext.Extension{
    .id = "sbcode.my-lang",
    .name = "My Language",
    .version = "0.1.0",
    .description = "My language support for SBCode",
    .capabilities = .{ .syntax = true },
    .syntax = &.{.{
        .language = .plain_text,  // or add a new LanguageId
        .display_name = "My Language",
        .file_extensions = &.{ ".mylang", ".ml" },
        .line_comment = "//",
        .tokenizer = &tokenizeMyLang,
    }},
};
```

Then follow the [Integration Steps](#integration-steps) to wire it in.

## Architecture

```
src/extension/
    extension.zig    — Core types: Extension, SyntaxContribution, etc.
    manifest.zig     — Comptime list of all extensions

src/extensions/
    zig_lang.zig     — Zig language extension (reference implementation)
    json_lang.zig    — JSON language extension
    my_lang.zig      — Your extension goes here
```

Extensions live in `src/extensions/`. The extension interface lives in `src/extension/`. The manifest in `src/extension/manifest.zig` collects all extensions into a comptime array.

## Extension Descriptor

Every extension exports `pub const extension: Extension`. The `Extension` struct:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `[]const u8` | yes | Unique ID, e.g. `"sbcode.rust-lang"` |
| `name` | `[]const u8` | yes | Display name |
| `version` | `[]const u8` | yes | Semver string |
| `description` | `[]const u8` | no | Short description |
| `capabilities` | `Capabilities` | no | Flags for what you contribute |
| `syntax` | `[]const SyntaxContribution` | no | Language tokenizers |
| `themes` | `[]const ThemeContribution` | no | Color themes |
| `commands` | `[]const CommandContribution` | no | Command palette actions |
| `keybindings` | `[]const KeybindingContribution` | no | Key bindings |
| `snippets` | `[]const SnippetContribution` | no | Code snippets |
| `status_items` | `[]const StatusItemContribution` | no | Status bar items |

### Capabilities

Set the flags for what your extension provides. This is used for filtering and documentation:

```zig
.capabilities = .{
    .syntax = true,
    .commands = true,
    .snippets = true,
    .theme = false,       // default
    .keybindings = false,  // default
    .status_items = false, // default
},
```

## Contribution Points

### Syntax Highlighting

The most common contribution. You provide a tokenizer function that breaks a line of text into colored tokens.

```zig
const my_syntax = ext.SyntaxContribution{
    .language = .python,              // LanguageId enum value
    .display_name = "Python",         // shown in status bar
    .file_extensions = &.{ ".py", ".pyw", ".pyi" },
    .line_comment = "#",              // for toggle-comment
    .block_comment_open = "",         // empty = not supported
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &tokenizePython,
};
```

#### Writing a Tokenizer

A tokenizer receives a `*LineSyntax` and a line of text. It must emit non-overlapping tokens that cover the entire line. Use `ls.addToken(start_col, length, kind)`:

```zig
fn tokenizePython(ls: *syntax.LineSyntax, text: []const u8) void {
    var pos: u16 = 0;
    const len: u16 = @intCast(text.len);

    while (pos < len) {
        const c = text[pos];

        // Line comment: # to end of line
        if (c == '#') {
            ls.addToken(pos, len - pos, .comment);
            return;
        }

        // String literal
        if (c == '"' or c == '\'') {
            const start = pos;
            const quote = c;
            pos += 1;
            while (pos < len and text[pos] != quote) : (pos += 1) {
                if (text[pos] == '\\') pos += 1; // skip escape
            }
            if (pos < len) pos += 1; // closing quote
            ls.addToken(start, pos - start, .string_literal);
            continue;
        }

        // Numbers
        if (c >= '0' and c <= '9') {
            const start = pos;
            while (pos < len and ((text[pos] >= '0' and text[pos] <= '9') or text[pos] == '.')) : (pos += 1) {}
            ls.addToken(start, pos - start, .number_literal);
            continue;
        }

        // Keywords / identifiers
        if (isAlpha(c)) {
            const start = pos;
            while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
            const word = text[start..pos];
            const kind: syntax.TokenKind = if (isPythonKeyword(word)) .keyword else .plain;
            ls.addToken(start, pos - start, kind);
            continue;
        }

        // Everything else: plain
        ls.addToken(pos, 1, .plain);
        pos += 1;
    }
}
```

**Rules:**
- Tokens must be non-overlapping and ordered by `start_col`
- The sum of all token lengths must equal the line length
- Use `MAX_TOKENS_PER_LINE` (128) as the upper bound — `addToken` silently drops tokens beyond this
- Available `TokenKind` values: `plain`, `keyword`, `string_literal`, `number_literal`, `comment`, `type_name`, `function_name`, `operator`, `punctuation`, `preprocessor`, `builtin`

#### Adding a New LanguageId

If your language isn't in the `LanguageId` enum yet, add it to `src/editor/syntax.zig`:

```zig
pub const LanguageId = enum(u8) {
    plain_text,
    zig_lang,
    json_lang,
    // ... existing languages ...
    my_new_lang,  // <-- add here
};
```

### Themes

Provide a complete color palette:

```zig
.themes = &.{.{
    .name = "Monokai",
    .is_dark = true,
    .colors = .{
        .keyword = Color.rgb(0xF9, 0x26, 0x72),       // pink
        .string_literal = Color.rgb(0xE6, 0xDB, 0x74), // yellow
        .comment = Color.rgb(0x75, 0x71, 0x5E),        // gray
        .number_literal = Color.rgb(0xAE, 0x81, 0xFF), // purple
        .function_name = Color.rgb(0xA6, 0xE2, 0x2E),  // green
        .plain = Color.rgb(0xF8, 0xF8, 0xF2),          // white
        // ... override any ThemeColors field
    },
}},
```

### Commands

Register actions that appear in the command palette (Ctrl+Shift+P):

```zig
.commands = &.{
    .{
        .id = 3000,           // unique ID, use 2000+ for extensions
        .label = "Python: Run File",
        .shortcut = "Ctrl+F5",
        .category = .run,
    },
    .{
        .id = 3001,
        .label = "Python: Select Interpreter",
        .category = .general,
    },
},
```

**Command ID ranges:**
- `0–99`: Core workbench commands (reserved)
- `100–599`: Context menu commands (reserved)
- `600–1999`: Menu bar commands (reserved)
- `2000–2999`: Built-in extension commands (Zig, JSON, etc.)
- `3000+`: Community extension commands

### Keybindings

Bind key combinations to command IDs:

```zig
.keybindings = &.{
    .{
        .key_code = 0x74,  // VK_F5
        .ctrl = true,
        .command_id = 3000, // Python: Run File
    },
},
```

Key codes use Win32 virtual key codes (VK_* constants).

### Snippets

Text templates with tab-stop expansion:

```zig
.snippets = &.{
    .{
        .prefix = "def",
        .label = "Function Definition",
        .description = "Python function with docstring",
        .body = "def $1($2):\n    \"\"\"$3\"\"\"\n    $0",
        .language = .python,
    },
},
```

**Tab stop syntax:**
- `$1`, `$2`, `$3`: Tab stops in order
- `$0`: Final cursor position
- Lines separated by `\n`
- Set `.language = null` for snippets available in all languages

### Status Bar Items

Add persistent items to the status bar:

```zig
.status_items = &.{
    .{
        .id = "python.interpreter",
        .label = "Python 3.11",
        .alignment = .right,
        .priority = 100,
        .command_id = 3001,  // click action
    },
},
```

## Integration Steps

After writing your extension file, you need to wire it into the build:

### 1. Add the module to `build.zig`

Find the extension modules section and add:

```zig
const ext_my_lang_mod = b.createModule(.{
    .root_source_file = b.path("src/extensions/my_lang.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{
        .{ .name = "extension", .module = extension_mod },
        .{ .name = "syntax", .module = syntax_mod },
    },
});
```

### 2. Add it to the manifest module's imports

Find `manifest_mod` in `build.zig` and add your module:

```zig
const manifest_mod = b.createModule(.{
    // ...
    .imports = &.{
        .{ .name = "extension", .module = extension_mod },
        .{ .name = "ext_zig_lang", .module = ext_zig_lang_mod },
        .{ .name = "ext_json_lang", .module = ext_json_lang_mod },
        .{ .name = "ext_my_lang", .module = ext_my_lang_mod },  // <-- add
        .{ .name = "syntax", .module = syntax_mod },
    },
});
```

### 3. Add it to the test step's imports

Find the test module list and add:

```zig
.{ .name = "ext_my_lang", .module = ext_my_lang_mod },
```

### 4. Register in the manifest

Edit `src/extension/manifest.zig`:

```zig
const my_lang = @import("ext_my_lang");

pub const extensions = [_]ext.Extension{
    zig_lang.extension,
    json_lang.extension,
    my_lang.extension,      // <-- add
};
```

### 5. Add to test root

Edit `src/tests/root.zig`:

```zig
_ = @import("ext_my_lang");
```

### 6. Build and test

```bash
zig build test    # run all tests including your extension's
zig build         # build the binary with your extension compiled in
```

## Testing Your Extension

Every extension should have embedded tests. At minimum, test:

1. **Metadata correctness** — contribution counts, capability flags
2. **Tokenizer coverage** — tokens must cover the full line with no gaps
3. **Tokenizer correctness** — keywords, strings, comments produce the right `TokenKind`

```zig
const testing = @import("std").testing;
const expect = testing.expect;

test "my_lang tokenizer covers full line" {
    var ls = syntax.LineSyntax{};
    const line = "def foo(): pass";
    extension.syntax[0].tokenizer(&ls, line);

    // Verify full coverage
    var total: u16 = 0;
    for (ls.tokens[0..ls.token_count]) |tok| {
        total += tok.len;
    }
    try expect(total == line.len);
}

test "my_lang tokenizer recognizes keywords" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "def foo():");
    try expect(ls.tokens[0].kind == .keyword);
    try expect(ls.tokens[0].len == 3); // "def"
}
```

The project has property-based test suites in `src/tests/` that verify tokenizer invariants across random inputs. Consider adding one for your language — see `src/tests/syntax_token_coverage_prop_test.zig` for the pattern.

## Coding Standards

Extensions must follow the same standards as the rest of SBCode:

- **Pure Zig 0.15.2+** syntax
- **Zero heap allocations** — all data is comptime const or stack
- **All storage comptime-sized** — no dynamic arrays, no allocators
- **Comptime slices** for contribution arrays (`&.{...}`)
- **No standard library I/O** at runtime
- **Named module imports** via `@import("module_name")`, not file paths

## Reference Extensions

Study the built-in extensions as templates:

- `src/extensions/zig_lang.zig` — Full example with syntax, snippets, and commands
- `src/extensions/json_lang.zig` — Minimal example with syntax and snippets only

## Extension ID Convention

Use reverse-domain style: `sbcode.<name>`. Examples:
- `sbcode.zig-lang`
- `sbcode.python-lang`
- `sbcode.monokai-theme`
- `sbcode.git-integration`

For community extensions: `<author>.<name>`, e.g. `johndoe.toml-lang`.
