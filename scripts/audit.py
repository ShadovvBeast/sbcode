#!/usr/bin/env python3
"""
SBCode Audit — Missing Feature & Extension Scanner

Scans the Zig codebase to detect missing features, unwired extensions,
and incomplete implementations. Reports actionable findings with
file references and fix instructions.

Extension types and where they live:
  - Language grammars:  src/extensions/<name>_lang.zig  (compiled-in Zig tokenizers)
  - Theme extensions:   src/extensions/theme_<name>.zig (compiled-in ThemeContribution)

All compiled-in extensions follow docs/extensions.md integration steps:
  1. Create src/extensions/<name>.zig
  2. Wire ext_<name>_mod in build.zig
  3. Register in src/extension/manifest.zig
  4. Add to src/tests/root.zig

The extensions/ directory contains VS Code's original extension data (from the
fork). It is reference material, NOT the SBCode implementation. The audit checks
for actual Zig implementations, not the existence of VS Code directories.

Usage:
    python scripts/audit.py

Exit code: 1 if any findings, 0 otherwise.
"""

import os
import re
import sys
from dataclasses import dataclass, field

# ── Config ────────────────────────────────────────────────────────────────────

ZIG_DIRS = ["src/base", "src/editor", "src/platform", "src/renderer",
            "src/workbench", "src/extensions", "src/extension"]
ZIG_APP  = ["src/app.zig", "src/main.zig"]
BUILD    = "build.zig"
TEST_ROOT = "src/tests/root.zig"

RESET = "\033[0m"
BOLD  = "\033[1m"
RED   = "\033[91m"

@dataclass
class Finding:
    category: str
    feature: str
    status: str
    action: str

@dataclass
class State:
    findings: list = field(default_factory=list)
    files: dict = field(default_factory=dict)   # path -> content

def finding(st, category, feature, status, action):
    st.findings.append(Finding(category, feature, status, action))

# ── File loading ──────────────────────────────────────────────────────────────

def load_files(st):
    for d in ZIG_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".zig"):
                path = os.path.join(d, f)
                with open(path, "r", encoding="utf-8", errors="replace") as fh:
                    st.files[path] = fh.read()
    for f in ZIG_APP:
        if os.path.isfile(f):
            with open(f, "r", encoding="utf-8", errors="replace") as fh:
                st.files[f] = fh.read()
    if os.path.isfile(BUILD):
        with open(BUILD, "r", encoding="utf-8", errors="replace") as fh:
            st.files[BUILD] = fh.read()
    if os.path.isfile(TEST_ROOT):
        with open(TEST_ROOT, "r", encoding="utf-8", errors="replace") as fh:
            st.files[TEST_ROOT] = fh.read()

# ── Helpers ───────────────────────────────────────────────────────────────────

def fc(st, filename):
    """Get content by basename."""
    for p, c in st.files.items():
        if p.replace("\\", "/").rsplit("/", 1)[-1] == filename:
            return c
    return ""

def any_has(st, s, case=False):
    for c in st.files.values():
        if case and s in c:
            return True
        if not case and s.lower() in c.lower():
            return True
    return False


# ══════════════════════════════════════════════════════════════════════════════
# EXTENSION CHECKS
# ══════════════════════════════════════════════════════════════════════════════

# Language grammars: each needs a compiled-in Zig tokenizer in src/extensions/
LANGUAGE_EXTENSIONS = {
    "bat":              "bat_lang.zig",
    "clojure":          "clojure_lang.zig",
    "coffeescript":     "coffeescript_lang.zig",
    "cpp":              "cpp_lang.zig",
    "csharp":           "csharp_lang.zig",
    "css":              "css_lang.zig",
    "dart":             "dart_lang.zig",
    "diff":             "diff_lang.zig",
    "docker":           "docker_lang.zig",
    "dotenv":           "dotenv_lang.zig",
    "fsharp":           "fsharp_lang.zig",
    "go":               "go_lang.zig",
    "groovy":           "groovy_lang.zig",
    "handlebars":       "handlebars_lang.zig",
    "hlsl":             "hlsl_lang.zig",
    "html":             "html_lang.zig",
    "ini":              "ini_lang.zig",
    "java":             "java_lang.zig",
    "javascript":       "javascript_lang.zig",
    "json":             "json_lang.zig",
    "julia":            "julia_lang.zig",
    "latex":            "latex_lang.zig",
    "less":             "less_lang.zig",
    "log":              "log_lang.zig",
    "lua":              "lua_lang.zig",
    "make":             "make_lang.zig",
    "markdown":         "markdown_lang.zig",
    "objective-c":      "objc_lang.zig",
    "perl":             "perl_lang.zig",
    "php":              "php_lang.zig",
    "powershell":       "powershell_lang.zig",
    "pug":              "pug_lang.zig",
    "python":           "python_lang.zig",
    "r":                "r_lang.zig",
    "razor":            "razor_lang.zig",
    "restructuredtext": "rst_lang.zig",
    "ruby":             "ruby_lang.zig",
    "rust":             "rust_lang.zig",
    "scss":             "scss_lang.zig",
    "shaderlab":        "shaderlab_lang.zig",
    "shellscript":      "shell_lang.zig",
    "sql":              "sql_lang.zig",
    "swift":            "swift_lang.zig",
    "typescript":       "typescript_lang.zig",
    "vb":               "vb_lang.zig",
    "xml":              "xml_lang.zig",
    "yaml":             "yaml_lang.zig",
}

# Theme extensions: each needs a compiled-in Zig ThemeContribution.
THEME_EXTENSIONS = {
    "theme-abyss":               "theme_abyss.zig",
    "theme-defaults":            "theme_defaults.zig",
    "theme-kimbie-dark":         "theme_kimbie_dark.zig",
    "theme-monokai":             "theme_monokai.zig",
    "theme-monokai-dimmed":      "theme_monokai_dimmed.zig",
    "theme-quietlight":          "theme_quietlight.zig",
    "theme-red":                 "theme_red.zig",
    "theme-seti":                "theme_seti.zig",
    "theme-solarized-dark":      "theme_solarized_dark.zig",
    "theme-solarized-light":     "theme_solarized_light.zig",
    "theme-tomorrow-night-blue": "theme_tomorrow_night_blue.zig",
}

# Feature/tool extensions: each needs a compiled-in Zig extension module.
FEATURE_EXTENSIONS = {
    "emmet":                     "emmet.zig",
    "git":                       "git_ext.zig",
    "merge-conflict":            "merge_conflict.zig",
    "references-view":           "references_view.zig",
    "search-result":             "search_result.zig",
    "npm":                       "npm_ext.zig",
    "configuration-editing":     "configuration_editing.zig",
    "media-preview":             "media_preview.zig",
    "markdown-language-features": "markdown_features.zig",
    "html-language-features":    "html_features.zig",
    "css-language-features":     "css_features.zig",
    "json-language-features":    "json_features.zig",
    "php-language-features":     "php_features.zig",
    "typescript-language-features": "typescript_features.zig",
    "git-base":                  "git_base.zig",
    "github":                    "github_ext.zig",
    "github-authentication":     "github_auth.zig",
    "microsoft-authentication":  "microsoft_auth.zig",
    "debug-auto-launch":         "debug_auto_launch.zig",
    "debug-server-ready":        "debug_server_ready.zig",
    "extension-editing":         "extension_editing.zig",
    "grunt":                     "grunt_ext.zig",
    "gulp":                      "gulp_ext.zig",
    "jake":                      "jake_ext.zig",
    "ipynb":                     "ipynb.zig",
    "markdown-math":             "markdown_math.zig",
    "notebook-renderers":        "notebook_renderers.zig",
    "simple-browser":            "simple_browser.zig",
    "terminal-suggest":          "terminal_suggest.zig",
    "tunnel-forwarding":         "tunnel_forwarding.zig",
    "siro-agent":                "siro_agent.zig",
}


def check_language_extensions(st):
    """Check that all expected language grammars have compiled-in Zig tokenizers."""
    ext_dir = "src/extensions"
    existing = set()
    if os.path.isdir(ext_dir):
        for f in os.listdir(ext_dir):
            if f.endswith(".zig"):
                existing.add(f)

    missing = []
    for name, zig_file in sorted(LANGUAGE_EXTENSIONS.items()):
        if zig_file not in existing:
            missing.append(name)

    if missing:
        names = ", ".join(missing)
        finding(st, "Language Extensions",
            f"Missing {len(missing)} language grammars: {names}",
            "No Zig tokenizer module found in src/extensions/",
            "Create src/extensions/<name>_lang.zig with tokenizer + Extension descriptor, "
            "wire ext_<name>_mod in build.zig, register in manifest.zig, "
            "add to test root. See docs/extensions.md")


def check_theme_extensions(st):
    """Check that all expected themes have compiled-in Zig ThemeContribution modules."""
    ext_dir = "src/extensions"
    existing = set()
    if os.path.isdir(ext_dir):
        for f in os.listdir(ext_dir):
            if f.endswith(".zig"):
                existing.add(f)

    missing = []
    for name, zig_file in sorted(THEME_EXTENSIONS.items()):
        if zig_file not in existing:
            missing.append(name)

    if missing:
        names = ", ".join(missing)
        finding(st, "Theme Extensions",
            f"Missing {len(missing)} compiled-in themes: {names}",
            "No Zig ThemeContribution module in src/extensions/",
            "Create src/extensions/theme_<name>.zig with ThemeContribution defining colors, "
            "wire ext_theme_<name>_mod in build.zig, register in manifest.zig. "
            "Reference extensions/theme-<name>/themes/*.json for color values")


def check_feature_extensions(st):
    """Check that all expected feature/tool extensions have compiled-in Zig modules."""
    ext_dir = "src/extensions"
    existing = set()
    if os.path.isdir(ext_dir):
        for f in os.listdir(ext_dir):
            if f.endswith(".zig"):
                existing.add(f)

    missing = []
    for name, zig_file in sorted(FEATURE_EXTENSIONS.items()):
        if zig_file not in existing:
            missing.append(name)

    if missing:
        names = ", ".join(missing)
        finding(st, "Feature Extensions",
            f"Missing {len(missing)} feature extensions: {names}",
            "No Zig extension module in src/extensions/",
            "Create src/extensions/<name>.zig with Extension descriptor and commands, "
            "wire ext_<name>_mod in build.zig, register in manifest.zig, "
            "add to test root. See docs/extensions.md")


def check_extension_wiring(st):
    """Check that existing extension files are properly wired through the build system.

    For each src/extensions/*.zig (language, theme, or other), verifies:
      1. ext_<name>_mod defined in build.zig
      2. Imported and registered in src/extension/manifest.zig
      3. Imported in src/tests/root.zig
    """
    build_content = st.files.get(BUILD, "")
    test_content = st.files.get(TEST_ROOT, "")

    manifest_path = "src/extension/manifest.zig"
    manifest_content = ""
    if os.path.isfile(manifest_path):
        with open(manifest_path, "r", encoding="utf-8", errors="replace") as f:
            manifest_content = f.read()

    build_modules = set(re.findall(r'const (\w+)_mod = b\.createModule', build_content))
    test_imports = set(re.findall(r'@import\("(\w+)"\)', test_content))

    ext_dir = "src/extensions"
    if not os.path.isdir(ext_dir):
        return

    for f in sorted(os.listdir(ext_dir)):
        if not f.endswith(".zig"):
            continue
        basename = f[:-4]  # e.g. zig_lang, theme_monokai
        ext_mod = f"ext_{basename}"  # e.g. ext_zig_lang, ext_theme_monokai

        if ext_mod not in build_modules:
            finding(st, "Extension Wiring",
                f"{basename} not wired in build.zig",
                f"No const {ext_mod}_mod = b.createModule(...) found",
                f"Add {ext_mod}_mod to build.zig with imports for 'extension' and 'syntax'. "
                f"See docs/extensions.md Integration Steps")

        if ext_mod not in manifest_content:
            finding(st, "Extension Wiring",
                f"{basename} not registered in manifest.zig",
                f"No @import(\"{ext_mod}\") in manifest.zig",
                f"Add: const {basename} = @import(\"{ext_mod}\"); and "
                f"append {basename}.extension to the extensions array")

        if ext_mod not in test_imports:
            finding(st, "Extension Wiring",
                f"{basename} not in test root",
                f"No _ = @import(\"{ext_mod}\"); in src/tests/root.zig",
                f"Add: _ = @import(\"{ext_mod}\"); to src/tests/root.zig")


def check_extension_integration(st):
    """Check that extension contribution types are consumed by the workbench.

    Verifies that the workbench actually wires:
      1. Extension keybindings (registered in registerDefaultKeybindings)
      2. Extension snippets (expansion logic in handleTab/tryExpandSnippet)
      3. Extension themes (getThemeColors / cycleTheme)
      4. Extension status items (registerExtensionStatusItems / addExtStatus)
    """
    wb = fc(st, "workbench.zig")

    # Keybindings: workbench must iterate extension keybindings
    if not any(s in wb for s in ["extension.keybindings", "kb.key_code", "kb.command_id"]):
        finding(st, "Extension Integration",
            "Extension keybindings not consumed",
            "registerDefaultKeybindings does not iterate extension keybindings",
            "In registerDefaultKeybindings, inline for manifest.extensions and register each kb")

    # Snippets: workbench must have snippet expansion logic
    if not any(s in wb for s in ["tryExpandSnippet", "expandSnippetBody", "snip.prefix"]):
        finding(st, "Extension Integration",
            "Extension snippets not consumed",
            "No snippet expansion logic wired to extensions",
            "Add tryExpandSnippet that matches word before cursor against extension snippet prefixes")

    # Themes: workbench must have theme color accessor
    if not any(s in wb for s in ["getThemeColors", "cycleTheme", "active_theme_index"]):
        finding(st, "Extension Integration",
            "Extension themes not consumed",
            "No theme color lookup from extensions",
            "Add getThemeColors() returning active theme colors, cycleTheme() to switch")

    # Status items: workbench must register extension status items
    sb = fc(st, "status_bar.zig")
    if not any(s in (wb + sb) for s in ["registerExtensionStatusItems", "addExtStatusLeft", "addExtStatusRight", "ext_status"]):
        finding(st, "Extension Integration",
            "Extension status items not consumed",
            "No extension status item rendering in status bar",
            "Add ext_status fields to StatusBar, populate from manifest at init")


# ══════════════════════════════════════════════════════════════════════════════
# EDITOR FEATURE CHECKS
# ══════════════════════════════════════════════════════════════════════════════

def check_selection_keyboard(st):
    wb = fc(st, "workbench.zig")
    if "fn handleCursorMovement" in wb:
        idx = wb.index("fn handleCursorMovement")
        fn_body = wb[idx:idx+2000]
        if "shift" not in fn_body.lower():
            finding(st, "Editor Core",
                "Text selection via Shift+Arrow keys",
                "handleCursorMovement ignores shift state",
                "Pass shift flag; when held, move active pos but keep anchor")

def check_selection_mouse(st):
    wb = fc(st, "workbench.zig")
    chunk = wb[wb.find("fn handleMouseClick"):wb.find("fn handleMouseClick")+1500] if "fn handleMouseClick" in wb else ""
    has_shift = "shift" in chunk
    has_drag = "drag" in wb.lower() and "selection" in wb.lower()
    if not has_shift:
        finding(st, "Editor Core",
            "Text selection via Shift+Click",
            "handleMouseClick doesn't check shift state",
            "On shift+click keep anchor, move active pos")
    if not has_drag:
        finding(st, "Editor Core",
            "Text selection via mouse drag",
            "No click-drag selection support",
            "Track mouse drag state; extend selection while left button held")

def check_select_all(st):
    wb = fc(st, "workbench.zig")
    if not ("select_all" in wb.lower() or "VK_A" in wb or "0x41" in wb):
        finding(st, "Editor Core", "Select All (Ctrl+A)",
            "No Ctrl+A handler", "Add Ctrl+A: anchor=(0,0), active=end of buffer")

def check_clipboard(st):
    w32 = fc(st, "win32.zig")
    wb = fc(st, "workbench.zig")
    has_api = any(s in w32 for s in ["OpenClipboard", "CF_UNICODETEXT", "SetClipboardData"])
    has_keys = any(s in wb for s in ["VK_C", "VK_V", "VK_X", "clipboard"])
    if not has_api:
        finding(st, "Editor Core", "Copy/Cut/Paste (Ctrl+C/X/V)",
            "No clipboard API in win32.zig", "Add OpenClipboard/Get/SetClipboardData + handlers")
    elif not has_keys:
        finding(st, "Editor Core", "Copy/Cut/Paste keybindings",
            "Clipboard API exists but no Ctrl+C/X/V handlers", "Wire Ctrl+C/X/V in workbench")

def check_undo_redo(st):
    buf = fc(st, "buffer.zig")
    wb = fc(st, "workbench.zig")
    has_undo = "fn undo" in buf
    has_keybind = "VK_Z" in wb or "0x5A" in wb
    if not has_undo:
        finding(st, "Editor Core", "Undo/Redo system",
            "No undo/redo in buffer.zig", "Add undo history ring buffer to buffer.zig")
    elif not has_keybind:
        finding(st, "Editor Core", "Undo keybinding (Ctrl+Z)",
            "buffer.zig has undo but Ctrl+Z not wired", "Add Ctrl+Z handler calling buffer.undo()")

def check_find_replace(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb for s in ["findNext", "find_match", "search_overlay", "CMD_FIND"]):
        finding(st, "Editor Core", "Find and Replace (Ctrl+F / Ctrl+H)",
            "No find/replace overlay or search command", "Add find overlay + Ctrl+F/H keybindings")

def check_tab_key(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_TAB" in wb or "0x09" in wb):
        finding(st, "Editor Core", "Tab key inserts spaces/tab",
            "No VK_TAB handling", "Add Tab key handler inserting spaces at cursor")

def check_home_end(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_HOME" in wb or "0x24" in wb) or not ("VK_END" in wb or "0x23" in wb):
        finding(st, "Editor Core", "Home/End keys",
            "No Home/End handling", "Add Home->col=0, End->col=line_len")

def check_page_updown(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_PRIOR" in wb or "0x21" in wb) or not ("VK_NEXT" in wb or "0x22" in wb):
        finding(st, "Editor Core", "Page Up/Down",
            "No PageUp/PageDown handling", "Add PageUp/Down moving cursor by visible_lines")

def check_word_nav(st):
    wb = fc(st, "workbench.zig")
    if "fn handleCursorMovement" in wb:
        fn_body = wb[wb.index("fn handleCursorMovement"):wb.index("fn handleCursorMovement")+1500]
        if "ctrl" not in fn_body.lower():
            finding(st, "Editor Core", "Word navigation (Ctrl+Left/Right)",
                "handleCursorMovement ignores ctrl for word jumps",
                "Add ctrl+arrow: scan for word boundaries")

def check_double_click_word(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb.lower() for s in ["double_click", "dbl_click", "select_word", "word_select"]):
        finding(st, "Editor Core", "Double-click to select word",
            "No double-click word selection", "Track click timing; select word boundaries on double-click")

def check_right_click_menu(st):
    wb = fc(st, "workbench.zig")
    app = fc(st, "app.zig")
    if not any(s in (wb + app).lower() for s in ["context_menu", "right_click", "WM_RBUTTONDOWN".lower(), "right_button"]):
        finding(st, "Editor Core", "Right-click context menu",
            "No right-click handling", "Add context menu popup on right-click")


def check_line_numbers(st):
    vp = fc(st, "viewport.zig")
    wb = fc(st, "workbench.zig")
    if not any(s in (vp + wb) for s in ["line_number", "lineNumber", "gutter"]):
        finding(st, "Editor Visual", "Line number gutter",
            "No line numbers in viewport", "Add line number column to left of editor")

def check_scrollbar(st):
    vp = fc(st, "viewport.zig")
    wb = fc(st, "workbench.zig")
    if not any(s in (vp + wb) for s in ["scrollbar", "scroll_thumb", "renderScrollbar", "scroll_track"]):
        finding(st, "Editor Visual", "Vertical scrollbar",
            "No visual scrollbar rendered", "Add scrollbar track + thumb to editor right edge")

def check_indent_guides(st):
    vp = fc(st, "viewport.zig")
    if not any(s in vp for s in ["indent_guide", "indentGuide", "guide_line"]):
        finding(st, "Editor Visual", "Indent guide lines",
            "No indent guides in viewport", "Add vertical lines at tab-stop positions")

def check_bracket_matching(st):
    vp = fc(st, "viewport.zig")
    syn = fc(st, "syntax.zig")
    wb = fc(st, "workbench.zig")
    if not any(s in (vp + syn + wb) for s in ["bracket_match", "matching_bracket", "bracketMatch"]):
        finding(st, "Editor Visual", "Bracket pair matching",
            "No bracket matching logic", "Add matching (), [], {} detection and highlight")

def check_word_wrap(st):
    vp = fc(st, "viewport.zig")
    wb = fc(st, "workbench.zig")
    if not any(s in (vp + wb) for s in ["word_wrap", "wrapping", "wrap_column"]):
        finding(st, "Editor Visual", "Word wrap mode",
            "No word wrap support", "Add wrap mode toggle and wrapped-line rendering")

def check_font_zoom(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb for s in ["font_zoom", "zoomIn", "zoomOut", "VK_OEM_PLUS", "VK_OEM_MINUS"]):
        finding(st, "Editor Visual", "Font zoom (Ctrl+=/Ctrl+-)",
            "No font zoom support", "Add Ctrl+=/- handlers adjusting font size")

def check_word_highlight(st):
    vp = fc(st, "viewport.zig")
    wb = fc(st, "workbench.zig")
    if not any(s in (vp + wb).lower() for s in ["word_highlight", "highlightword"]):
        finding(st, "Editor Visual", "Highlight word under cursor",
            "No word highlight on cursor", "Add word-under-cursor detection + highlight rendering")

def check_current_line_highlight(st):
    vp = fc(st, "viewport.zig")
    if not any(s in vp for s in ["current_line", "active_line_bg", "CURRENT_LINE"]):
        finding(st, "Editor Visual", "Current line highlight",
            "No current-line background in viewport", "Add subtle bg rect for cursor line")

def check_comment_toggle(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb.lower() for s in ["toggle_comment", "comment_line"]) and "VK_OEM_2" not in wb:
        finding(st, "Editor Ops", "Toggle line comment (Ctrl+/)",
            "No Ctrl+/ handler", "Add Ctrl+/ to prepend/remove '//' on current line")

def check_go_to_line(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb for s in ["goto_line", "go_to_line", "CMD_GOTO_LINE", "VK_G", "0x47"]):
        finding(st, "Editor Ops", "Go to line (Ctrl+G)",
            "No Ctrl+G handler", "Add Ctrl+G with line number input overlay")

def check_duplicate_line(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb.lower() for s in ["duplicate_line", "duplicateline"]):
        finding(st, "Editor Ops", "Duplicate line",
            "No line duplication command", "Add Alt+Shift+Down to copy current line below")

def check_move_line(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb.lower() for s in ["move_line", "moveline"]):
        finding(st, "Editor Ops", "Move line up/down (Alt+Up/Down)",
            "No line move command", "Add Alt+Up/Down to swap current line with adjacent")

def check_autocomplete(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb.lower() for s in ["autocomplete", "suggest", "completion", "intellisense"]):
        finding(st, "Editor Ops", "Basic autocomplete popup",
            "No autocomplete system", "Add word-based completion popup")

def check_code_folding(st):
    vp = fc(st, "viewport.zig")
    wb = fc(st, "workbench.zig")
    if "fold" not in (vp + wb).lower():
        finding(st, "Editor Ops", "Code folding",
            "No fold support", "Add fold markers and collapse logic to viewport")


# ══════════════════════════════════════════════════════════════════════════════
# WINDOW / WORKBENCH / PLATFORM CHECKS
# ══════════════════════════════════════════════════════════════════════════════

def check_window_btn_clicks(st):
    wb = fc(st, "workbench.zig")
    app = fc(st, "app.zig")
    has_render = "renderTitleBar" in wb and any(s in wb for s in ["min_x", "close_x", "max_x"])
    has_click = any(s in (wb + app) for s in ["SW_MINIMIZE", "SW_MAXIMIZE", "SC_MINIMIZE", "SC_MAXIMIZE", "PostQuitMessage"])
    if has_render and not has_click:
        finding(st, "Window", "Window button click handlers",
            "Title bar renders buttons but no click dispatch", "Add hit-testing + PostMessageW for min/max/close")

def check_title_bar_dblclick(st):
    wb = fc(st, "workbench.zig")
    app = fc(st, "app.zig")
    if not any(s in (wb + app).lower() for s in ["double_click", "wm_nclbuttondblclk", "dbl_click"]):
        finding(st, "Window", "Double-click title bar to maximize/restore",
            "No double-click detection on title bar", "Handle WM_NCLBUTTONDBLCLK or track timing")

def check_window_resize(st):
    app = fc(st, "app.zig")
    indicators = ["HTLEFT", "HTRIGHT", "HTTOP", "HTBOTTOM", "HTTOPLEFT",
                   "HTTOPRIGHT", "HTBOTTOMLEFT", "HTBOTTOMRIGHT", "WS_THICKFRAME"]
    if not any(s in app for s in indicators):
        finding(st, "Window", "Edge-drag window resize",
            "No resize hit zones in WM_NCHITTEST", "Add HT* return values for window edges")

def check_tab_close_click(st):
    wb = fc(st, "workbench.zig")
    has_close = "fn closeTab" in wb
    update_fn = wb[wb.index("fn update"):wb.index("fn update")+3000] if "fn update" in wb else ""
    has_click = any(s in update_fn for s in ["editor_tabs", "tab_close"])
    if has_close and not has_click:
        finding(st, "Tab Bar", "Tab close 'x' click handler",
            "closeTab() exists but no click hit-testing in update()", "Add mouse click detection for tab close rects")

def check_tab_switch_click(st):
    wb = fc(st, "workbench.zig")
    update_fn = wb[wb.index("fn update"):wb.index("fn update")+3000] if "fn update" in wb else ""
    if not ("active_tab" in update_fn and "editor_tabs" in update_fn):
        finding(st, "Tab Bar", "Click tab to switch",
            "No tab click detection in update()", "Add hit-testing for tab rects; set active_tab on click")

def check_ctrl_w(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_W" in wb or "0x57" in wb):
        finding(st, "Tab Bar", "Ctrl+W close tab",
            "No Ctrl+W keybinding", "Add Ctrl+W calling closeTab(active_tab)")

def check_ctrl_tab(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_TAB" in wb and "ctrl" in wb.lower()):
        finding(st, "Tab Bar", "Ctrl+Tab cycle tabs",
            "No Ctrl+Tab handler", "Add Ctrl+Tab cycling active_tab index")

def check_activity_bar_clicks(st):
    wb = fc(st, "workbench.zig")
    ab = fc(st, "activity_bar.zig")
    has_icon = "active_icon" in ab
    update_fn = wb[wb.index("fn update"):wb.index("fn update")+3000] if "fn update" in wb else ""
    if has_icon and not ("activity_bar" in update_fn and "active_icon" in update_fn):
        finding(st, "Activity Bar", "Icon clicks to switch sidebar views",
            "active_icon field exists but no click handling in update()", "Add click detection for activity bar icons")

def check_panel_tab_clicks(st):
    wb = fc(st, "workbench.zig")
    pn = fc(st, "panel.zig")
    has_tab = "active_tab" in pn
    update_fn = wb[wb.index("fn update"):wb.index("fn update")+3000] if "fn update" in wb else ""
    if has_tab and not ("panel" in update_fn.lower() and "active_tab" in update_fn):
        finding(st, "Panel", "Panel tab clicks (PROBLEMS/OUTPUT/TERMINAL)",
            "Panel has active_tab but no click handling in update()", "Add click detection for panel tab rects")

def check_panel_toggle(st):
    wb = fc(st, "workbench.zig")
    if "CMD_TOGGLE_PANEL" in wb and not any(s in wb for s in ["VK_J", "0x4A", "VK_OEM_3", "0xC0"]):
        finding(st, "Panel", "Panel toggle keybinding (Ctrl+J)",
            "CMD_TOGGLE_PANEL exists but no keyboard shortcut", "Register Ctrl+J for CMD_TOGGLE_PANEL")

def check_sidebar_toggle(st):
    wb = fc(st, "workbench.zig")
    if not ("VK_B" in wb or "0x42" in wb):
        finding(st, "Sidebar", "Ctrl+B toggle sidebar",
            "No Ctrl+B keybinding", "Register Ctrl+B for CMD_TOGGLE_SIDEBAR")

def check_file_save_as(st):
    wb = fc(st, "workbench.zig")
    w32 = fc(st, "win32.zig")
    if not any(s in (w32 + wb) for s in ["GetSaveFileNameW", "SaveAs", "save_as"]):
        finding(st, "Platform", "Save As (Ctrl+Shift+S)",
            "No Save As dialog", "Add GetSaveFileNameW + Ctrl+Shift+S handler")

def check_new_file(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb for s in ["CMD_NEW_FILE", "VK_N", "0x4E"]):
        finding(st, "Platform", "New File (Ctrl+N)",
            "No Ctrl+N handler", "Add Ctrl+N creating untitled buffer tab")

def check_file_watcher(st):
    w32 = fc(st, "win32.zig")
    if not any(s in w32 for s in ["ReadDirectoryChangesW", "FindFirstChangeNotification"]):
        finding(st, "Platform", "File system watcher",
            "No file change notification API", "Add ReadDirectoryChangesW for auto-reload")

def check_drag_drop(st):
    app = fc(st, "app.zig")
    w32 = fc(st, "win32.zig")
    if not any(s in (app + w32) for s in ["WM_DROPFILES", "DragAcceptFiles"]):
        finding(st, "Platform", "Drag and drop files to open",
            "No WM_DROPFILES handling", "Add DragAcceptFiles + WM_DROPFILES handler")

def check_menu_bar(st):
    wb = fc(st, "workbench.zig")
    if not any(s in wb for s in ["menu_bar", "renderMenu", "menuBar"]):
        finding(st, "Workbench", "Menu bar (File, Edit, View...)",
            "No menu bar in title bar", "Add menu bar rendering with dropdown menus")

def check_search_files(st):
    wb = fc(st, "workbench.zig")
    sb = fc(st, "sidebar.zig")
    if not any(s in (wb + sb).lower() for s in ["search_view", "file_search", "cmd_search"]):
        finding(st, "Workbench", "Search across files (Ctrl+Shift+F)",
            "No file search view", "Add search sidebar view with content search")

def check_terminal(st):
    pn = fc(st, "panel.zig")
    w32 = fc(st, "win32.zig")
    if not any(s in (w32 + pn).lower() for s in ["createprocess", "pseudoconsole", "pty"]):
        finding(st, "Panel", "Integrated terminal with shell process",
            "No shell process integration", "Add CreateProcess + pipe I/O for terminal")

def check_problems_panel(st):
    pn = fc(st, "panel.zig")
    if not any(s in pn.lower() for s in ["diagnostic", "error_list", "problem_entry", "marker"]):
        finding(st, "Panel", "Problems panel with diagnostics",
            "No diagnostic data model in panel", "Add diagnostic entry model + rendering")

def check_theme_system(st):
    all_c = "\n".join(st.files.values())
    if not any(s in all_c.lower() for s in ["theme_service", "loadtheme", "themedata", "color_theme"]):
        finding(st, "Theming", "Switchable color themes",
            "Colors are compile-time constants, no runtime switching", "Add theme data structure with color lookup")

def check_git_integration(st):
    all_c = "\n".join(st.files.values())
    if not any(s in all_c.lower() for s in ["git_status", "git_diff", "scm_provider"]):
        finding(st, "SCM", "Git integration (status, gutter diff)",
            "No git/SCM integration", "Add git status parsing for gutter indicators")


# ══════════════════════════════════════════════════════════════════════════════
# REPORT
# ══════════════════════════════════════════════════════════════════════════════

def print_report(st):
    st.findings.sort(key=lambda f: (f.category, f.feature))
    total = len(st.findings)

    print(f"\n{BOLD}=== SBCode Audit ==={RESET}\n")
    print(f"  Scanned {len(st.files)} files")
    if total == 0:
        print(f"  {BOLD}0 findings{RESET} -- all clear\n")
    else:
        print(f"  {RED}{total} findings{RESET}\n")

    cat = None
    for f in st.findings:
        if f.category != cat:
            cat = f.category
            print(f"\n{BOLD}-- {cat} --{RESET}")
        print(f"  {RED}*{RESET} {f.feature}")
        print(f"    Status: {f.status}")
        print(f"    Action: {f.action}")
        print()

    print(f"{BOLD}=== {total} findings -- all must be fixed ==={RESET}\n")

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

def main():
    st = State()
    load_files(st)

    # Extensions
    check_language_extensions(st)
    check_theme_extensions(st)
    check_feature_extensions(st)
    check_extension_wiring(st)
    check_extension_integration(st)

    # Editor core
    check_selection_keyboard(st)
    check_selection_mouse(st)
    check_select_all(st)
    check_clipboard(st)
    check_undo_redo(st)
    check_find_replace(st)
    check_tab_key(st)
    check_home_end(st)
    check_page_updown(st)
    check_word_nav(st)
    check_double_click_word(st)
    check_right_click_menu(st)

    # Editor visual
    check_line_numbers(st)
    check_current_line_highlight(st)
    check_scrollbar(st)
    check_indent_guides(st)
    check_bracket_matching(st)
    check_word_wrap(st)
    check_font_zoom(st)
    check_word_highlight(st)

    # Editor ops
    check_comment_toggle(st)
    check_go_to_line(st)
    check_duplicate_line(st)
    check_move_line(st)
    check_autocomplete(st)
    check_code_folding(st)

    # Window
    check_window_btn_clicks(st)
    check_title_bar_dblclick(st)
    check_window_resize(st)

    # Tab bar
    check_tab_close_click(st)
    check_tab_switch_click(st)
    check_ctrl_w(st)
    check_ctrl_tab(st)

    # Activity bar / Panel / Sidebar
    check_activity_bar_clicks(st)
    check_panel_tab_clicks(st)
    check_panel_toggle(st)
    check_sidebar_toggle(st)

    # Platform
    check_file_save_as(st)
    check_new_file(st)
    check_file_watcher(st)
    check_drag_drop(st)

    # Workbench
    check_menu_bar(st)
    check_search_files(st)
    check_terminal(st)
    check_problems_panel(st)

    # Theming / SCM
    check_theme_system(st)
    check_git_integration(st)

    print_report(st)
    sys.exit(1 if st.findings else 0)

if __name__ == "__main__":
    main()
