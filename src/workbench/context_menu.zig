// src/workbench/context_menu.zig — VS Code-style context menus
//
// Pure Zig, zero allocations. Uses Win32 native popup menus (TrackPopupMenu)
// to display context menus matching VS Code's naming and structure.
// Each menu zone (editor, tab, sidebar, panel, title bar) has its own
// item set and command dispatch.

const win32 = @import("win32");

// =============================================================================
// Menu command IDs — unique per context zone, starting at 100 to avoid
// collision with workbench CMD_* constants (0–99).
// =============================================================================

/// Editor right-click context menu commands.
pub const EditorCmd = enum(u16) {
    // Navigation group
    go_to_definition = 100,
    go_to_declaration = 101,
    go_to_type_definition = 102,
    go_to_implementations = 103,
    go_to_references = 104,
    // ---
    peek_definition = 110,
    peek_declaration = 111,
    peek_type_definition = 112,
    peek_implementations = 113,
    peek_references = 114,
    // ---
    rename_symbol = 120,
    change_all_occurrences = 121,
    // ---
    cut = 130,
    copy = 131,
    paste = 132,
    // ---
    format_document = 140,
    format_selection = 141,
    // ---
    refactor = 150,
    source_action = 151,
    // ---
    toggle_line_comment = 160,
    toggle_block_comment = 161,
    // ---
    command_palette = 170,
};

/// Tab right-click context menu commands.
pub const TabCmd = enum(u16) {
    close = 200,
    close_others = 201,
    close_to_the_right = 202,
    close_saved = 203,
    close_all = 204,
    // ---
    copy_path = 210,
    copy_relative_path = 211,
    // ---
    reveal_in_explorer = 220,
    // ---
    keep_open = 230,
    // ---
    split_up = 240,
    split_down = 241,
    split_left = 242,
    split_right = 243,
};

/// Sidebar / Explorer right-click context menu commands.
pub const SidebarCmd = enum(u16) {
    new_file = 300,
    new_folder = 301,
    // ---
    cut = 310,
    copy = 311,
    paste = 312,
    // ---
    copy_path = 320,
    copy_relative_path = 321,
    // ---
    rename = 330,
    delete = 331,
    // ---
    reveal_in_file_explorer = 340,
    open_in_integrated_terminal = 341,
    // ---
    find_in_folder = 350,
    // ---
    collapse_folders = 360,
};

/// Panel right-click context menu commands.
pub const PanelCmd = enum(u16) {
    clear = 400,
    copy_all = 401,
    // ---
    select_all = 410,
    // ---
    scroll_to_bottom = 420,
    // ---
    split_terminal = 430,
    new_terminal = 431,
    kill_terminal = 432,
};

/// Title bar right-click context menu commands.
pub const TitleBarCmd = enum(u16) {
    restore = 500,
    minimize = 501,
    maximize = 502,
    // ---
    close = 510,
};

// =============================================================================
// Menu bar command IDs — File, Edit, Selection, View, Go, Run, Terminal, Help
// IDs 600–999 reserved for menu bar dropdowns.
// =============================================================================

pub const FileCmd = enum(u16) {
    new_file = 600,
    new_window = 601,
    open_file = 602,
    open_folder = 603,
    open_recent = 604,
    // ---
    save = 610,
    save_as = 611,
    save_all = 612,
    // ---
    auto_save = 620,
    // ---
    preferences = 625,
    // ---
    revert_file = 630,
    close_editor = 631,
    close_folder = 632,
    close_window = 633,
    // ---
    exit = 640,
};

pub const EditCmd = enum(u16) {
    undo = 700,
    redo = 701,
    // ---
    cut = 710,
    copy = 711,
    paste = 712,
    // ---
    find = 720,
    replace = 721,
    // ---
    find_in_files = 730,
    replace_in_files = 731,
    // ---
    toggle_line_comment = 740,
    toggle_block_comment = 741,
    emmet_expand = 742,
};

pub const SelectionCmd = enum(u16) {
    select_all = 800,
    expand_selection = 801,
    shrink_selection = 802,
    // ---
    copy_line_up = 810,
    copy_line_down = 811,
    move_line_up = 812,
    move_line_down = 813,
    duplicate_selection = 814,
    // ---
    add_cursor_above = 820,
    add_cursor_below = 821,
    add_cursors_to_line_ends = 822,
    add_next_occurrence = 823,
    add_all_occurrences = 824,
    // ---
    column_selection_mode = 830,
};

pub const ViewCmd = enum(u16) {
    command_palette = 900,
    open_view = 901,
    // ---
    appearance = 910,
    editor_layout = 911,
    // ---
    explorer = 920,
    search = 921,
    scm = 922,
    run_and_debug = 923,
    extensions = 924,
    // ---
    problems = 930,
    output = 931,
    debug_console = 932,
    terminal = 933,
    // ---
    word_wrap = 940,
    minimap = 941,
    breadcrumbs = 942,
    // ---
    zoom_in = 950,
    zoom_out = 951,
    reset_zoom = 952,
    // ---
    full_screen = 960,
};

pub const GoCmd = enum(u16) {
    back = 1000,
    forward = 1001,
    last_edit_location = 1002,
    // ---
    go_to_file = 1010,
    go_to_symbol_in_workspace = 1011,
    // ---
    go_to_symbol_in_editor = 1020,
    go_to_definition = 1021,
    go_to_declaration = 1022,
    go_to_type_definition = 1023,
    go_to_implementations = 1024,
    go_to_references = 1025,
    // ---
    go_to_line = 1030,
    go_to_bracket = 1031,
    // ---
    next_problem = 1040,
    previous_problem = 1041,
    // ---
    next_change = 1050,
    previous_change = 1051,
};

pub const RunCmd = enum(u16) {
    start_debugging = 1100,
    run_without_debugging = 1101,
    stop_debugging = 1102,
    restart_debugging = 1103,
    // ---
    open_configurations = 1110,
    add_configuration = 1111,
    // ---
    step_over = 1120,
    step_into = 1121,
    step_out = 1122,
    @"continue" = 1123,
    // ---
    toggle_breakpoint = 1130,
    new_breakpoint = 1131,
    // ---
    enable_all_breakpoints = 1140,
    disable_all_breakpoints = 1141,
    remove_all_breakpoints = 1142,
    // ---
    install_debuggers = 1150,
};

pub const TerminalCmd = enum(u16) {
    new_terminal = 1200,
    split_terminal = 1201,
    // ---
    run_task = 1210,
    run_build_task = 1211,
    // ---
    run_active_file = 1220,
    run_selected_text = 1221,
    // ---
    configure_tasks = 1230,
};

pub const HelpCmd = enum(u16) {
    welcome = 1300,
    show_all_commands = 1301,
    documentation = 1302,
    // ---
    release_notes = 1310,
    // ---
    keyboard_shortcuts = 1320,
    // ---
    report_issue = 1330,
    // ---
    toggle_developer_tools = 1340,
    // ---
    about = 1350,
};

/// Menu bar item index (which top-level menu was clicked).
pub const MenuBarIndex = enum(u8) {
    file = 0,
    edit = 1,
    selection = 2,
    view = 3,
    go = 4,
    run = 5,
    terminal = 6,
    help = 7,
};

/// Menu bar labels — matches VS Code exactly.
pub const MENU_BAR_LABELS = [_][]const u8{
    "File", "Edit", "Selection", "View", "Go", "Run", "Terminal", "Help",
};

pub const MENU_BAR_COUNT: u8 = MENU_BAR_LABELS.len;

/// Padding between menu bar items (pixels).
pub const MENU_BAR_PAD: i32 = 10;

/// Icon space before first menu item (icon width + padding).
/// The icon occupies ~2 cell widths + padding on each side.
pub const ICON_SPACE_CELLS: i32 = 4; // cells reserved for icon area

// =============================================================================
// Menu zone — which context menu to show based on click location.
// =============================================================================

pub const MenuZone = enum {
    editor,
    tab,
    sidebar,
    panel,
    title_bar,
};

// =============================================================================
// Menu item definition (comptime, no allocations).
// =============================================================================

pub const MenuItem = struct {
    id: u16,
    label: []const u8,
    shortcut: []const u8 = "",
    separator_after: bool = false,
    grayed: bool = false,
};

// =============================================================================
// Editor context menu items — matches VS Code exactly.
// =============================================================================

pub const editor_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(EditorCmd.go_to_definition), .label = "Go to Definition", .shortcut = "F12" },
    .{ .id = @intFromEnum(EditorCmd.go_to_declaration), .label = "Go to Declaration" },
    .{ .id = @intFromEnum(EditorCmd.go_to_type_definition), .label = "Go to Type Definition" },
    .{ .id = @intFromEnum(EditorCmd.go_to_implementations), .label = "Go to Implementations", .shortcut = "Ctrl+F12" },
    .{ .id = @intFromEnum(EditorCmd.go_to_references), .label = "Go to References", .shortcut = "Shift+F12", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.peek_definition), .label = "Peek Definition", .shortcut = "Alt+F12" },
    .{ .id = @intFromEnum(EditorCmd.peek_declaration), .label = "Peek Declaration" },
    .{ .id = @intFromEnum(EditorCmd.peek_type_definition), .label = "Peek Type Definition" },
    .{ .id = @intFromEnum(EditorCmd.peek_implementations), .label = "Peek Implementations" },
    .{ .id = @intFromEnum(EditorCmd.peek_references), .label = "Peek References", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.rename_symbol), .label = "Rename Symbol", .shortcut = "F2" },
    .{ .id = @intFromEnum(EditorCmd.change_all_occurrences), .label = "Change All Occurrences", .shortcut = "Ctrl+F2", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.cut), .label = "Cut", .shortcut = "Ctrl+X" },
    .{ .id = @intFromEnum(EditorCmd.copy), .label = "Copy", .shortcut = "Ctrl+C" },
    .{ .id = @intFromEnum(EditorCmd.paste), .label = "Paste", .shortcut = "Ctrl+V", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.format_document), .label = "Format Document", .shortcut = "Shift+Alt+F" },
    .{ .id = @intFromEnum(EditorCmd.format_selection), .label = "Format Selection", .shortcut = "Ctrl+K Ctrl+F", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.refactor), .label = "Refactor...", .shortcut = "Ctrl+Shift+R" },
    .{ .id = @intFromEnum(EditorCmd.source_action), .label = "Source Action...", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.toggle_line_comment), .label = "Toggle Line Comment", .shortcut = "Ctrl+/" },
    .{ .id = @intFromEnum(EditorCmd.toggle_block_comment), .label = "Toggle Block Comment", .shortcut = "Ctrl+Shift+/", .separator_after = true },
    .{ .id = @intFromEnum(EditorCmd.command_palette), .label = "Command Palette", .shortcut = "Ctrl+Shift+P" },
};

// =============================================================================
// Tab context menu items.
// =============================================================================

pub const tab_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(TabCmd.close), .label = "Close", .shortcut = "Ctrl+W" },
    .{ .id = @intFromEnum(TabCmd.close_others), .label = "Close Others" },
    .{ .id = @intFromEnum(TabCmd.close_to_the_right), .label = "Close to the Right" },
    .{ .id = @intFromEnum(TabCmd.close_saved), .label = "Close Saved" },
    .{ .id = @intFromEnum(TabCmd.close_all), .label = "Close All", .separator_after = true },
    .{ .id = @intFromEnum(TabCmd.copy_path), .label = "Copy Path" },
    .{ .id = @intFromEnum(TabCmd.copy_relative_path), .label = "Copy Relative Path", .separator_after = true },
    .{ .id = @intFromEnum(TabCmd.reveal_in_explorer), .label = "Reveal in File Explorer", .separator_after = true },
    .{ .id = @intFromEnum(TabCmd.keep_open), .label = "Keep Open", .separator_after = true },
    .{ .id = @intFromEnum(TabCmd.split_up), .label = "Split Up" },
    .{ .id = @intFromEnum(TabCmd.split_down), .label = "Split Down" },
    .{ .id = @intFromEnum(TabCmd.split_left), .label = "Split Left" },
    .{ .id = @intFromEnum(TabCmd.split_right), .label = "Split Right" },
};

// =============================================================================
// Sidebar context menu items.
// =============================================================================

pub const sidebar_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(SidebarCmd.new_file), .label = "New File..." },
    .{ .id = @intFromEnum(SidebarCmd.new_folder), .label = "New Folder...", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.cut), .label = "Cut" },
    .{ .id = @intFromEnum(SidebarCmd.copy), .label = "Copy" },
    .{ .id = @intFromEnum(SidebarCmd.paste), .label = "Paste", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.copy_path), .label = "Copy Path" },
    .{ .id = @intFromEnum(SidebarCmd.copy_relative_path), .label = "Copy Relative Path", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.rename), .label = "Rename", .shortcut = "F2" },
    .{ .id = @intFromEnum(SidebarCmd.delete), .label = "Delete", .shortcut = "Delete", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.reveal_in_file_explorer), .label = "Reveal in File Explorer" },
    .{ .id = @intFromEnum(SidebarCmd.open_in_integrated_terminal), .label = "Open in Integrated Terminal", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.find_in_folder), .label = "Find in Folder...", .separator_after = true },
    .{ .id = @intFromEnum(SidebarCmd.collapse_folders), .label = "Collapse Folders in Explorer" },
};

// =============================================================================
// Panel (terminal) context menu items.
// =============================================================================

pub const panel_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(PanelCmd.copy_all), .label = "Copy All" },
    .{ .id = @intFromEnum(PanelCmd.select_all), .label = "Select All", .separator_after = true },
    .{ .id = @intFromEnum(PanelCmd.clear), .label = "Clear", .separator_after = true },
    .{ .id = @intFromEnum(PanelCmd.scroll_to_bottom), .label = "Scroll to Bottom", .separator_after = true },
    .{ .id = @intFromEnum(PanelCmd.split_terminal), .label = "Split Terminal" },
    .{ .id = @intFromEnum(PanelCmd.new_terminal), .label = "New Terminal" },
    .{ .id = @intFromEnum(PanelCmd.kill_terminal), .label = "Kill Terminal" },
};

// =============================================================================
// Title bar context menu items.
// =============================================================================

pub const title_bar_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(TitleBarCmd.restore), .label = "Restore" },
    .{ .id = @intFromEnum(TitleBarCmd.minimize), .label = "Minimize" },
    .{ .id = @intFromEnum(TitleBarCmd.maximize), .label = "Maximize", .separator_after = true },
    .{ .id = @intFromEnum(TitleBarCmd.close), .label = "Close", .shortcut = "Alt+F4" },
};

// =============================================================================
// Menu bar dropdown items — File, Edit, Selection, View, Go, Run, Terminal, Help
// =============================================================================

pub const file_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(FileCmd.new_file), .label = "New File", .shortcut = "Ctrl+N" },
    .{ .id = @intFromEnum(FileCmd.new_window), .label = "New Window", .shortcut = "Ctrl+Shift+N" },
    .{ .id = @intFromEnum(FileCmd.open_file), .label = "Open File...", .shortcut = "Ctrl+O" },
    .{ .id = @intFromEnum(FileCmd.open_folder), .label = "Open Folder...", .shortcut = "Ctrl+K Ctrl+O" },
    .{ .id = @intFromEnum(FileCmd.open_recent), .label = "Open Recent", .separator_after = true },
    .{ .id = @intFromEnum(FileCmd.save), .label = "Save", .shortcut = "Ctrl+S" },
    .{ .id = @intFromEnum(FileCmd.save_as), .label = "Save As...", .shortcut = "Ctrl+Shift+S" },
    .{ .id = @intFromEnum(FileCmd.save_all), .label = "Save All", .shortcut = "Ctrl+K S", .separator_after = true },
    .{ .id = @intFromEnum(FileCmd.auto_save), .label = "Auto Save", .separator_after = true },
    .{ .id = @intFromEnum(FileCmd.preferences), .label = "Preferences", .separator_after = true },
    .{ .id = @intFromEnum(FileCmd.revert_file), .label = "Revert File" },
    .{ .id = @intFromEnum(FileCmd.close_editor), .label = "Close Editor", .shortcut = "Ctrl+W" },
    .{ .id = @intFromEnum(FileCmd.close_folder), .label = "Close Folder" },
    .{ .id = @intFromEnum(FileCmd.close_window), .label = "Close Window", .shortcut = "Alt+F4", .separator_after = true },
    .{ .id = @intFromEnum(FileCmd.exit), .label = "Exit" },
};

pub const edit_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(EditCmd.undo), .label = "Undo", .shortcut = "Ctrl+Z" },
    .{ .id = @intFromEnum(EditCmd.redo), .label = "Redo", .shortcut = "Ctrl+Y", .separator_after = true },
    .{ .id = @intFromEnum(EditCmd.cut), .label = "Cut", .shortcut = "Ctrl+X" },
    .{ .id = @intFromEnum(EditCmd.copy), .label = "Copy", .shortcut = "Ctrl+C" },
    .{ .id = @intFromEnum(EditCmd.paste), .label = "Paste", .shortcut = "Ctrl+V", .separator_after = true },
    .{ .id = @intFromEnum(EditCmd.find), .label = "Find", .shortcut = "Ctrl+F" },
    .{ .id = @intFromEnum(EditCmd.replace), .label = "Replace", .shortcut = "Ctrl+H", .separator_after = true },
    .{ .id = @intFromEnum(EditCmd.find_in_files), .label = "Find in Files", .shortcut = "Ctrl+Shift+F" },
    .{ .id = @intFromEnum(EditCmd.replace_in_files), .label = "Replace in Files", .shortcut = "Ctrl+Shift+H", .separator_after = true },
    .{ .id = @intFromEnum(EditCmd.toggle_line_comment), .label = "Toggle Line Comment", .shortcut = "Ctrl+/" },
    .{ .id = @intFromEnum(EditCmd.toggle_block_comment), .label = "Toggle Block Comment", .shortcut = "Ctrl+Shift+/" },
    .{ .id = @intFromEnum(EditCmd.emmet_expand), .label = "Emmet: Expand Abbreviation", .shortcut = "Tab" },
};

pub const selection_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(SelectionCmd.select_all), .label = "Select All", .shortcut = "Ctrl+A" },
    .{ .id = @intFromEnum(SelectionCmd.expand_selection), .label = "Expand Selection", .shortcut = "Shift+Alt+Right" },
    .{ .id = @intFromEnum(SelectionCmd.shrink_selection), .label = "Shrink Selection", .shortcut = "Shift+Alt+Left", .separator_after = true },
    .{ .id = @intFromEnum(SelectionCmd.copy_line_up), .label = "Copy Line Up", .shortcut = "Shift+Alt+Up" },
    .{ .id = @intFromEnum(SelectionCmd.copy_line_down), .label = "Copy Line Down", .shortcut = "Shift+Alt+Down" },
    .{ .id = @intFromEnum(SelectionCmd.move_line_up), .label = "Move Line Up", .shortcut = "Alt+Up" },
    .{ .id = @intFromEnum(SelectionCmd.move_line_down), .label = "Move Line Down", .shortcut = "Alt+Down" },
    .{ .id = @intFromEnum(SelectionCmd.duplicate_selection), .label = "Duplicate Selection", .separator_after = true },
    .{ .id = @intFromEnum(SelectionCmd.add_cursor_above), .label = "Add Cursor Above", .shortcut = "Ctrl+Alt+Up" },
    .{ .id = @intFromEnum(SelectionCmd.add_cursor_below), .label = "Add Cursor Below", .shortcut = "Ctrl+Alt+Down" },
    .{ .id = @intFromEnum(SelectionCmd.add_cursors_to_line_ends), .label = "Add Cursors to Line Ends", .shortcut = "Shift+Alt+I" },
    .{ .id = @intFromEnum(SelectionCmd.add_next_occurrence), .label = "Add Next Occurrence", .shortcut = "Ctrl+D" },
    .{ .id = @intFromEnum(SelectionCmd.add_all_occurrences), .label = "Select All Occurrences", .shortcut = "Ctrl+Shift+L", .separator_after = true },
    .{ .id = @intFromEnum(SelectionCmd.column_selection_mode), .label = "Column Selection Mode", .shortcut = "Shift+Alt" },
};

pub const view_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(ViewCmd.command_palette), .label = "Command Palette...", .shortcut = "Ctrl+Shift+P" },
    .{ .id = @intFromEnum(ViewCmd.open_view), .label = "Open View...", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.appearance), .label = "Appearance" },
    .{ .id = @intFromEnum(ViewCmd.editor_layout), .label = "Editor Layout", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.explorer), .label = "Explorer", .shortcut = "Ctrl+Shift+E" },
    .{ .id = @intFromEnum(ViewCmd.search), .label = "Search", .shortcut = "Ctrl+Shift+F" },
    .{ .id = @intFromEnum(ViewCmd.scm), .label = "Source Control", .shortcut = "Ctrl+Shift+G" },
    .{ .id = @intFromEnum(ViewCmd.run_and_debug), .label = "Run and Debug", .shortcut = "Ctrl+Shift+D" },
    .{ .id = @intFromEnum(ViewCmd.extensions), .label = "Extensions", .shortcut = "Ctrl+Shift+X", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.problems), .label = "Problems", .shortcut = "Ctrl+Shift+M" },
    .{ .id = @intFromEnum(ViewCmd.output), .label = "Output", .shortcut = "Ctrl+Shift+U" },
    .{ .id = @intFromEnum(ViewCmd.debug_console), .label = "Debug Console", .shortcut = "Ctrl+Shift+Y" },
    .{ .id = @intFromEnum(ViewCmd.terminal), .label = "Terminal", .shortcut = "Ctrl+`", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.word_wrap), .label = "Word Wrap", .shortcut = "Alt+Z" },
    .{ .id = @intFromEnum(ViewCmd.minimap), .label = "Minimap" },
    .{ .id = @intFromEnum(ViewCmd.breadcrumbs), .label = "Breadcrumbs", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.zoom_in), .label = "Zoom In", .shortcut = "Ctrl+=" },
    .{ .id = @intFromEnum(ViewCmd.zoom_out), .label = "Zoom Out", .shortcut = "Ctrl+-" },
    .{ .id = @intFromEnum(ViewCmd.reset_zoom), .label = "Reset Zoom", .shortcut = "Ctrl+Numpad0", .separator_after = true },
    .{ .id = @intFromEnum(ViewCmd.full_screen), .label = "Full Screen", .shortcut = "F11" },
};

pub const go_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(GoCmd.back), .label = "Back", .shortcut = "Alt+Left" },
    .{ .id = @intFromEnum(GoCmd.forward), .label = "Forward", .shortcut = "Alt+Right" },
    .{ .id = @intFromEnum(GoCmd.last_edit_location), .label = "Last Edit Location", .shortcut = "Ctrl+K Ctrl+Q", .separator_after = true },
    .{ .id = @intFromEnum(GoCmd.go_to_file), .label = "Go to File...", .shortcut = "Ctrl+P" },
    .{ .id = @intFromEnum(GoCmd.go_to_symbol_in_workspace), .label = "Go to Symbol in Workspace...", .shortcut = "Ctrl+T", .separator_after = true },
    .{ .id = @intFromEnum(GoCmd.go_to_symbol_in_editor), .label = "Go to Symbol in Editor...", .shortcut = "Ctrl+Shift+O" },
    .{ .id = @intFromEnum(GoCmd.go_to_definition), .label = "Go to Definition", .shortcut = "F12" },
    .{ .id = @intFromEnum(GoCmd.go_to_declaration), .label = "Go to Declaration" },
    .{ .id = @intFromEnum(GoCmd.go_to_type_definition), .label = "Go to Type Definition" },
    .{ .id = @intFromEnum(GoCmd.go_to_implementations), .label = "Go to Implementations", .shortcut = "Ctrl+F12" },
    .{ .id = @intFromEnum(GoCmd.go_to_references), .label = "Go to References", .shortcut = "Shift+F12", .separator_after = true },
    .{ .id = @intFromEnum(GoCmd.go_to_line), .label = "Go to Line/Column...", .shortcut = "Ctrl+G" },
    .{ .id = @intFromEnum(GoCmd.go_to_bracket), .label = "Go to Bracket", .shortcut = "Ctrl+Shift+\\", .separator_after = true },
    .{ .id = @intFromEnum(GoCmd.next_problem), .label = "Next Problem", .shortcut = "F8" },
    .{ .id = @intFromEnum(GoCmd.previous_problem), .label = "Previous Problem", .shortcut = "Shift+F8", .separator_after = true },
    .{ .id = @intFromEnum(GoCmd.next_change), .label = "Next Change", .shortcut = "Alt+F5" },
    .{ .id = @intFromEnum(GoCmd.previous_change), .label = "Previous Change", .shortcut = "Shift+Alt+F5" },
};

pub const run_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(RunCmd.start_debugging), .label = "Start Debugging", .shortcut = "F5" },
    .{ .id = @intFromEnum(RunCmd.run_without_debugging), .label = "Run Without Debugging", .shortcut = "Ctrl+F5" },
    .{ .id = @intFromEnum(RunCmd.stop_debugging), .label = "Stop Debugging", .shortcut = "Shift+F5" },
    .{ .id = @intFromEnum(RunCmd.restart_debugging), .label = "Restart Debugging", .shortcut = "Ctrl+Shift+F5", .separator_after = true },
    .{ .id = @intFromEnum(RunCmd.open_configurations), .label = "Open Configurations" },
    .{ .id = @intFromEnum(RunCmd.add_configuration), .label = "Add Configuration...", .separator_after = true },
    .{ .id = @intFromEnum(RunCmd.step_over), .label = "Step Over", .shortcut = "F10" },
    .{ .id = @intFromEnum(RunCmd.step_into), .label = "Step Into", .shortcut = "F11" },
    .{ .id = @intFromEnum(RunCmd.step_out), .label = "Step Out", .shortcut = "Shift+F11" },
    .{ .id = @intFromEnum(RunCmd.@"continue"), .label = "Continue", .shortcut = "F5", .separator_after = true },
    .{ .id = @intFromEnum(RunCmd.toggle_breakpoint), .label = "Toggle Breakpoint", .shortcut = "F9" },
    .{ .id = @intFromEnum(RunCmd.new_breakpoint), .label = "New Breakpoint", .separator_after = true },
    .{ .id = @intFromEnum(RunCmd.enable_all_breakpoints), .label = "Enable All Breakpoints" },
    .{ .id = @intFromEnum(RunCmd.disable_all_breakpoints), .label = "Disable All Breakpoints" },
    .{ .id = @intFromEnum(RunCmd.remove_all_breakpoints), .label = "Remove All Breakpoints", .separator_after = true },
    .{ .id = @intFromEnum(RunCmd.install_debuggers), .label = "Install Additional Debuggers..." },
};

pub const terminal_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(TerminalCmd.new_terminal), .label = "New Terminal", .shortcut = "Ctrl+Shift+`" },
    .{ .id = @intFromEnum(TerminalCmd.split_terminal), .label = "Split Terminal", .separator_after = true },
    .{ .id = @intFromEnum(TerminalCmd.run_task), .label = "Run Task..." },
    .{ .id = @intFromEnum(TerminalCmd.run_build_task), .label = "Run Build Task...", .shortcut = "Ctrl+Shift+B", .separator_after = true },
    .{ .id = @intFromEnum(TerminalCmd.run_active_file), .label = "Run Active File" },
    .{ .id = @intFromEnum(TerminalCmd.run_selected_text), .label = "Run Selected Text", .separator_after = true },
    .{ .id = @intFromEnum(TerminalCmd.configure_tasks), .label = "Configure Tasks..." },
};

pub const help_menu_items = [_]MenuItem{
    .{ .id = @intFromEnum(HelpCmd.welcome), .label = "Welcome" },
    .{ .id = @intFromEnum(HelpCmd.show_all_commands), .label = "Show All Commands", .shortcut = "Ctrl+Shift+P" },
    .{ .id = @intFromEnum(HelpCmd.documentation), .label = "Documentation", .separator_after = true },
    .{ .id = @intFromEnum(HelpCmd.release_notes), .label = "Release Notes", .separator_after = true },
    .{ .id = @intFromEnum(HelpCmd.keyboard_shortcuts), .label = "Keyboard Shortcuts Reference", .shortcut = "Ctrl+K Ctrl+R", .separator_after = true },
    .{ .id = @intFromEnum(HelpCmd.report_issue), .label = "Report Issue", .separator_after = true },
    .{ .id = @intFromEnum(HelpCmd.toggle_developer_tools), .label = "Toggle Developer Tools", .shortcut = "Ctrl+Shift+I", .separator_after = true },
    .{ .id = @intFromEnum(HelpCmd.about), .label = "About" },
};

/// Show a menu bar dropdown by index. Returns selected command ID or 0.
pub fn showMenuBarDropdown(index: MenuBarIndex, hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return switch (index) {
        .file => showMenu(&file_menu_items, hwnd, screen_x, screen_y),
        .edit => showMenu(&edit_menu_items, hwnd, screen_x, screen_y),
        .selection => showMenu(&selection_menu_items, hwnd, screen_x, screen_y),
        .view => showMenu(&view_menu_items, hwnd, screen_x, screen_y),
        .go => showMenu(&go_menu_items, hwnd, screen_x, screen_y),
        .run => showMenu(&run_menu_items, hwnd, screen_x, screen_y),
        .terminal => showMenu(&terminal_menu_items, hwnd, screen_x, screen_y),
        .help => showMenu(&help_menu_items, hwnd, screen_x, screen_y),
    };
}

/// Compute the X position and width of each menu bar label given a cell width.
/// Returns an array of [MENU_BAR_COUNT] x-positions and an array of widths.
pub fn menuBarLabelX(cell_w: i32) [MENU_BAR_COUNT]i32 {
    var xs: [MENU_BAR_COUNT]i32 = undefined;
    var x: i32 = ICON_SPACE_CELLS * cell_w; // leave room for icon
    for (MENU_BAR_LABELS, 0..) |label, i| {
        xs[i] = x;
        x += @as(i32, @intCast(label.len)) * cell_w + MENU_BAR_PAD * 2;
    }
    return xs;
}

pub fn menuBarLabelW(cell_w: i32) [MENU_BAR_COUNT]i32 {
    var ws: [MENU_BAR_COUNT]i32 = undefined;
    for (MENU_BAR_LABELS, 0..) |label, i| {
        ws[i] = @as(i32, @intCast(label.len)) * cell_w + MENU_BAR_PAD * 2;
    }
    return ws;
}

// =============================================================================
// Build and show a Win32 popup menu from a comptime item list.
// Returns the selected command ID, or 0 if cancelled.
// =============================================================================

/// Build a native Win32 popup menu from the given items and show it at (screen_x, screen_y).
/// Returns the selected command ID (item.id), or 0 if the user dismissed the menu.
pub fn showMenu(comptime items: []const MenuItem, hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    const hmenu: ?win32.HMENU = win32.CreatePopupMenu();
    if (hmenu == null) return 0;

    inline for (items) |item| {
        // Build label with shortcut tab-separated: "Cut\tCtrl+X"
        const label = comptime buildMenuLabel(item.label, item.shortcut);
        const flags: win32.UINT = win32.MF_STRING | (if (item.grayed) win32.MF_GRAYED else 0);
        _ = win32.AppendMenuW(hmenu, flags, item.id, &label);

        if (item.separator_after) {
            _ = win32.AppendMenuW(hmenu, win32.MF_SEPARATOR, 0, null);
        }
    }

    const result = win32.TrackPopupMenu(
        hmenu,
        win32.TPM_RETURNCMD | win32.TPM_LEFTALIGN | win32.TPM_TOPALIGN,
        screen_x,
        screen_y,
        0,
        hwnd,
        null,
    );

    _ = win32.DestroyMenu(hmenu);

    // TrackPopupMenu with TPM_RETURNCMD returns the menu item ID, or 0 if cancelled
    if (result != 0) {
        return @intCast(@as(u32, @bitCast(result)));
    }
    return 0;
}

/// Show the editor context menu. Returns selected EditorCmd ID or 0.
pub fn showEditorMenu(hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return showMenu(&editor_menu_items, hwnd, screen_x, screen_y);
}

/// Show the tab context menu. Returns selected TabCmd ID or 0.
pub fn showTabMenu(hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return showMenu(&tab_menu_items, hwnd, screen_x, screen_y);
}

/// Show the sidebar context menu. Returns selected SidebarCmd ID or 0.
pub fn showSidebarMenu(hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return showMenu(&sidebar_menu_items, hwnd, screen_x, screen_y);
}

/// Show the panel context menu. Returns selected PanelCmd ID or 0.
pub fn showPanelMenu(hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return showMenu(&panel_menu_items, hwnd, screen_x, screen_y);
}

/// Show the title bar context menu. Returns selected TitleBarCmd ID or 0.
pub fn showTitleBarMenu(hwnd: win32.HWND, screen_x: i32, screen_y: i32) u16 {
    return showMenu(&title_bar_menu_items, hwnd, screen_x, screen_y);
}

// =============================================================================
// Comptime helper: build a null-terminated UTF-16 menu label with optional
// tab-separated shortcut, e.g. "Cut\tCtrl+X".
// =============================================================================

fn buildMenuLabel(comptime label: []const u8, comptime shortcut: []const u8) [labelLen(label, shortcut):0]u16 {
    const total = labelLen(label, shortcut);
    var buf: [total:0]u16 = undefined;
    var i: usize = 0;
    for (label) |c| {
        buf[i] = c;
        i += 1;
    }
    if (shortcut.len > 0) {
        buf[i] = '\t';
        i += 1;
        for (shortcut) |c| {
            buf[i] = c;
            i += 1;
        }
    }
    buf[total] = 0;
    return buf;
}

fn labelLen(comptime label: []const u8, comptime shortcut: []const u8) usize {
    return label.len + (if (shortcut.len > 0) 1 + shortcut.len else 0);
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "EditorCmd enum values are unique and in expected range" {
    try testing.expectEqual(@as(u16, 100), @intFromEnum(EditorCmd.go_to_definition));
    try testing.expectEqual(@as(u16, 130), @intFromEnum(EditorCmd.cut));
    try testing.expectEqual(@as(u16, 131), @intFromEnum(EditorCmd.copy));
    try testing.expectEqual(@as(u16, 132), @intFromEnum(EditorCmd.paste));
    try testing.expectEqual(@as(u16, 170), @intFromEnum(EditorCmd.command_palette));
}

test "TabCmd enum values are unique and in expected range" {
    try testing.expectEqual(@as(u16, 200), @intFromEnum(TabCmd.close));
    try testing.expectEqual(@as(u16, 204), @intFromEnum(TabCmd.close_all));
    try testing.expectEqual(@as(u16, 210), @intFromEnum(TabCmd.copy_path));
    try testing.expectEqual(@as(u16, 243), @intFromEnum(TabCmd.split_right));
}

test "SidebarCmd enum values are unique and in expected range" {
    try testing.expectEqual(@as(u16, 300), @intFromEnum(SidebarCmd.new_file));
    try testing.expectEqual(@as(u16, 331), @intFromEnum(SidebarCmd.delete));
    try testing.expectEqual(@as(u16, 360), @intFromEnum(SidebarCmd.collapse_folders));
}

test "PanelCmd enum values are unique and in expected range" {
    try testing.expectEqual(@as(u16, 400), @intFromEnum(PanelCmd.clear));
    try testing.expectEqual(@as(u16, 432), @intFromEnum(PanelCmd.kill_terminal));
}

test "TitleBarCmd enum values are unique and in expected range" {
    try testing.expectEqual(@as(u16, 500), @intFromEnum(TitleBarCmd.restore));
    try testing.expectEqual(@as(u16, 510), @intFromEnum(TitleBarCmd.close));
}

test "editor_menu_items has correct count" {
    // VS Code editor context menu: 22 items
    try testing.expectEqual(@as(usize, 22), editor_menu_items.len);
}

test "tab_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 13), tab_menu_items.len);
}

test "sidebar_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 13), sidebar_menu_items.len);
}

test "panel_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 7), panel_menu_items.len);
}

test "title_bar_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 4), title_bar_menu_items.len);
}

test "buildMenuLabel without shortcut" {
    const label = buildMenuLabel("Paste", "");
    try testing.expectEqual(@as(u16, 'P'), label[0]);
    try testing.expectEqual(@as(u16, 'e'), label[4]);
    try testing.expectEqual(@as(u16, 0), label[5]);
}

test "buildMenuLabel with shortcut" {
    const label = buildMenuLabel("Cut", "Ctrl+X");
    try testing.expectEqual(@as(u16, 'C'), label[0]);
    try testing.expectEqual(@as(u16, 'u'), label[1]);
    try testing.expectEqual(@as(u16, 't'), label[2]);
    try testing.expectEqual(@as(u16, '\t'), label[3]);
    try testing.expectEqual(@as(u16, 'C'), label[4]);
    try testing.expectEqual(@as(u16, 0), label[10]);
}

test "MenuZone has all expected zones" {
    _ = MenuZone.editor;
    _ = MenuZone.tab;
    _ = MenuZone.sidebar;
    _ = MenuZone.panel;
    _ = MenuZone.title_bar;
}

test "MenuItem struct fields" {
    const item = MenuItem{ .id = 42, .label = "Test", .shortcut = "F1", .separator_after = true, .grayed = false };
    try testing.expectEqual(@as(u16, 42), item.id);
    try testing.expectEqual(true, item.separator_after);
    try testing.expectEqual(false, item.grayed);
}

test "all editor menu items have non-empty labels" {
    for (editor_menu_items) |item| {
        try testing.expect(item.label.len > 0);
        try testing.expect(item.id >= 100);
    }
}

test "all tab menu items have non-empty labels" {
    for (tab_menu_items) |item| {
        try testing.expect(item.label.len > 0);
        try testing.expect(item.id >= 200);
    }
}

test "no duplicate IDs in editor menu" {
    for (editor_menu_items, 0..) |a, i| {
        for (editor_menu_items, 0..) |b, j| {
            if (i != j) {
                try testing.expect(a.id != b.id);
            }
        }
    }
}

test "no duplicate IDs in tab menu" {
    for (tab_menu_items, 0..) |a, i| {
        for (tab_menu_items, 0..) |b, j| {
            if (i != j) {
                try testing.expect(a.id != b.id);
            }
        }
    }
}

test "file_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 15), file_menu_items.len);
}

test "edit_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 12), edit_menu_items.len);
}

test "selection_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 14), selection_menu_items.len);
}

test "view_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 20), view_menu_items.len);
}

test "go_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 17), go_menu_items.len);
}

test "run_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 16), run_menu_items.len);
}

test "terminal_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 7), terminal_menu_items.len);
}

test "help_menu_items has correct count" {
    try testing.expectEqual(@as(usize, 8), help_menu_items.len);
}

test "MENU_BAR_LABELS has 8 entries" {
    try testing.expectEqual(@as(usize, 8), MENU_BAR_LABELS.len);
    try testing.expectEqual(@as(u8, 8), MENU_BAR_COUNT);
}

test "MenuBarIndex covers all 8 menus" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(MenuBarIndex.file));
    try testing.expectEqual(@as(u8, 7), @intFromEnum(MenuBarIndex.help));
}

test "menuBarLabelX returns increasing positions" {
    const xs = menuBarLabelX(8);
    var i: usize = 1;
    while (i < MENU_BAR_COUNT) : (i += 1) {
        try testing.expect(xs[i] > xs[i - 1]);
    }
}

test "menuBarLabelW returns positive widths" {
    const ws = menuBarLabelW(8);
    for (ws) |w| {
        try testing.expect(w > 0);
    }
}

test "no duplicate IDs across all menu bar dropdowns" {
    // Collect all IDs from all menu bar dropdowns
    const all_items = file_menu_items ++ edit_menu_items ++ selection_menu_items ++
        view_menu_items ++ go_menu_items ++ run_menu_items ++
        terminal_menu_items ++ help_menu_items;
    for (all_items, 0..) |a, i| {
        for (all_items, 0..) |b, j| {
            if (i != j) {
                try testing.expect(a.id != b.id);
            }
        }
    }
}
