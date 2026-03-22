// src/platform/gl.zig — OpenGL 1.x immediate mode bindings
//
// Hand-written OpenGL API extern declarations. All GL types, constants,
// and function bindings for immediate mode rendering. No auto-generation,
// no third-party dependencies.

const std = @import("std");
const cc: std.builtin.CallingConvention = .c;

// =============================================================================
// GL type aliases
// =============================================================================

pub const GLuint = u32;
pub const GLint = i32;
pub const GLfloat = f32;
pub const GLdouble = f64;
pub const GLenum = u32;
pub const GLsizei = i32;
pub const GLboolean = u8;
pub const GLbitfield = u32;
pub const GLclampf = f32;
pub const GLvoid = anyopaque;

// =============================================================================
// Primitive type constants
// =============================================================================

pub const GL_LINES: GLenum = 0x0001;
pub const GL_LINE_LOOP: GLenum = 0x0002;
pub const GL_LINE_STRIP: GLenum = 0x0003;
pub const GL_TRIANGLES: GLenum = 0x0004;
pub const GL_QUADS: GLenum = 0x0007;

// =============================================================================
// Enable caps
// =============================================================================

pub const GL_LINE_SMOOTH: GLenum = 0x0B20;
pub const GL_SCISSOR_TEST: GLenum = 0x0C11;
pub const GL_BLEND: GLenum = 0x0BE2;
pub const GL_TEXTURE_2D: GLenum = 0x0DE1;

// =============================================================================
// Blend functions
// =============================================================================

pub const GL_SRC_ALPHA: GLenum = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA: GLenum = 0x0303;

// =============================================================================
// Matrix modes
// =============================================================================

pub const GL_MODELVIEW: GLenum = 0x1700;
pub const GL_PROJECTION: GLenum = 0x1701;

// =============================================================================
// Clear bits
// =============================================================================

pub const GL_COLOR_BUFFER_BIT: GLbitfield = 0x00004000;

// =============================================================================
// Texture parameters
// =============================================================================

pub const GL_TEXTURE_MAG_FILTER: GLenum = 0x2800;
pub const GL_TEXTURE_MIN_FILTER: GLenum = 0x2801;
pub const GL_TEXTURE_WRAP_S: GLenum = 0x2802;
pub const GL_TEXTURE_WRAP_T: GLenum = 0x2803;
pub const GL_NEAREST: GLint = 0x2600;
pub const GL_LINEAR: GLint = 0x2601;
pub const GL_CLAMP_TO_EDGE: GLint = 0x812F;

// =============================================================================
// Pixel formats
// =============================================================================

pub const GL_ALPHA: GLenum = 0x1906;
pub const GL_RGBA: GLenum = 0x1908;
pub const GL_UNSIGNED_BYTE: GLenum = 0x1401;

// =============================================================================
// Extern functions — opengl32
// =============================================================================

pub extern "opengl32" fn glEnable(GLenum) callconv(cc) void;
pub extern "opengl32" fn glDisable(GLenum) callconv(cc) void;
pub extern "opengl32" fn glBlendFunc(GLenum, GLenum) callconv(cc) void;
pub extern "opengl32" fn glClear(GLbitfield) callconv(cc) void;
pub extern "opengl32" fn glClearColor(GLclampf, GLclampf, GLclampf, GLclampf) callconv(cc) void;
pub extern "opengl32" fn glViewport(GLint, GLint, GLsizei, GLsizei) callconv(cc) void;
pub extern "opengl32" fn glScissor(GLint, GLint, GLsizei, GLsizei) callconv(cc) void;
pub extern "opengl32" fn glMatrixMode(GLenum) callconv(cc) void;
pub extern "opengl32" fn glLoadIdentity() callconv(cc) void;
pub extern "opengl32" fn glOrtho(GLdouble, GLdouble, GLdouble, GLdouble, GLdouble, GLdouble) callconv(cc) void;
pub extern "opengl32" fn glPushMatrix() callconv(cc) void;
pub extern "opengl32" fn glPopMatrix() callconv(cc) void;
pub extern "opengl32" fn glTranslatef(GLfloat, GLfloat, GLfloat) callconv(cc) void;
pub extern "opengl32" fn glBegin(GLenum) callconv(cc) void;
pub extern "opengl32" fn glEnd() callconv(cc) void;
pub extern "opengl32" fn glVertex2f(GLfloat, GLfloat) callconv(cc) void;
pub extern "opengl32" fn glVertex2i(GLint, GLint) callconv(cc) void;
pub extern "opengl32" fn glTexCoord2f(GLfloat, GLfloat) callconv(cc) void;
pub extern "opengl32" fn glColor3f(GLfloat, GLfloat, GLfloat) callconv(cc) void;
pub extern "opengl32" fn glColor4f(GLfloat, GLfloat, GLfloat, GLfloat) callconv(cc) void;
pub extern "opengl32" fn glGenTextures(GLsizei, *GLuint) callconv(cc) void;
pub extern "opengl32" fn glBindTexture(GLenum, GLuint) callconv(cc) void;
pub extern "opengl32" fn glTexImage2D(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, ?*const GLvoid) callconv(cc) void;
pub extern "opengl32" fn glTexParameteri(GLenum, GLenum, GLint) callconv(cc) void;
pub extern "opengl32" fn glDeleteTextures(GLsizei, *const GLuint) callconv(cc) void;
pub extern "opengl32" fn glLineWidth(GLfloat) callconv(cc) void;

// =============================================================================
// Tests
// =============================================================================

test "GL constant values are correct" {
    // Primitive types
    try std.testing.expectEqual(@as(GLenum, 0x0007), GL_QUADS);
    try std.testing.expectEqual(@as(GLenum, 0x0004), GL_TRIANGLES);
    try std.testing.expectEqual(@as(GLenum, 0x0001), GL_LINES);

    // Enable caps
    try std.testing.expectEqual(@as(GLenum, 0x0BE2), GL_BLEND);
    try std.testing.expectEqual(@as(GLenum, 0x0DE1), GL_TEXTURE_2D);
    try std.testing.expectEqual(@as(GLenum, 0x0B20), GL_LINE_SMOOTH);
    try std.testing.expectEqual(@as(GLenum, 0x0C11), GL_SCISSOR_TEST);

    // Blend functions
    try std.testing.expectEqual(@as(GLenum, 0x0302), GL_SRC_ALPHA);
    try std.testing.expectEqual(@as(GLenum, 0x0303), GL_ONE_MINUS_SRC_ALPHA);

    // Matrix modes
    try std.testing.expectEqual(@as(GLenum, 0x1701), GL_PROJECTION);
    try std.testing.expectEqual(@as(GLenum, 0x1700), GL_MODELVIEW);

    // Clear bits
    try std.testing.expectEqual(@as(GLbitfield, 0x00004000), GL_COLOR_BUFFER_BIT);

    // Texture params
    try std.testing.expectEqual(@as(GLint, 0x2600), GL_NEAREST);
    try std.testing.expectEqual(@as(GLint, 0x2601), GL_LINEAR);

    // Pixel formats
    try std.testing.expectEqual(@as(GLenum, 0x1908), GL_RGBA);
    try std.testing.expectEqual(@as(GLenum, 0x1401), GL_UNSIGNED_BYTE);
    try std.testing.expectEqual(@as(GLenum, 0x1906), GL_ALPHA);
}

test "GL type sizes are correct" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLuint));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLint));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLfloat));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(GLdouble));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLenum));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLsizei));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(GLboolean));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLbitfield));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(GLclampf));
}
