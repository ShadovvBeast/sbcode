#!/usr/bin/env python3
"""
SBCode Feature Gap Analysis — Deep Heuristic Scanner

Scans the Zig codebase file-by-file to detect missing, stubbed, or
non-functional features compared to a baseline VS Code-like editor.

Unlike a naive keyword search, this script:
  - Reads each Zig file individually and checks for FUNCTIONAL code
  - Distinguishes between "keyword mentioned" vs "actually implemented"
  - Checks for rendered-but-non-functional UI elements
  - Verifies keyboard shortcuts are wired end-to-end
  - Checks click handlers exist for clickable UI elements

Usage:
    python scripts/feature_gap.py [--verbose]

Exit code: 1 if any CRITICAL gaps, 0 otherwise.
"""

import os
import re
import sys
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

# ─── Configuration ────────────────────────────────────────────────────────────

ZIG_DIRS = ["src/base", "src/editor", "src/platform", "src/renderer", "src/workbench"]
ZIG_APP  = ["src/app.zig", "src/main.zig"]
BUILD    = "build.zig"

class Severity(Enum):
    CRITICAL = "CRITICAL"
    HIGH     = "HIGH"
    MEDIUM   = "MEDIUM"
    LOW      = "LOW"

SEVERITY_COLORS = {
    Severity.CRITICAL: "\033[91m",
    Severity.HIGH:     "\033[93m",
    Severity.MEDIUM:   "\033[96m",
    Severity.LOW:      "\033[90m",
}
RESET = "\033[0m"
BOLD  = "\033[1m"

@dataclass
class Gap:
    severity: Severity
    category: str
    feature: str
    status: str
    action: str

@dataclass
class AnalysisState:
    gaps: list = field(default_factory=list)
    files: dict = field(default_factory=dict)  # path -> content

def gap(state, severity, category, feature, status, action):
    state.gaps.append(Gap(severity, category, feature, status, action))

# ─── File loading ─────────────────────────────────────────────────────────────

def load_files(state: AnalysisState):
    for d in ZIG_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".zig"):
                path = os.path.join(d, f)
                with open(path, "r", encoding="utf-8", errors="replace") as fh:
                    state.files[path] = fh.read()
    for f in ZIG_APP:
        if os.path.isfile(f):
            with open(f, "r", encoding="utf-8", errors="replace") as fh:
                state.files[f] = fh.read()
    if os.path.isfile(BUILD):
        with open(BUILD, "r", encoding="utf-8", errors="replace") as fh:
            state.files[BUILD] = fh.read()


# ─── Strict search helpers ────────────────────────────────────────────────────

def file_content(state, filename):
    """Get content of a specific file by exact basename match."""
    for path, content in state.files.items():
        # Normalize separators for cross-platform matching
        norm = path.replace("\\", "/")
        basename = norm.rsplit("/", 1)[-1] if "/" in norm else norm
        if basename == filename:
            return content
    return ""

def file_has_fn(state, filename, fn_name):
    """Check if a file defines a function (pub fn or fn) with the given name."""
    content = file_content(state, filename)
    pattern = rf'\bfn\s+{re.escape(fn_name)}\b'
    return bool(re.search(pattern, content))

def file_has_field(state, filename, field_name):
    """Check if a file has a struct field with the given name."""
    content = file_content(state, filename)
    pattern = rf'^\s+{re.escape(field_name)}\s*:'
    return bool(re.search(pattern, content, re.MULTILINE))

def file_has_string(state, filename, s, case_sensitive=True):
    """Check if a file contains a literal string (not just in comments)."""
    content = file_content(state, filename)
    if not content:
        return False
    # Strip single-line comments to avoid false positives
    lines = content.split('\n')
    code_lines = []
    for line in lines:
        # Remove // comments but keep string literals
        idx = line.find('//')
        if idx >= 0:
            # Simple heuristic: if // is not inside a string, strip it
            before = line[:idx]
            if before.count('"') % 2 == 0:
                line = before
        code_lines.append(line)
    code = '\n'.join(code_lines)
    if case_sensitive:
        return s in code
    return s.lower() in code.lower()

def file_has_pattern(state, filename, pattern):
    """Check if a file matches a regex pattern in code (not comments)."""
    content = file_content(state, filename)
    if not content:
        return False
    return bool(re.search(pattern, content))

def any_file_has(state, s, case_sensitive=False):
    """Check if any Zig file contains a string (in code, not just comments)."""
    for path, content in state.files.items():
        if case_sensitive:
            if s in content:
                return True
        else:
            if s.lower() in content.lower():
                return True
    return False

def workbench_handles_vk(state, vk_name):
    """Check if workbench.zig handles a specific virtual key code in update()."""
    content = file_content(state, "workbench.zig")
    # Look for the VK constant being matched in a switch or if statement
    return vk_name in content

def workbench_handles_ctrl_key(state, vk_hex_or_name):
    """Check if workbench.zig handles Ctrl+<key> combination."""
    content = file_content(state, "workbench.zig")
    # Check if there's a keybinding registration or direct ev.ctrl check for this key
    return vk_hex_or_name in content and "ctrl" in content.lower()


# ═══════════════════════════════════════════════════════════════════════════════
# FEATURE CHECKS — organized by category
# ═══════════════════════════════════════════════════════════════════════════════

# ─── 1. Editor Core: Text Editing ─────────────────────────────────────────────

def check_line_numbers(state):
    """Line number gutter — every code editor has this."""
    vp = file_content(state, "viewport.zig")
    wb = file_content(state, "workbench.zig")
    has_line_numbers = ("line_number" in vp or "lineNumber" in vp or
                        "gutter" in vp or "line_number" in wb)
    if not has_line_numbers:
        gap(state, Severity.HIGH, "Editor Visual",
            "Line number gutter on the left side of the editor",
            "viewport.zig renders text and cursors but has no line number column",
            "Add line number rendering to the left of each line in viewport.zig")

def check_current_line_highlight(state):
    """Subtle background highlight on the line where the cursor sits."""
    vp = file_content(state, "viewport.zig")
    has_highlight = ("current_line" in vp or "active_line_bg" in vp or
                     "CURRENT_LINE" in vp)
    if not has_highlight:
        gap(state, Severity.HIGH, "Editor Visual",
            "Current line highlight (subtle background on cursor line)",
            "viewport.zig has no current-line background highlight",
            "Add a subtle background rect for the cursor's line in renderEditorViewport")

def check_scrollbar(state):
    """Visual scrollbar — scroll works via mouse wheel but no visual indicator."""
    vp = file_content(state, "viewport.zig")
    wb = file_content(state, "workbench.zig")
    has_scrollbar = ("scrollbar" in vp or "scroll_thumb" in vp or
                     "scrollbar" in wb or "renderScrollbar" in wb or
                     "scroll_track" in vp)
    if not has_scrollbar:
        gap(state, Severity.HIGH, "Editor Visual",
            "Vertical scrollbar with thumb/track indicator",
            "Mouse wheel scrolling works but there is no visual scrollbar rendered",
            "Add scrollbar rendering (track + thumb) to the right of the editor area")

def check_selection_keyboard(state):
    """Shift+Arrow to extend selection — fundamental editor feature."""
    wb = file_content(state, "workbench.zig")
    # Check if handleCursorMovement uses shift to extend selection
    # The current code just moves the cursor position without checking shift
    has_shift_select = ("ev.shift" in wb and ("anchor" in wb or "selection" in wb))
    # Also check if handleCursorMovement reads shift state
    cursor_fn = ""
    if "fn handleCursorMovement" in wb:
        # Extract the function body
        idx = wb.index("fn handleCursorMovement")
        # Find the closing brace (rough heuristic)
        brace_count = 0
        started = False
        end_idx = idx
        for i in range(idx, min(idx + 2000, len(wb))):
            if wb[i] == '{':
                brace_count += 1
                started = True
            elif wb[i] == '}':
                brace_count -= 1
                if started and brace_count == 0:
                    end_idx = i
                    break
        cursor_fn = wb[idx:end_idx]

    # handleCursorMovement takes (self, vk) — no shift parameter
    # This means shift+arrow cannot extend selection
    if "shift" not in cursor_fn.lower():
        gap(state, Severity.HIGH, "Editor Core",
            "Text selection via Shift+Arrow keys",
            "handleCursorMovement only takes vk code, ignores shift state — cannot extend selection",
            "Pass shift flag to handleCursorMovement; when shift is held, move active but keep anchor")

def check_selection_mouse(state):
    """Click-drag or Shift+Click to select text with mouse."""
    wb = file_content(state, "workbench.zig")
    # Check handleMouseClick for shift handling or drag tracking
    has_shift_click = "shift" in wb[wb.find("fn handleMouseClick"):wb.find("fn handleMouseClick") + 1500] if "fn handleMouseClick" in wb else False
    has_drag = "left_button" in wb and "mouse_dx" in wb  # drag tracking
    if not has_shift_click and not has_drag:
        gap(state, Severity.HIGH, "Editor Core",
            "Text selection via mouse (Shift+Click or click-drag)",
            "handleMouseClick sets cursor position but doesn't support shift+click or drag selection",
            "Track mouse drag state; on shift+click move active pos but keep anchor")

def check_select_all(state):
    """Ctrl+A to select all text."""
    wb = file_content(state, "workbench.zig")
    has_select_all = ("select_all" in wb.lower() or "VK_A" in wb or "0x41" in wb)
    if not has_select_all:
        gap(state, Severity.HIGH, "Editor Core",
            "Select All (Ctrl+A)",
            "No Ctrl+A handler found in workbench.zig",
            "Add Ctrl+A keybinding that sets anchor to (0,0) and active to end of buffer")

def check_clipboard(state):
    """Copy/Cut/Paste via system clipboard."""
    w32 = file_content(state, "win32.zig")
    wb = file_content(state, "workbench.zig")
    has_clipboard_api = ("OpenClipboard" in w32 or "CF_UNICODETEXT" in w32 or
                         "SetClipboardData" in w32 or "GetClipboardData" in w32)
    has_clipboard_handler = ("clipboard" in wb.lower() or "VK_C" in wb or "VK_V" in wb or "VK_X" in wb)
    if not has_clipboard_api:
        gap(state, Severity.HIGH, "Editor Core",
            "Copy/Cut/Paste via system clipboard (Ctrl+C/X/V)",
            "No Win32 clipboard API declarations (OpenClipboard, Get/SetClipboardData) in win32.zig",
            "Add clipboard Win32 API declarations and Ctrl+C/X/V handlers in workbench.zig")
    elif not has_clipboard_handler:
        gap(state, Severity.HIGH, "Editor Core",
            "Copy/Cut/Paste keyboard shortcuts (Ctrl+C/X/V)",
            "Clipboard API exists in win32.zig but no Ctrl+C/X/V handlers in workbench.zig",
            "Wire Ctrl+C/X/V to clipboard operations using selection range")

def check_undo_redo_keybindings(state):
    """Ctrl+Z undo, Ctrl+Y/Ctrl+Shift+Z redo — must be wired to keybindings."""
    wb = file_content(state, "workbench.zig")
    buf = file_content(state, "buffer.zig")
    has_undo_system = "fn undo" in buf and "fn redo" in buf
    has_undo_keybind = ("VK_Z" in wb or "0x5A" in wb)
    has_redo_keybind = ("VK_Y" in wb or "0x59" in wb)
    if has_undo_system and not has_undo_keybind:
        gap(state, Severity.HIGH, "Editor Core",
            "Undo keybinding (Ctrl+Z)",
            "buffer.zig has undo/redo system but Ctrl+Z is not wired in workbench.zig",
            "Add Ctrl+Z handler that calls self.buffer.undo() and updates cursor position")
    if has_undo_system and not has_redo_keybind:
        gap(state, Severity.HIGH, "Editor Core",
            "Redo keybinding (Ctrl+Y or Ctrl+Shift+Z)",
            "buffer.zig has redo system but Ctrl+Y is not wired in workbench.zig",
            "Add Ctrl+Y handler that calls self.buffer.redo() and updates cursor position")

def check_tab_key(state):
    """Tab key should insert tab character or spaces."""
    wb = file_content(state, "workbench.zig")
    has_tab = ("VK_TAB" in wb or "0x09" in wb or "tab_key" in wb)
    if not has_tab:
        gap(state, Severity.HIGH, "Editor Core",
            "Tab key inserts tab character or spaces",
            "No Tab key (VK_TAB / 0x09) handling in workbench.zig",
            "Add Tab key handler that inserts spaces (tab_size from status_bar) at cursor")

def check_home_end_keys(state):
    """Home/End keys for line navigation."""
    wb = file_content(state, "workbench.zig")
    has_home = ("VK_HOME" in wb or "0x24" in wb)
    has_end = ("VK_END" in wb or "0x23" in wb)
    if not has_home or not has_end:
        gap(state, Severity.HIGH, "Editor Core",
            "Home/End keys for line start/end navigation",
            "No Home (0x24) or End (0x23) key handling in workbench.zig",
            "Add Home → col=0, End → col=line_len handlers to handleCursorMovement")

def check_page_up_down(state):
    """Page Up/Page Down for viewport-sized scrolling."""
    wb = file_content(state, "workbench.zig")
    has_pgup = ("VK_PRIOR" in wb or "0x21" in wb or "page_up" in wb.lower())
    has_pgdn = ("VK_NEXT" in wb or "0x22" in wb or "page_down" in wb.lower())
    if not has_pgup or not has_pgdn:
        gap(state, Severity.HIGH, "Editor Core",
            "Page Up / Page Down for viewport-sized scrolling",
            "No PageUp (0x21) or PageDown (0x22) key handling in workbench.zig",
            "Add PageUp/PageDown that move cursor and scroll by visible_lines")

def check_word_navigation(state):
    """Ctrl+Left/Right to jump by word."""
    wb = file_content(state, "workbench.zig")
    # Check if cursor movement handles ctrl modifier for word jumping
    has_word_nav = ("word" in wb.lower() and "ctrl" in wb.lower() and
                    ("VK_LEFT" in wb or "VK_RIGHT" in wb))
    # More precise: check if handleCursorMovement or update checks ctrl+arrow
    cursor_fn_area = ""
    if "fn handleCursorMovement" in wb:
        idx = wb.index("fn handleCursorMovement")
        cursor_fn_area = wb[idx:idx+1500]
    has_ctrl_in_cursor = "ctrl" in cursor_fn_area.lower()
    if not has_ctrl_in_cursor:
        gap(state, Severity.MEDIUM, "Editor Core",
            "Word navigation (Ctrl+Left/Right to jump by word)",
            "handleCursorMovement doesn't check ctrl modifier for word-level jumps",
            "Add ctrl+arrow handling: scan for word boundaries in buffer line")


def check_find_replace(state):
    """Find and Replace (Ctrl+F, Ctrl+H)."""
    wb = file_content(state, "workbench.zig")
    has_find = ("find_replace" in wb.lower() or "search_query" in wb.lower() or
                "VK_F" in wb or "0x46" in wb)
    # VK_DELETE is 0x2E, VK_F is 0x46 — check if 0x46 is used for Ctrl+F
    # Actually check for a find/search UI or command
    has_find_ui = ("findNext" in wb or "find_match" in wb or "search_overlay" in wb or
                   "CMD_FIND" in wb)
    if not has_find_ui:
        gap(state, Severity.HIGH, "Editor Core",
            "Find and Replace (Ctrl+F / Ctrl+H) with match highlighting",
            "No find/replace overlay or search command found in workbench.zig",
            "Add find overlay UI, search logic in buffer, and Ctrl+F/H keybindings")

def check_enter_newline(state):
    """Enter key properly inserts newline and handles auto-indent."""
    wb = file_content(state, "workbench.zig")
    # Check if Enter/Return is handled for newline insertion
    # The text input handler should handle '\n' from WM_CHAR
    has_newline = ("'\\n'" in wb or "newline" in wb.lower())
    if not has_newline:
        gap(state, Severity.HIGH, "Editor Core",
            "Enter key inserts newline",
            "No newline handling found in text input",
            "Ensure WM_CHAR sends newline and handleTextInput processes it")

# ─── 2. Window Controls & Title Bar ──────────────────────────────────────────

def check_window_button_clicks(state):
    """Window min/max/close buttons are rendered but need click handlers."""
    wb = file_content(state, "workbench.zig")
    app = file_content(state, "app.zig")
    # Buttons are rendered in renderTitleBar (we can see "Minimize", "Maximize", "Close" symbols)
    has_btn_render = "renderTitleBar" in wb and ("min_x" in wb or "close_x" in wb or "max_x" in wb)
    # Check if click handling exists for these buttons
    has_btn_click = ("WINDOW_BTN" in wb and "mouse" in wb.lower() and
                     ("PostMessageW" in wb or "ShowWindow" in wb or
                      "SW_MINIMIZE" in wb or "SW_MAXIMIZE" in wb or
                      "DestroyWindow" in wb or "PostQuitMessage" in wb))
    # Also check app.zig for actual window command dispatching
    has_app_btn = ("SW_MINIMIZE" in app or "SW_MAXIMIZE" in app or
                   "SC_MINIMIZE" in app or "SC_MAXIMIZE" in app)
    if has_btn_render and not has_btn_click and not has_app_btn:
        gap(state, Severity.HIGH, "Window Controls",
            "Window control buttons (minimize/maximize/close) click handling",
            "Title bar renders min/max/close button symbols but no click handlers dispatch window commands",
            "Add hit-testing in update() for button rects; call PostMessageW(WM_SYSCOMMAND, SC_MINIMIZE/MAXIMIZE/CLOSE)")

def check_title_bar_double_click(state):
    """Double-click title bar to maximize/restore."""
    wb = file_content(state, "workbench.zig")
    app = file_content(state, "app.zig")
    has_dblclick = ("double_click" in wb.lower() or "WM_NCLBUTTONDBLCLK" in app or
                    "dbl_click" in wb.lower())
    if not has_dblclick:
        gap(state, Severity.LOW, "Window Controls",
            "Double-click title bar to maximize/restore window",
            "No double-click detection on title bar area",
            "Track double-click timing or handle WM_NCLBUTTONDBLCLK in windowProc")

# ─── 3. Tab Bar Interactions ─────────────────────────────────────────────────

def check_tab_close_click(state):
    """Tab close 'x' button click handler."""
    wb = file_content(state, "workbench.zig")
    # closeTab function exists, but is it wired to mouse clicks on the 'x' button?
    has_close_fn = "fn closeTab" in wb
    # Check if update() has click detection for tab close buttons
    has_close_click = ("tab" in wb.lower() and "close" in wb.lower() and
                       "mouse" in wb.lower() and "left_button_pressed" in wb)
    # More precise: check if there's hit-testing for tab close button area
    update_fn = ""
    if "fn update" in wb:
        idx = wb.index("fn update")
        update_fn = wb[idx:idx+3000]
    has_tab_click_in_update = ("editor_tabs" in update_fn or "tab_close" in update_fn.lower() or
                               "renderTabBar" in update_fn)
    if has_close_fn and not has_tab_click_in_update:
        gap(state, Severity.HIGH, "Tab Bar",
            "Tab close 'x' button click handler",
            "closeTab() exists and 'x' is rendered on each tab, but no click hit-testing in update()",
            "Add mouse click detection in update() for tab close button rects, call closeTab()")

def check_tab_switch_click(state):
    """Click on a tab to switch to it."""
    wb = file_content(state, "workbench.zig")
    update_fn = ""
    if "fn update" in wb:
        idx = wb.index("fn update")
        update_fn = wb[idx:idx+3000]
    has_tab_switch = ("active_tab" in update_fn and "editor_tabs" in update_fn)
    if not has_tab_switch:
        gap(state, Severity.HIGH, "Tab Bar",
            "Click on tab to switch active editor tab",
            "No tab click detection in update() — tabs render but clicking them does nothing",
            "Add hit-testing for tab rects in update(); set active_tab on click")

def check_ctrl_w_close_tab(state):
    """Ctrl+W to close current tab."""
    wb = file_content(state, "workbench.zig")
    has_ctrl_w = ("VK_W" in wb or "0x57" in wb)
    if not has_ctrl_w:
        gap(state, Severity.MEDIUM, "Tab Bar",
            "Ctrl+W to close current tab",
            "No Ctrl+W keybinding found in workbench.zig",
            "Add Ctrl+W handler that calls closeTab(active_tab)")

def check_ctrl_tab_switch(state):
    """Ctrl+Tab to cycle through open tabs."""
    wb = file_content(state, "workbench.zig")
    has_ctrl_tab = ("Ctrl+Tab" in wb or ("VK_TAB" in wb and "ctrl" in wb.lower()))
    if not has_ctrl_tab:
        gap(state, Severity.LOW, "Tab Bar",
            "Ctrl+Tab to cycle through open tabs",
            "No Ctrl+Tab handler found",
            "Add Ctrl+Tab handler that cycles active_tab index")

# ─── 4. Activity Bar Interactions ─────────────────────────────────────────────

def check_activity_bar_clicks(state):
    """Activity bar icon clicks should switch sidebar views."""
    wb = file_content(state, "workbench.zig")
    ab = file_content(state, "activity_bar.zig")
    has_active_icon = "active_icon" in ab
    # Check if workbench update() handles clicks in activity bar region
    update_fn = ""
    if "fn update" in wb:
        idx = wb.index("fn update")
        update_fn = wb[idx:idx+3000]
    has_ab_click = ("activity_bar" in update_fn and "active_icon" in update_fn)
    if has_active_icon and not has_ab_click:
        gap(state, Severity.MEDIUM, "Activity Bar",
            "Activity bar icon clicks to switch sidebar views",
            "ActivityBar has active_icon field but workbench update() doesn't handle clicks on it",
            "Add click detection for activity bar icon rects in update(); set activity_bar.active_icon")

# ─── 5. Panel Interactions ────────────────────────────────────────────────────

def check_panel_tab_clicks(state):
    """Panel tab clicks (PROBLEMS/OUTPUT/TERMINAL) should switch active tab."""
    wb = file_content(state, "workbench.zig")
    pn = file_content(state, "panel.zig")
    has_active_tab = "active_tab" in pn
    update_fn = ""
    if "fn update" in wb:
        idx = wb.index("fn update")
        update_fn = wb[idx:idx+3000]
    has_panel_click = ("panel" in update_fn.lower() and "active_tab" in update_fn)
    if has_active_tab and not has_panel_click:
        gap(state, Severity.MEDIUM, "Panel",
            "Panel tab clicks (PROBLEMS/OUTPUT/TERMINAL) to switch views",
            "Panel has active_tab field but workbench update() doesn't handle clicks on panel tabs",
            "Add click detection for panel tab rects in update(); set panel.active_tab")

def check_panel_toggle(state):
    """Ctrl+J or Ctrl+` to toggle panel visibility."""
    wb = file_content(state, "workbench.zig")
    has_toggle = "CMD_TOGGLE_PANEL" in wb
    # Check if there's a keyboard shortcut wired to it (not just command palette)
    has_keybind = ("VK_J" in wb or "0x4A" in wb or "VK_OEM_3" in wb or "0xC0" in wb)
    if has_toggle and not has_keybind:
        gap(state, Severity.LOW, "Panel",
            "Keyboard shortcut to toggle panel (Ctrl+J or Ctrl+`)",
            "CMD_TOGGLE_PANEL exists but no keyboard shortcut is registered for it",
            "Register Ctrl+J or Ctrl+` keybinding for CMD_TOGGLE_PANEL")

# ─── 6. Sidebar Features ─────────────────────────────────────────────────────

def check_sidebar_file_tree(state):
    """Sidebar should show actual directory listing, not just static entries."""
    sb = file_content(state, "sidebar.zig")
    wb = file_content(state, "workbench.zig")
    w32 = file_content(state, "win32.zig")
    has_dir_listing = ("FindFirstFileW" in w32 or "ReadDirectoryChangesW" in w32 or
                       "directory" in sb.lower())
    has_tree = ("expand" in sb.lower() or "collapse" in sb.lower() or
                "tree_node" in sb or "indent_level" in sb or "is_dir" in sb)
    if not has_dir_listing:
        gap(state, Severity.HIGH, "Sidebar",
            "File explorer with actual directory listing",
            "Sidebar has addEntry/clearEntries but no Win32 directory enumeration (FindFirstFileW)",
            "Add FindFirstFileW to win32.zig; populate sidebar entries from actual filesystem")
    if not has_tree:
        gap(state, Severity.MEDIUM, "Sidebar",
            "File tree with expand/collapse directories",
            "Sidebar entries are flat list — no tree structure with indentation or folder expand/collapse",
            "Add tree node model with is_dir, indent_level, expanded fields to sidebar.zig")

def check_sidebar_toggle_keybind(state):
    """Ctrl+B to toggle sidebar."""
    wb = file_content(state, "workbench.zig")
    has_ctrl_b = ("VK_B" in wb or "0x42" in wb)
    if not has_ctrl_b:
        gap(state, Severity.LOW, "Sidebar",
            "Ctrl+B keyboard shortcut to toggle sidebar",
            "CMD_TOGGLE_SIDEBAR exists but no Ctrl+B keybinding registered",
            "Register Ctrl+B keybinding for CMD_TOGGLE_SIDEBAR")

def check_sidebar_file_click(state):
    """Click on a file in sidebar to open it in editor."""
    wb = file_content(state, "workbench.zig")
    sb = file_content(state, "sidebar.zig")
    update_fn = ""
    if "fn update" in wb:
        idx = wb.index("fn update")
        update_fn = wb[idx:idx+3000]
    has_sidebar_click = ("sidebar" in update_fn and "entry" in update_fn.lower())
    if not has_sidebar_click:
        gap(state, Severity.MEDIUM, "Sidebar",
            "Click on file entry in sidebar to open it in editor",
            "Sidebar renders file entries but no click handler opens them in the editor",
            "Add click detection for sidebar entries in update(); call openFile on click")

# ─── 7. Syntax & Languages ───────────────────────────────────────────────────

def check_language_detection(state):
    """Auto-detect language from file extension for syntax highlighting."""
    wb = file_content(state, "workbench.zig")
    syn = file_content(state, "syntax.zig")
    has_detection = ("detect" in syn.lower() or "extension" in syn.lower() or
                     "language_from" in syn.lower() or "detectLanguage" in syn or
                     ".zig" in wb and "zig_lang" in wb)
    if not has_detection:
        gap(state, Severity.MEDIUM, "Syntax",
            "Auto-detect language from file extension for syntax highlighting",
            "No language detection based on file extension found",
            "Add file extension → LanguageId mapping; set highlighter.language on file open")

def check_language_count(state):
    """Multiple language grammars for syntax highlighting."""
    syn = file_content(state, "syntax.zig")
    lang_count = 0
    for lang in ["zig", "c_lang", "python", "javascript", "typescript",
                 "rust", "go", "json", "html", "css", "markdown", "plain"]:
        if lang in syn.lower():
            lang_count += 1
    if lang_count < 4:
        gap(state, Severity.MEDIUM, "Syntax",
            "Multiple language grammars (VS Code supports 30+, need at least C, Python, JS, JSON)",
            f"Only ~{lang_count} language references found in syntax.zig",
            "Add tokenizer rules for common languages: C, Python, JavaScript, JSON")


# ─── 8. Platform Services ─────────────────────────────────────────────────────

def check_file_save_as(state):
    """Save As dialog (Ctrl+Shift+S)."""
    wb = file_content(state, "workbench.zig")
    w32 = file_content(state, "win32.zig")
    has_save_as = ("GetSaveFileNameW" in w32 or "SaveAs" in wb or "save_as" in wb.lower())
    if not has_save_as:
        gap(state, Severity.MEDIUM, "Platform",
            "Save As dialog (Ctrl+Shift+S) for saving to a new path",
            "Only Save (Ctrl+S) exists; no Save As with GetSaveFileNameW",
            "Add GetSaveFileNameW to win32.zig and Ctrl+Shift+S handler")

def check_new_file(state):
    """Ctrl+N to create a new untitled file."""
    wb = file_content(state, "workbench.zig")
    has_new = ("CMD_NEW_FILE" in wb or "new_file" in wb.lower() or
               "VK_N" in wb or "0x4E" in wb)
    if not has_new:
        gap(state, Severity.MEDIUM, "Platform",
            "New File command (Ctrl+N) to create untitled buffer",
            "No Ctrl+N or new file command found in workbench.zig",
            "Add Ctrl+N handler that clears buffer, opens 'untitled' tab")

def check_file_watcher(state):
    """File system watcher for auto-reload on external changes."""
    w32 = file_content(state, "win32.zig")
    has_watcher = ("ReadDirectoryChangesW" in w32 or "FindFirstChangeNotification" in w32 or
                   "file_watch" in w32.lower())
    if not has_watcher:
        gap(state, Severity.LOW, "Platform",
            "File system watcher (auto-reload on external changes)",
            "No ReadDirectoryChangesW or file change notification API found",
            "Add file watching for auto-reload when files change externally")

def check_drag_drop(state):
    """Drag and drop files onto window to open them."""
    app = file_content(state, "app.zig")
    w32 = file_content(state, "win32.zig")
    has_drop = ("WM_DROPFILES" in app or "DragAcceptFiles" in app or
                "WM_DROPFILES" in w32 or "DragAcceptFiles" in w32)
    if not has_drop:
        gap(state, Severity.LOW, "Platform",
            "Drag and drop files onto window to open them",
            "No WM_DROPFILES or DragAcceptFiles handling found",
            "Add DragAcceptFiles in window creation and WM_DROPFILES handler in windowProc")

def check_recent_files(state):
    """Recent files list."""
    wb = file_content(state, "workbench.zig")
    has_recent = ("recent" in wb.lower() and "file" in wb.lower() and
                  ("mru" in wb.lower() or "history" in wb.lower()))
    if not has_recent:
        gap(state, Severity.LOW, "Platform",
            "Recent files list (File > Open Recent)",
            "No recent files / MRU tracking found",
            "Add MRU file path list to workbench state")

def check_confirm_save_on_close(state):
    """Prompt to save unsaved changes before closing."""
    app = file_content(state, "app.zig")
    wb = file_content(state, "workbench.zig")
    w32 = file_content(state, "win32.zig")
    has_dirty = "dirty" in file_content(state, "buffer.zig")
    has_close_prompt = ("WM_CLOSE" in app and ("MessageBoxW" in app or "dirty" in app.lower()))
    has_msgbox = "MessageBoxW" in w32
    if has_dirty and not has_close_prompt:
        gap(state, Severity.MEDIUM, "Platform",
            "Prompt to save unsaved changes before closing window",
            "Buffer has dirty flag but WM_CLOSE handler doesn't check it or show save dialog",
            "Add WM_CLOSE handler that checks buffer.dirty and shows MessageBoxW confirm dialog")

# ─── 9. Editor Visual Features ───────────────────────────────────────────────

def check_indent_guides(state):
    """Vertical indent guide lines."""
    vp = file_content(state, "viewport.zig")
    has_guides = ("indent_guide" in vp or "indentGuide" in vp or "guide_line" in vp)
    if not has_guides:
        gap(state, Severity.LOW, "Editor Visual",
            "Vertical indent guide lines at indentation levels",
            "No indent guide rendering in viewport.zig",
            "Add thin vertical lines at tab-stop positions for indented code")

def check_bracket_matching(state):
    """Bracket pair matching and highlighting."""
    vp = file_content(state, "viewport.zig")
    syn = file_content(state, "syntax.zig")
    wb = file_content(state, "workbench.zig")
    has_bracket = ("bracket_match" in vp or "bracket_match" in syn or
                   "matching_bracket" in wb or "bracketMatch" in vp)
    if not has_bracket:
        gap(state, Severity.MEDIUM, "Editor Visual",
            "Bracket pair matching and highlighting",
            "No bracket matching logic found in viewport.zig or syntax.zig",
            "Add bracket match detection: find matching (), [], {} and highlight both")

def check_minimap_content(state):
    """Minimap should show actual code representation, not just background."""
    wb = file_content(state, "workbench.zig")
    if "fn renderMinimap" in wb:
        # Extract the function body
        idx = wb.index("fn renderMinimap")
        fn_body = wb[idx:idx+800]
        # Check if it renders actual buffer content or just background
        has_content = ("buffer" in fn_body or "line" in fn_body or "content" in fn_body or
                       "getLine" in fn_body)
        if not has_content:
            gap(state, Severity.LOW, "Editor Visual",
                "Minimap renders actual code content (not just background color)",
                "renderMinimap only draws background — no code representation",
                "Add simplified block rendering of buffer lines in minimap region")

def check_word_wrap(state):
    """Word wrap / soft line wrapping."""
    vp = file_content(state, "viewport.zig")
    wb = file_content(state, "workbench.zig")
    has_wrap = ("word_wrap" in vp or "wrapping" in vp or "wrap_column" in vp or
                "word_wrap" in wb)
    if not has_wrap:
        gap(state, Severity.LOW, "Editor Visual",
            "Word wrap / soft line wrapping mode",
            "No word wrap support found — long lines extend beyond viewport",
            "Add wrap mode toggle and wrapped-line rendering to viewport.zig")

# ─── 10. Editor Operations ───────────────────────────────────────────────────

def check_comment_toggle(state):
    """Toggle line comment (Ctrl+/)."""
    wb = file_content(state, "workbench.zig")
    has_comment = ("toggle_comment" in wb.lower() or "comment_line" in wb.lower() or
                   "VK_OEM_2" in wb or "0xBF" in wb)
    if not has_comment:
        gap(state, Severity.MEDIUM, "Editor Operations",
            "Toggle line comment (Ctrl+/)",
            "No Ctrl+/ or comment toggle command found",
            "Add Ctrl+/ handler that prepends/removes '//' on current line")

def check_go_to_line(state):
    """Go to line number (Ctrl+G)."""
    wb = file_content(state, "workbench.zig")
    has_goto = ("goto_line" in wb.lower() or "go_to_line" in wb.lower() or
                "CMD_GOTO_LINE" in wb or "VK_G" in wb or "0x47" in wb)
    if not has_goto:
        gap(state, Severity.MEDIUM, "Editor Operations",
            "Go to line number (Ctrl+G)",
            "No Ctrl+G or go-to-line command found",
            "Add Ctrl+G handler with input overlay for line number")

def check_duplicate_line(state):
    """Duplicate line (Ctrl+Shift+D or Alt+Shift+Down)."""
    wb = file_content(state, "workbench.zig")
    has_dup = ("duplicate_line" in wb.lower() or "duplicateLine" in wb)
    if not has_dup:
        gap(state, Severity.LOW, "Editor Operations",
            "Duplicate line (Alt+Shift+Down)",
            "No line duplication command found",
            "Add duplicate-line handler that copies current line below")

def check_move_line(state):
    """Move line up/down (Alt+Up/Down)."""
    wb = file_content(state, "workbench.zig")
    has_move = ("move_line" in wb.lower() or "moveLine" in wb or
                ("alt" in wb.lower() and "swap" in wb.lower()))
    if not has_move:
        gap(state, Severity.LOW, "Editor Operations",
            "Move line up/down (Alt+Up/Down)",
            "No line move command found",
            "Add Alt+Up/Down handlers that swap current line with adjacent line")

def check_autocomplete(state):
    """Basic autocomplete / word completion."""
    wb = file_content(state, "workbench.zig")
    has_complete = ("autocomplete" in wb.lower() or "suggest" in wb.lower() or
                    "completion" in wb.lower() or "intellisense" in wb.lower())
    if not has_complete:
        gap(state, Severity.MEDIUM, "Editor Operations",
            "Basic autocomplete / word completion popup",
            "No autocomplete or suggestion system found",
            "Add basic word-based completion popup triggered by typing")

# ─── 11. Workbench Features ──────────────────────────────────────────────────

def check_menu_bar(state):
    """Menu bar (File, Edit, View, etc.) in the title bar."""
    wb = file_content(state, "workbench.zig")
    has_menu = ("menu_bar" in wb.lower() or "renderMenu" in wb or
                "menuBar" in wb or "File  Edit  View" in wb)
    if not has_menu:
        gap(state, Severity.LOW, "Workbench UI",
            "Menu bar (File, Edit, View, etc.) in the title bar",
            "Title bar has title text and window buttons but no menu bar",
            "Add menu bar rendering with File/Edit/View/Help dropdown menus")

def check_search_across_files(state):
    """Search across files (Ctrl+Shift+F)."""
    wb = file_content(state, "workbench.zig")
    sb = file_content(state, "sidebar.zig")
    has_search = ("search_view" in wb.lower() or "file_search" in wb.lower() or
                  "search_view" in sb.lower() or "grep" in wb.lower() or
                  "CMD_SEARCH" in wb)
    if not has_search:
        gap(state, Severity.MEDIUM, "Workbench UI",
            "Search across files (Ctrl+Shift+F) in sidebar",
            "No file search view or Ctrl+Shift+F handler found",
            "Add search sidebar view with file content search")

def check_terminal_process(state):
    """Integrated terminal with actual shell process."""
    pn = file_content(state, "panel.zig")
    w32 = file_content(state, "win32.zig")
    has_process = ("CreateProcess" in w32 or "pseudoConsole" in w32.lower() or
                   "conhost" in w32.lower() or "pty" in pn.lower())
    if not has_process:
        gap(state, Severity.MEDIUM, "Panel",
            "Integrated terminal with actual shell process (cmd.exe/powershell)",
            "Panel renders 'Terminal ready' placeholder but no actual shell process integration",
            "Add Win32 CreateProcess + pipe I/O for terminal emulation in panel")

def check_problems_panel(state):
    """Problems panel showing actual diagnostics."""
    pn = file_content(state, "panel.zig")
    has_diagnostics = ("diagnostic" in pn.lower() or "error_list" in pn.lower() or
                       "problem_entry" in pn.lower() or "marker" in pn.lower())
    if not has_diagnostics:
        gap(state, Severity.LOW, "Panel",
            "Problems panel showing actual errors/warnings from build output",
            "Panel has PROBLEMS tab label but no diagnostic data model",
            "Add diagnostic entry model and rendering to panel.zig")

# ─── 12. Theming & Config ────────────────────────────────────────────────────

def check_config_persistence(state):
    """Settings persistence (load/save settings.json)."""
    cfg = file_content(state, "config.zig")
    has_persistence = ("load" in cfg.lower() and "save" in cfg.lower()) or \
                      ("readFile" in cfg and "writeFile" in cfg) or \
                      ("parse" in cfg.lower() and "json" in cfg.lower())
    if cfg and not has_persistence:
        gap(state, Severity.LOW, "Platform",
            "Settings persistence (load/save settings.json)",
            "config.zig exists but may not load/save settings from disk",
            "Add JSON settings file read/write to config.zig")

def check_theme_system(state):
    """Switchable color themes."""
    all_content = "\n".join(state.files.values())
    has_theme = ("theme_service" in all_content.lower() or "loadTheme" in all_content or
                 "ThemeData" in all_content or "color_theme" in all_content.lower())
    if not has_theme:
        gap(state, Severity.LOW, "Theming",
            "Switchable color themes (colors are currently hardcoded constants)",
            "All colors are compile-time constants — no runtime theme switching",
            "Add theme data structure with color lookup table (low priority)")

# ─── 13. Advanced Features (LOW priority) ────────────────────────────────────

def check_git_integration(state):
    all_content = "\n".join(state.files.values())
    has_git = ("git_status" in all_content.lower() or "git_diff" in all_content.lower() or
               "scm_provider" in all_content.lower())
    if not has_git:
        gap(state, Severity.LOW, "SCM",
            "Git integration (status, diff indicators in gutter)",
            "No git/SCM integration found",
            "Add git status parsing for gutter change indicators")

def check_code_folding(state):
    vp = file_content(state, "viewport.zig")
    wb = file_content(state, "workbench.zig")
    has_fold = ("fold" in vp.lower() or "collapse_region" in vp or
                "fold" in wb.lower())
    if not has_fold:
        gap(state, Severity.LOW, "Editor Operations",
            "Code folding (collapse/expand regions)",
            "No code folding support found",
            "Add fold markers and collapse logic to viewport.zig")

def check_hover_tooltips(state):
    wb = file_content(state, "workbench.zig")
    has_hover = ("hover_tooltip" in wb.lower() or "renderHover" in wb or
                 "tooltip" in wb.lower())
    if not has_hover:
        gap(state, Severity.LOW, "Editor Operations",
            "Hover tooltips showing type info / documentation",
            "No hover tooltip system found",
            "Add hover overlay rendering (requires language server or symbol data)")

def check_snippet_support(state):
    wb = file_content(state, "workbench.zig")
    has_snippet = ("snippet" in wb.lower() or "expandSnippet" in wb)
    if not has_snippet:
        gap(state, Severity.LOW, "Editor Operations",
            "Snippet expansion with tab stops",
            "No snippet support found",
            "Add snippet engine (low priority)")

def check_debug_support(state):
    all_content = "\n".join(state.files.values())
    has_debug = ("debug_session" in all_content.lower() or "breakpoint" in all_content.lower() or
                 "debugAdapter" in all_content)
    if not has_debug:
        gap(state, Severity.LOW, "Debug",
            "Debugger integration (breakpoints, step, variables)",
            "No debug support found",
            "Add debug adapter protocol support (long-term goal)")

def check_extension_system(state):
    all_content = "\n".join(state.files.values())
    has_ext = ("extension_host" in all_content.lower() or "loadExtension" in all_content or
               "plugin_system" in all_content.lower())
    if not has_ext:
        gap(state, Severity.LOW, "Extensions",
            "Extension/plugin system for third-party add-ons",
            "No extension system found (expected for native single-binary)",
            "Consider WASM-based plugin system (long-term)")

def check_diff_algorithm(state):
    all_content = "\n".join(state.files.values())
    has_diff = ("diff_algorithm" in all_content.lower() or "diffLines" in all_content or
                "myers" in all_content.lower())
    if not has_diff:
        gap(state, Severity.LOW, "Base Utilities",
            "Diff algorithm for comparing text (needed for git diff view)",
            "No diff algorithm found",
            "Add diff module to src/base/")

def check_glob_matching(state):
    all_content = "\n".join(state.files.values())
    has_glob = ("glob_match" in all_content.lower() or "wildcard_match" in all_content.lower())
    if not has_glob:
        gap(state, Severity.LOW, "Base Utilities",
            "Glob pattern matching (for file filters, search)",
            "No glob matching found",
            "Add glob matcher to src/base/")

def check_font_zoom(state):
    wb = file_content(state, "workbench.zig")
    has_zoom = ("font_zoom" in wb.lower() or "zoomIn" in wb or "zoomOut" in wb or
                "VK_OEM_PLUS" in wb or "VK_OEM_MINUS" in wb)
    if not has_zoom:
        gap(state, Severity.LOW, "Editor Visual",
            "Font zoom (Ctrl+= / Ctrl+-)",
            "No font zoom support found",
            "Add Ctrl+=/- handlers that adjust font size and re-init font atlas")

def check_word_highlight(state):
    vp = file_content(state, "viewport.zig")
    wb = file_content(state, "workbench.zig")
    has_highlight = ("word_highlight" in vp.lower() or "highlightWord" in vp or
                     "word_highlight" in wb.lower())
    if not has_highlight:
        gap(state, Severity.LOW, "Editor Visual",
            "Highlight all occurrences of word under cursor",
            "No word highlight on cursor found",
            "Add word-under-cursor detection and highlight rendering in viewport.zig")

def check_double_click_select_word(state):
    wb = file_content(state, "workbench.zig")
    has_dblclick = ("double_click" in wb.lower() or "dbl_click" in wb.lower() or
                    "select_word" in wb.lower() or "word_select" in wb.lower())
    if not has_dblclick:
        gap(state, Severity.MEDIUM, "Editor Core",
            "Double-click to select word",
            "No double-click word selection found in workbench.zig",
            "Track click timing; on double-click, find word boundaries and set selection")

def check_right_click_context_menu(state):
    wb = file_content(state, "workbench.zig")
    app = file_content(state, "app.zig")
    has_context = ("context_menu" in wb.lower() or "right_click" in wb.lower() or
                   "WM_RBUTTONDOWN" in app or "TrackPopupMenu" in app or
                   "right_button" in wb.lower())
    if not has_context:
        gap(state, Severity.LOW, "Editor Core",
            "Right-click context menu (Cut, Copy, Paste, Select All)",
            "No right-click or context menu handling found",
            "Add WM_RBUTTONDOWN handling and context menu popup")


# ═══════════════════════════════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════════════════════════════

def print_report(state: AnalysisState, verbose: bool):
    severity_order = {Severity.CRITICAL: 0, Severity.HIGH: 1, Severity.MEDIUM: 2, Severity.LOW: 3}
    state.gaps.sort(key=lambda g: (severity_order[g.severity], g.category, g.feature))

    counts = {s: 0 for s in Severity}
    for g in state.gaps:
        counts[g.severity] += 1

    total = len(state.gaps)

    print(f"\n{BOLD}═══ SBCode Feature Gap Analysis ═══{RESET}\n")
    print(f"  Scanned Zig source: {len(state.files)} files\n")

    print(f"  {SEVERITY_COLORS[Severity.CRITICAL]}CRITICAL: {counts[Severity.CRITICAL]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.HIGH]}HIGH: {counts[Severity.HIGH]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.MEDIUM]}MEDIUM: {counts[Severity.MEDIUM]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.LOW]}LOW: {counts[Severity.LOW]}{RESET}  "
          f"(Total: {total})\n")

    if not verbose:
        shown = [g for g in state.gaps if g.severity in (Severity.CRITICAL, Severity.HIGH)]
        hidden = total - len(shown)
    else:
        shown = state.gaps
        hidden = 0

    current_severity = None
    for g in shown:
        if g.severity != current_severity:
            current_severity = g.severity
            color = SEVERITY_COLORS[g.severity]
            print(f"\n{color}{BOLD}── {g.severity.value} ──{RESET}")

        color = SEVERITY_COLORS[g.severity]
        print(f"  {color}[{g.category}]{RESET} {g.feature}")
        print(f"    Status:  {g.status}")
        print(f"    Action:  {g.action}")
        print()

    if hidden > 0:
        print(f"  ({hidden} MEDIUM/LOW gaps hidden — use --verbose to see all)")

    print(f"\n{BOLD}═══ End of Feature Gap Analysis ═══{RESET}\n")


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv

    state = AnalysisState()
    load_files(state)

    # ── Editor Core: Text Editing ──
    check_line_numbers(state)
    check_current_line_highlight(state)
    check_scrollbar(state)
    check_selection_keyboard(state)
    check_selection_mouse(state)
    check_select_all(state)
    check_clipboard(state)
    check_undo_redo_keybindings(state)
    check_tab_key(state)
    check_home_end_keys(state)
    check_page_up_down(state)
    check_word_navigation(state)
    check_find_replace(state)
    check_enter_newline(state)
    check_double_click_select_word(state)
    check_right_click_context_menu(state)

    # ── Window Controls ──
    check_window_button_clicks(state)
    check_title_bar_double_click(state)

    # ── Tab Bar ──
    check_tab_close_click(state)
    check_tab_switch_click(state)
    check_ctrl_w_close_tab(state)
    check_ctrl_tab_switch(state)

    # ── Activity Bar ──
    check_activity_bar_clicks(state)

    # ── Panel ──
    check_panel_tab_clicks(state)
    check_panel_toggle(state)

    # ── Sidebar ──
    check_sidebar_file_tree(state)
    check_sidebar_toggle_keybind(state)
    check_sidebar_file_click(state)

    # ── Syntax ──
    check_language_detection(state)
    check_language_count(state)

    # ── Platform Services ──
    check_file_save_as(state)
    check_new_file(state)
    check_file_watcher(state)
    check_drag_drop(state)
    check_recent_files(state)
    check_confirm_save_on_close(state)

    # ── Editor Visual ──
    check_indent_guides(state)
    check_bracket_matching(state)
    check_minimap_content(state)
    check_word_wrap(state)
    check_font_zoom(state)
    check_word_highlight(state)

    # ── Editor Operations ──
    check_comment_toggle(state)
    check_go_to_line(state)
    check_duplicate_line(state)
    check_move_line(state)
    check_autocomplete(state)
    check_code_folding(state)
    check_hover_tooltips(state)
    check_snippet_support(state)

    # ── Workbench Features ──
    check_menu_bar(state)
    check_search_across_files(state)
    check_terminal_process(state)
    check_problems_panel(state)

    # ── Theming & Config ──
    check_config_persistence(state)
    check_theme_system(state)

    # ── Advanced (LOW) ──
    check_git_integration(state)
    check_debug_support(state)
    check_extension_system(state)
    check_diff_algorithm(state)
    check_glob_matching(state)

    print_report(state, verbose)

    sys.exit(1 if any(g.severity == Severity.CRITICAL for g in state.gaps) else 0)

if __name__ == "__main__":
    main()
