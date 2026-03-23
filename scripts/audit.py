#!/usr/bin/env python3
"""
SBCode Implementation Audit Script

Heuristically detects incomplete, stubbed, or substandard code in the
Zig source tree and reports concrete findings with file:line references.

Usage:
    python scripts/audit.py [--verbose]
"""

import os
import re
import sys
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

# ─── Configuration ────────────────────────────────────────────────────────────

ZIG_SRC_DIRS = ["src/base", "src/editor", "src/platform", "src/renderer", "src/workbench"]
ZIG_APP_FILES = ["src/app.zig", "src/main.zig"]
BUILD_FILE = "build.zig"
TEST_ROOT = "src/tests/root.zig"

class Severity(Enum):
    CRITICAL = "CRITICAL"   # Broken or missing core functionality
    HIGH     = "HIGH"       # Significant gap, user-visible impact
    MEDIUM   = "MEDIUM"     # Stub/placeholder, works but incomplete
    LOW      = "LOW"        # Style, minor quality issue

SEVERITY_COLORS = {
    Severity.CRITICAL: "\033[91m",  # red
    Severity.HIGH:     "\033[93m",  # yellow
    Severity.MEDIUM:   "\033[96m",  # cyan
    Severity.LOW:      "\033[90m",  # gray
}
RESET = "\033[0m"
BOLD  = "\033[1m"

@dataclass
class Finding:
    severity: Severity
    file: str
    line: Optional[int]
    category: str
    message: str

@dataclass
class AuditState:
    findings: list = field(default_factory=list)
    zig_files: list = field(default_factory=list)
    test_files: list = field(default_factory=list)
    module_names: set = field(default_factory=set)
    test_root_imports: set = field(default_factory=set)
    build_module_defs: set = field(default_factory=set)

# ─── File collection ──────────────────────────────────────────────────────────

def collect_zig_files(state: AuditState):
    for d in ZIG_SRC_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".zig"):
                state.zig_files.append(os.path.join(d, f))
    for f in ZIG_APP_FILES:
        if os.path.isfile(f):
            state.zig_files.append(f)

    test_dir = "src/tests"
    if os.path.isdir(test_dir):
        for f in sorted(os.listdir(test_dir)):
            if f.endswith(".zig"):
                state.test_files.append(os.path.join(test_dir, f))

def add(state: AuditState, severity, file, line, category, message):
    state.findings.append(Finding(severity, file, line, category, message))

# ─── Heuristic checks ────────────────────────────────────────────────────────

def check_stub_markers(state: AuditState):
    """Detect TODO, FIXME, stub, placeholder, not implemented markers."""
    patterns = [
        (r'\bTODO\b', "TODO marker"),
        (r'\bFIXME\b', "FIXME marker"),
        (r'\bHACK\b', "HACK marker"),
        (r'\bXXX\b', "XXX marker"),
        (r'\bnot.implemented\b', "Not implemented marker"),
        (r'\bunimplemented\b', "Unimplemented marker"),
    ]
    for fpath in state.zig_files + state.test_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f, 1):
                for pat, desc in patterns:
                    if re.search(pat, line, re.IGNORECASE):
                        add(state, Severity.HIGH, fpath, i, "Stub Marker",
                            f"{desc}: {line.strip()[:100]}")

def check_placeholder_content(state: AuditState):
    """Detect files with hardcoded placeholder/fake data used in rendering."""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        # Count placeholder constant declarations (not every reference)
        decls = re.findall(r'const (PLACEHOLDER_\w+)', content)
        if decls:
            names = ", ".join(sorted(set(decls)))
            add(state, Severity.MEDIUM, fpath, None, "Placeholder",
                f"Contains hardcoded placeholder data: {names} — should be replaced with real content")

def check_ignored_params(state: AuditState):
    """Detect functions that discard self or important parameters with _ = param."""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # _ = self means the struct method doesn't use its own state
            if stripped == "_ = self;":
                add(state, Severity.MEDIUM, fpath, i, "Unused Self",
                    "Method discards self — likely a stub that ignores struct state")
            # _ = font_atlas means a render function doesn't actually render text
            elif stripped == "_ = font_atlas;":
                add(state, Severity.MEDIUM, fpath, i, "Unused Param",
                    "Render function discards font_atlas — no text rendering")

def check_render_delegation(state: AuditState):
    """Check if workbench.render() delegates to sub-component renderers or just draws flat rects."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Check if render() calls sub-component render methods
    expected_delegations = {
        "activity_bar": (r'\.activity_bar\.render\(', "ActivityBar.render() not called — draws flat rect instead"),
        "sidebar":      (r'\.sidebar\.render\(',      "Sidebar.render() not called — draws flat rect instead"),
        "panel":        (r'\.panel\.render\(',         "Panel.render() not called — draws flat rect instead"),
        "status_bar":   (r'\.status_bar\.render\(',    "StatusBar.render() not called — draws flat rect instead"),
    }
    for component, (pattern, msg) in expected_delegations.items():
        if not re.search(pattern, content):
            add(state, Severity.HIGH, wb_path, None, "Missing Delegation",
                f"{msg} (sub-component has a render method but workbench doesn't call it)")

def check_missing_scroll_handling(state: AuditState):
    """Check if mouse wheel scroll_delta is consumed to update scroll_top."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "scroll_delta" not in content:
        add(state, Severity.HIGH, wb_path, None, "Missing Feature",
            "Mouse wheel scroll_delta is never consumed — scrolling doesn't work. "
            "input.scroll_delta is set by WM_MOUSEWHEEL but workbench.update() never reads it to adjust scroll_top")

def check_missing_backspace_in_editor(state: AuditState):
    """Check if backspace/delete works in the editor buffer (not just command palette)."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Check if handleTextInput or handleCursorMovement handles backspace for buffer editing
    # VK_BACK is only handled inside handleCommandPaletteInput
    # Look for buffer.delete calls outside of command palette context
    if "self.buffer.delete" not in content:
        add(state, Severity.HIGH, wb_path, None, "Missing Feature",
            "Backspace/Delete key never calls buffer.delete() — text deletion doesn't work in the editor. "
            "VK_BACK is only handled for command palette input, not for buffer editing")

def check_missing_file_dialog(state: AuditState):
    """Check if Ctrl+O actually opens a file dialog."""
    app_path = "src/app.zig"
    wb_path = "src/workbench/workbench.zig"
    for fpath in [app_path, wb_path]:
        if not os.path.isfile(fpath):
            continue
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        if "GetOpenFileName" in content or "IFileDialog" in content or "OPENFILENAME" in content:
            return
    add(state, Severity.HIGH, wb_path, None, "Missing Feature",
        "Ctrl+O (CMD_OPEN_FILE) is a no-op — no Win32 file dialog is implemented. "
        "The command is registered but dispatchCommand does nothing for it")

def check_missing_window_controls(state: AuditState):
    """Check for close/minimize/maximize buttons on the custom title bar."""
    # Since WS_POPUP is used (borderless), the app needs custom window controls
    app_path = "src/app.zig"
    wb_path = "src/workbench/workbench.zig"
    all_content = ""
    for fpath in [app_path, wb_path] + [
        "src/workbench/layout.zig",
    ]:
        if os.path.isfile(fpath):
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                all_content += f.read()

    if not re.search(r'close.{0,10}button|minimize.{0,10}button|maximize.{0,10}button|window.{0,10}control|title_bar_button|renderWindowControls', all_content, re.IGNORECASE):
        add(state, Severity.CRITICAL, "src/workbench/workbench.zig", None, "Missing Feature",
            "No close/minimize/maximize buttons rendered on the custom title bar. "
            "Window uses WS_POPUP (borderless) so there are no native window controls — "
            "user cannot close the window without Alt+F4 or taskbar")

def check_missing_window_resize(state: AuditState):
    """Check if borderless window supports edge-drag resizing."""
    app_path = "src/app.zig"
    if not os.path.isfile(app_path):
        return
    with open(app_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    resize_indicators = ["HTLEFT", "HTRIGHT", "HTTOP", "HTBOTTOM", "HTTOPLEFT",
                         "HTTOPRIGHT", "HTBOTTOMLEFT", "HTBOTTOMRIGHT", "WS_THICKFRAME"]
    if not any(ind in content for ind in resize_indicators):
        add(state, Severity.HIGH, app_path, None, "Missing Feature",
            "Borderless window (WS_POPUP) has no edge-drag resize handling. "
            "WM_NCHITTEST only returns HTCAPTION for title bar drag — no resize hit zones")

def check_layout_visibility_sync(state: AuditState):
    """Check if workbench syncs sidebar/panel visibility to layout before render."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    # Layout has its own sidebar_visible/panel_visible flags
    # Workbench has its own sidebar_visible/panel_visible flags
    # They need to be synced before layout.recompute or render
    if "layout.sidebar_visible" not in content and "layout.panel_visible" not in content:
        add(state, Severity.HIGH, wb_path, None, "State Sync Bug",
            "Workbench.sidebar_visible/panel_visible are never synced to LayoutState. "
            "Toggle sidebar/panel changes workbench flags but layout still computes regions "
            "as if they're visible — the regions just aren't drawn, causing layout gaps")

def check_status_bar_cursor_sync(state: AuditState):
    """Check if status bar line/col is updated from cursor state."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "status_bar.line" not in content and "status_bar.col" not in content:
        add(state, Severity.MEDIUM, wb_path, None, "Missing Sync",
            "StatusBar.line/col are never updated from CursorState — "
            "status bar always shows 'Ln 1, Col 1' regardless of cursor position")

def check_callconv(state: AuditState):
    """Check that Win32/GL externs use callconv(.c) not callconv(.C)."""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f, 1):
                if 'callconv(.C)' in line and 'extern' in line:
                    add(state, Severity.LOW, fpath, i, "Coding Standard",
                        f"Uses callconv(.C) instead of callconv(.c): {line.strip()[:100]}")

def check_file_path_imports(state: AuditState):
    """Check for @import("../...") file path imports instead of named module imports."""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f, 1):
                if re.search(r'@import\("\.\./', line):
                    add(state, Severity.LOW, fpath, i, "Coding Standard",
                        f"Uses file path import instead of named module: {line.strip()[:100]}")

def check_std_io_at_runtime(state: AuditState):
    """Check for std lib I/O usage at runtime (not in tests)."""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        in_test = False
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("test "):
                in_test = True
            if in_test:
                if stripped == "}":
                    # Rough heuristic: top-level closing brace ends test
                    if not line.startswith(" ") and not line.startswith("\t"):
                        in_test = False
                continue
            if re.search(r'std\.(debug|io)\.(print|write)', stripped):
                add(state, Severity.LOW, fpath, i, "Coding Standard",
                    f"std lib I/O used at runtime (should be zero std I/O): {stripped[:100]}")

def check_module_wiring(state: AuditState):
    """Check that all source modules are defined in build.zig and imported in test root."""
    if not os.path.isfile(BUILD_FILE):
        return
    with open(BUILD_FILE, "r", encoding="utf-8", errors="replace") as f:
        build_content = f.read()

    if not os.path.isfile(TEST_ROOT):
        return
    with open(TEST_ROOT, "r", encoding="utf-8", errors="replace") as f:
        test_content = f.read()

    # Extract module names from build.zig (const xxx_mod = b.createModule)
    build_modules = set(re.findall(r'const (\w+)_mod = b\.createModule', build_content))

    # Extract imports from test root
    test_imports = set(re.findall(r'@import\("(\w+)"\)', test_content))

    # Map zig files to expected module names
    for fpath in state.zig_files:
        basename = os.path.splitext(os.path.basename(fpath))[0]
        # Skip main.zig and app.zig from test root check (they have Win32 deps)
        if basename in ("main",):
            continue
        if basename not in build_modules and basename + "_prop_test" not in build_modules:
            add(state, Severity.MEDIUM, fpath, None, "Module Wiring",
                f"Module '{basename}' may not be defined in build.zig (no '{basename}_mod' found)")

def check_empty_render_bodies(state: AuditState):
    """Detect render functions that only draw a background rect without content."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Title bar just gets renderRegionBackground — no text, no buttons
    if "renderRegionBackground(layout.getRegion(.title_bar)" in content:
        # Check if there's any title bar text rendering after it
        title_section = content.split("// 1. Title bar")[1].split("// 2.")[0] if "// 1. Title bar" in content else ""
        if "renderText" not in title_section and "font_atlas" not in title_section:
            add(state, Severity.MEDIUM, wb_path, None, "Incomplete Render",
                "Title bar only draws a background rectangle — no title text, "
                "no window control buttons, no app icon")

def check_missing_cursor_blink(state: AuditState):
    """Check if cursor rendering has blink support."""
    vp_path = "src/editor/viewport.zig"
    if not os.path.isfile(vp_path):
        return
    with open(vp_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "blink" not in content.lower() and "delta_time" not in content:
        add(state, Severity.LOW, vp_path, None, "Polish",
            "Cursor has no blink animation — always visible (minor UX issue)")

def check_missing_selection_rendering(state: AuditState):
    """Check if selection highlight is actually rendered."""
    vp_path = "src/editor/viewport.zig"
    if not os.path.isfile(vp_path):
        return
    with open(vp_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "selection" not in content.lower() or "drawSelection" not in content:
        # Check for any selection-related rendering
        if not re.search(r'selection|highlight.*rect|sel_start|sel_end', content, re.IGNORECASE):
            add(state, Severity.MEDIUM, vp_path, None, "Missing Feature",
                "No selection highlight rendering found in viewport")

def check_undo_redo(state: AuditState):
    """Check if undo/redo is implemented."""
    all_content = ""
    for fpath in state.zig_files:
        with open(fpath, "r", encoding="utf-8", errors="replace") as f:
            all_content += f.read()
    if "undo" not in all_content.lower():
        add(state, Severity.MEDIUM, "src/editor/buffer.zig", None, "Missing Feature",
            "No undo/redo system implemented — text edits are irreversible")

def check_tab_close(state: AuditState):
    """Check if tabs can be closed."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "closeTab" not in content and "close_tab" not in content:
        add(state, Severity.MEDIUM, wb_path, None, "Missing Feature",
            "No tab close functionality — tabs can be opened but never closed")

def check_mouse_click_positioning(state: AuditState):
    """Check if mouse clicks position the cursor in the editor."""
    wb_path = "src/workbench/workbench.zig"
    if not os.path.isfile(wb_path):
        return
    with open(wb_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    if "left_button_pressed" not in content and "mouse_x" not in content:
        add(state, Severity.MEDIUM, wb_path, None, "Missing Feature",
            "Mouse clicks don't position the cursor — no click-to-place-cursor handling")

# ─── Report ───────────────────────────────────────────────────────────────────

def print_report(state: AuditState, verbose: bool):
    # Sort by severity, then file
    severity_order = {Severity.CRITICAL: 0, Severity.HIGH: 1, Severity.MEDIUM: 2, Severity.LOW: 3}
    state.findings.sort(key=lambda f: (severity_order[f.severity], f.file, f.line or 0))

    # Deduplicate
    seen = set()
    unique = []
    for f in state.findings:
        key = (f.file, f.line, f.message[:60])
        if key not in seen:
            seen.add(key)
            unique.append(f)
    state.findings = unique

    counts = {s: 0 for s in Severity}
    for f in state.findings:
        counts[f.severity] += 1

    print(f"\n{BOLD}═══ SBCode Implementation Audit ═══{RESET}\n")
    print(f"  Scanned {len(state.zig_files)} source files, {len(state.test_files)} test files\n")

    # Summary
    print(f"  {SEVERITY_COLORS[Severity.CRITICAL]}CRITICAL: {counts[Severity.CRITICAL]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.HIGH]}HIGH: {counts[Severity.HIGH]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.MEDIUM]}MEDIUM: {counts[Severity.MEDIUM]}{RESET}  "
          f"{SEVERITY_COLORS[Severity.LOW]}LOW: {counts[Severity.LOW]}{RESET}\n")

    if not verbose:
        # Only show CRITICAL and HIGH by default
        shown = [f for f in state.findings if f.severity in (Severity.CRITICAL, Severity.HIGH)]
        hidden = len(state.findings) - len(shown)
    else:
        shown = state.findings
        hidden = 0

    current_severity = None
    for f in shown:
        if f.severity != current_severity:
            current_severity = f.severity
            color = SEVERITY_COLORS[f.severity]
            print(f"\n{color}{BOLD}── {f.severity.value} ──{RESET}")

        loc = f"{f.file}:{f.line}" if f.line else f.file
        color = SEVERITY_COLORS[f.severity]
        print(f"  {color}[{f.category}]{RESET} {loc}")
        print(f"    {f.message}")

    if hidden > 0:
        print(f"\n  ({hidden} MEDIUM/LOW findings hidden — use --verbose to see all)")

    print(f"\n{BOLD}═══ End of Audit ═══{RESET}\n")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv

    state = AuditState()
    collect_zig_files(state)

    # Run all checks
    check_stub_markers(state)
    check_placeholder_content(state)
    check_ignored_params(state)
    check_render_delegation(state)
    check_missing_scroll_handling(state)
    check_missing_backspace_in_editor(state)
    check_missing_file_dialog(state)
    check_missing_window_controls(state)
    check_missing_window_resize(state)
    check_layout_visibility_sync(state)
    check_status_bar_cursor_sync(state)
    check_callconv(state)
    check_file_path_imports(state)
    check_std_io_at_runtime(state)
    check_module_wiring(state)
    check_empty_render_bodies(state)
    check_missing_cursor_blink(state)
    check_missing_selection_rendering(state)
    check_undo_redo(state)
    check_tab_close(state)
    check_mouse_click_positioning(state)

    print_report(state, verbose)

    # Exit code: 1 if any CRITICAL findings
    sys.exit(1 if any(f.severity == Severity.CRITICAL for f in state.findings) else 0)

if __name__ == "__main__":
    main()
