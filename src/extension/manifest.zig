// src/extension/manifest.zig — Comptime extension manifest
//
// Central registry of all compiled-in extensions. The workbench uses this
// to activate extensions at init time. All resolution happens at comptime.

const ext = @import("extension");

// -- Import all extension modules --
const zig_lang = @import("ext_zig_lang");
const json_lang = @import("ext_json_lang");
const markdown_lang = @import("ext_markdown_lang");
const typescript_lang = @import("ext_typescript_lang");
const javascript_lang = @import("ext_javascript_lang");
const python_lang = @import("ext_python_lang");
const c_lang = @import("ext_c_lang");
const cpp_lang = @import("ext_cpp_lang");
const rust_lang = @import("ext_rust_lang");
const go_lang = @import("ext_go_lang");
const html_lang = @import("ext_html_lang");
const css_lang = @import("ext_css_lang");
const java_lang = @import("ext_java_lang");
const csharp_lang = @import("ext_csharp_lang");
const php_lang = @import("ext_php_lang");
const ruby_lang = @import("ext_ruby_lang");
const shell_lang = @import("ext_shell_lang");
const sql_lang = @import("ext_sql_lang");
const xml_lang = @import("ext_xml_lang");
const yaml_lang = @import("ext_yaml_lang");
const bat_lang = @import("ext_bat_lang");
const dart_lang = @import("ext_dart_lang");
const diff_lang = @import("ext_diff_lang");
const docker_lang = @import("ext_docker_lang");
const ini_lang = @import("ext_ini_lang");
const less_lang = @import("ext_less_lang");
const lua_lang = @import("ext_lua_lang");
const make_lang = @import("ext_make_lang");
const perl_lang = @import("ext_perl_lang");
const powershell_lang = @import("ext_powershell_lang");
const r_lang = @import("ext_r_lang");
const scss_lang = @import("ext_scss_lang");
const swift_lang = @import("ext_swift_lang");
const clojure_lang = @import("ext_clojure_lang");
const coffeescript_lang = @import("ext_coffeescript_lang");
const dotenv_lang = @import("ext_dotenv_lang");
const fsharp_lang = @import("ext_fsharp_lang");
const groovy_lang = @import("ext_groovy_lang");
const handlebars_lang = @import("ext_handlebars_lang");
const hlsl_lang = @import("ext_hlsl_lang");
const julia_lang = @import("ext_julia_lang");
const latex_lang = @import("ext_latex_lang");
const log_lang = @import("ext_log_lang");
const objc_lang = @import("ext_objc_lang");
const pug_lang = @import("ext_pug_lang");
const razor_lang = @import("ext_razor_lang");
const rst_lang = @import("ext_rst_lang");
const shaderlab_lang = @import("ext_shaderlab_lang");
const vb_lang = @import("ext_vb_lang");

/// Master list of all compiled-in extensions.
pub const extensions = [_]ext.Extension{
    zig_lang.extension,
    json_lang.extension,
    markdown_lang.extension,
    typescript_lang.extension,
    javascript_lang.extension,
    python_lang.extension,
    c_lang.extension,
    cpp_lang.extension,
    rust_lang.extension,
    go_lang.extension,
    html_lang.extension,
    css_lang.extension,
    java_lang.extension,
    csharp_lang.extension,
    php_lang.extension,
    ruby_lang.extension,
    shell_lang.extension,
    sql_lang.extension,
    xml_lang.extension,
    yaml_lang.extension,
    bat_lang.extension,
    dart_lang.extension,
    diff_lang.extension,
    docker_lang.extension,
    ini_lang.extension,
    less_lang.extension,
    lua_lang.extension,
    make_lang.extension,
    perl_lang.extension,
    powershell_lang.extension,
    r_lang.extension,
    scss_lang.extension,
    swift_lang.extension,
    clojure_lang.extension,
    coffeescript_lang.extension,
    dotenv_lang.extension,
    fsharp_lang.extension,
    groovy_lang.extension,
    handlebars_lang.extension,
    hlsl_lang.extension,
    julia_lang.extension,
    latex_lang.extension,
    log_lang.extension,
    objc_lang.extension,
    pug_lang.extension,
    razor_lang.extension,
    rst_lang.extension,
    shaderlab_lang.extension,
    vb_lang.extension,
};

/// Total number of extensions.
pub const count = extensions.len;

/// Detect language from filename using all registered syntax contributions.
pub fn detectLanguage(filename: []const u8) ext.syntax.LanguageId {
    return ext.detectLanguage(&extensions, filename);
}

/// Get tokenizer for a language.
pub fn getTokenizer(lang: ext.syntax.LanguageId) ?*const fn (*ext.syntax.LineSyntax, []const u8) void {
    return ext.getTokenizer(&extensions, lang);
}

/// Get display name for a language.
pub fn getLanguageDisplayName(lang: ext.syntax.LanguageId) []const u8 {
    return ext.getLanguageDisplayName(&extensions, lang);
}

/// Get line comment prefix for a language.
pub fn getLineComment(lang: ext.syntax.LanguageId) []const u8 {
    return ext.getLineComment(&extensions, lang);
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;
const expect = testing.expect;

test "manifest has all extensions registered" {
    try expect(count == 49);
}

test "manifest detectLanguage routes to zig extension" {
    try expect(detectLanguage("main.zig") == .zig_lang);
    try expect(detectLanguage("build.zon") == .zig_lang);
}

test "manifest detectLanguage routes to json extension" {
    try expect(detectLanguage("config.json") == .json_lang);
}

test "manifest detectLanguage routes to new extensions" {
    try expect(detectLanguage("README.md") == .markdown);
    try expect(detectLanguage("app.ts") == .typescript);
    try expect(detectLanguage("app.tsx") == .typescript);
    try expect(detectLanguage("index.js") == .javascript);
    try expect(detectLanguage("main.py") == .python);
    try expect(detectLanguage("main.c") == .c_lang);
    try expect(detectLanguage("main.cpp") == .cpp_lang);
    try expect(detectLanguage("main.rs") == .rust_lang);
    try expect(detectLanguage("main.go") == .go_lang);
    try expect(detectLanguage("index.html") == .html);
    try expect(detectLanguage("style.css") == .css);
    try expect(detectLanguage("Main.java") == .java);
    try expect(detectLanguage("App.cs") == .csharp);
    try expect(detectLanguage("index.php") == .php);
    try expect(detectLanguage("app.rb") == .ruby);
    try expect(detectLanguage("script.sh") == .shellscript);
    try expect(detectLanguage("query.sql") == .sql);
    try expect(detectLanguage("data.xml") == .xml);
    try expect(detectLanguage("config.yml") == .yaml);
    try expect(detectLanguage("run.bat") == .bat);
    try expect(detectLanguage("main.dart") == .dart);
    try expect(detectLanguage("changes.diff") == .diff_lang);
    try expect(detectLanguage("app.lua") == .lua);
    try expect(detectLanguage("style.less") == .less);
    try expect(detectLanguage("style.scss") == .scss);
    try expect(detectLanguage("script.ps1") == .powershell);
    try expect(detectLanguage("analysis.r") == .r_lang);
    try expect(detectLanguage("app.swift") == .swift);
    try expect(detectLanguage("core.clj") == .clojure);
    try expect(detectLanguage("app.coffee") == .coffeescript);
    try expect(detectLanguage("module.fs") == .fsharp);
    try expect(detectLanguage("build.gradle") == .groovy);
    try expect(detectLanguage("shader.hlsl") == .hlsl);
    try expect(detectLanguage("main.jl") == .julia);
    try expect(detectLanguage("paper.tex") == .latex);
    try expect(detectLanguage("app.log") == .log);
    try expect(detectLanguage("view.cshtml") == .razor);
    try expect(detectLanguage("doc.rst") == .restructuredtext);
    try expect(detectLanguage("fx.shader") == .shaderlab);
    try expect(detectLanguage("form.vb") == .vb);
}

test "manifest detectLanguage returns plain_text for unknown" {
    try expect(detectLanguage("readme.txt") == .plain_text);
    try expect(detectLanguage("Makefile") == .plain_text);
}

test "manifest getTokenizer returns non-null for all registered languages" {
    try expect(getTokenizer(.zig_lang) != null);
    try expect(getTokenizer(.json_lang) != null);
    try expect(getTokenizer(.markdown) != null);
    try expect(getTokenizer(.typescript) != null);
    try expect(getTokenizer(.javascript) != null);
    try expect(getTokenizer(.python) != null);
    try expect(getTokenizer(.c_lang) != null);
    try expect(getTokenizer(.cpp_lang) != null);
    try expect(getTokenizer(.rust_lang) != null);
    try expect(getTokenizer(.go_lang) != null);
    try expect(getTokenizer(.html) != null);
    try expect(getTokenizer(.css) != null);
}

test "manifest getTokenizer returns null for plain_text" {
    try expect(getTokenizer(.plain_text) == null);
}

test "manifest getLanguageDisplayName" {
    const zig_name = getLanguageDisplayName(.zig_lang);
    try expect(zig_name.len > 0);
    const py_name = getLanguageDisplayName(.python);
    try expect(py_name.len > 0);
}
