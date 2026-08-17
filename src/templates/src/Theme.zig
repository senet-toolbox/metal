// Theme.zig
const std = @import("std");
const Vapor = @import("vapor");
const Color = Vapor.Types.Color;
pub const Mode = enum(u8) {
    light,
    dark,
};

pub const ThemeTokens = enum(u8) {
    none,
    text,
    background,
    tint,
};

pub const Colors = struct {
    text: Color,
    background: Color,
    tint: Color,
};

pub const Light = Colors{
    .text = .black,
    .background = .white,
    .tint = .hex("#002bff"),
};

pub const Dark = Colors{
    .text = .hex("#EAEAEA"),
    .background = .hex("#0F0F0F"),
    .tint = .hex("#C2FE0A"),
};

pub var mode: Mode = .light;

pub export fn setTheme(new_mode: Mode) void {
    mode = new_mode;
}

pub fn toggleTheme() void {
    mode = switch (mode) {
        .dark => .light,
        .light => .dark,
    };
    Vapor.lib.store("theme", @tagName(mode));
    Vapor.lib.toggleTheme();
}
