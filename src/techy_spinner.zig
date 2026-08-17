const std = @import("std");
const Time = @import("Time.zig");

// ╔═══════════════════════════════════════════════════════════════════════════════╗
// ║  VAPOR CLI - Terminal Animation Engine                                        ║
// ║  Inspired by cli-spinners (sindresorhus)                                      ║
// ║  https://github.com/sindresorhus/cli-spinners                                 ║
// ╚═══════════════════════════════════════════════════════════════════════════════╝

// ═══════════════════════════════════════════════════════════════════════════════
//  ANSI Escape Codes
// ═══════════════════════════════════════════════════════════════════════════════

pub const Ansi = struct {
    // Cursor control
    pub var hide_cursor: []const u8 = "\x1b[?25l";
    pub var show_cursor: []const u8 = "\x1b[?25h";
    pub var save_cursor: []const u8 = "\x1b[s";
    pub var restore_cursor: []const u8 = "\x1b[u";
    pub var move_start: []const u8 = "\r";
    pub var clear_line: []const u8 = "\x1b[2K";
    pub var clear_screen: []const u8 = "\x1b[2J\x1b[H";
    pub var clear_below: []const u8 = "\x1b[J";
    pub var move_up: []const u8 = "\x1b[A";
    pub var move_down: []const u8 = "\x1b[B";

    // Text styles
    pub var reset: []const u8 = "\x1b[0m";
    pub var bold: []const u8 = "\x1b[1m";
    pub var dim: []const u8 = "\x1b[2m";
    pub var italic: []const u8 = "\x1b[3m";
    pub var underline: []const u8 = "\x1b[4m";
    pub var blink: []const u8 = "\x1b[5m";
    pub var reverse: []const u8 = "\x1b[7m";

    // Standard colors
    pub var black: []const u8 = "\x1b[30m";
    pub var red: []const u8 = "\x1b[31m";
    pub var green: []const u8 = "\x1b[32m";
    pub var yellow: []const u8 = "\x1b[33m";
    pub var blue: []const u8 = "\x1b[34m";
    pub var magenta: []const u8 = "\x1b[35m";
    pub var cyan: []const u8 = "\x1b[36m";
    pub var white: []const u8 = "\x1b[37m";

    // Bright colors
    pub var bright_black: []const u8 = "\x1b[90m";
    pub var bright_red: []const u8 = "\x1b[91m";
    pub var bright_green: []const u8 = "\x1b[92m";
    pub var bright_yellow: []const u8 = "\x1b[93m";
    pub var bright_blue: []const u8 = "\x1b[94m";
    pub var bright_magenta: []const u8 = "\x1b[95m";
    pub var bright_cyan: []const u8 = "\x1b[96m";
    pub var bright_white: []const u8 = "\x1b[97m";

    // Background colors
    pub var bg_black: []const u8 = "\x1b[40m";
    pub var bg_red: []const u8 = "\x1b[41m";
    pub var bg_green: []const u8 = "\x1b[42m";
    pub var bg_yellow: []const u8 = "\x1b[43m";
    pub var bg_blue: []const u8 = "\x1b[44m";
    pub var bg_magenta: []const u8 = "\x1b[45m";
    pub var bg_cyan: []const u8 = "\x1b[46m";
    pub var bg_white: []const u8 = "\x1b[47m";

    pub fn disable() void {
        hide_cursor = "";
        show_cursor = "";
        save_cursor = "";
        restore_cursor = "";
        clear_line = "";
        clear_screen = "";
        clear_below = "";
        move_up = "";
        move_down = "";
        reset = "";
        bold = "";
        dim = "";
        italic = "";
        underline = "";
        blink = "";
        reverse = "";
        black = "";
        red = "";
        green = "";
        yellow = "";
        blue = "";
        magenta = "";
        cyan = "";
        white = "";
        bright_black = "";
        bright_red = "";
        bright_green = "";
        bright_yellow = "";
        bright_blue = "";
        bright_magenta = "";
        bright_cyan = "";
        bright_white = "";
        bg_black = "";
        bg_red = "";
        bg_green = "";
        bg_yellow = "";
        bg_blue = "";
        bg_magenta = "";
        bg_cyan = "";
        bg_white = "";
    }

    // 256 color support
    pub fn fg256(code: u8) [11]u8 {
        var buf: [11]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{code}) catch unreachable;
        return buf;
    }

    pub fn bg256(code: u8) [11]u8 {
        var buf: [11]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "\x1b[48;5;{d}m", .{code}) catch unreachable;
        return buf;
    }

    // Move cursor to specific line
    pub fn moveToLine(n: usize) void {
        std.debug.print("\x1b[{d};1H", .{n});
    }

    pub fn moveUp(n: usize) void {
        std.debug.print("\x1b[{d}A", .{n});
    }

    pub fn moveDown(n: usize) void {
        std.debug.print("\x1b[{d}B", .{n});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Spinner Patterns (from cli-spinners)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpinnerStyle = enum {
    // Classic spinners
    dots,
    dots2,
    dots3,
    dots8,
    dots9,
    dots12,
    line,
    line2,
    pipe,
    star,
    star2,
    flip,
    hamburger,
    growVertical,
    growHorizontal,
    balloon,
    balloon2,
    noise,
    bounce,
    boxBounce,
    boxBounce2,
    triangle,
    binary,
    arc,
    circle,
    squareCorners,
    circleQuarters,
    circleHalves,
    squish,
    toggle,
    toggle2,
    toggle3,
    toggle4,
    toggle5,
    toggle6,
    toggle7,
    toggle8,
    toggle9,
    toggle10,
    toggle11,
    toggle12,
    toggle13,
    arrow,
    arrow2,
    arrow3,
    bouncingBar,
    bouncingBall,
    smiley,
    monkey,
    hearts,
    clock,
    earth,
    material,
    moon,
    runner,
    pong,
    shark,
    dqpb,
    weather,
    christmas,
    grenade,
    point,
    layer,
    betaWave,
    fingerDance,
    fistBump,
    soccerHeader,
    mindblown,
    speaker,
    orangePulse,
    bluePulse,
    orangeBluePulse,
    timeTravel,
    aesthetic,

    pub fn frames(self: SpinnerStyle) []const []const u8 {
        return switch (self) {
            .dots => &[_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
            .dots2 => &[_][]const u8{ "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
            .dots3 => &[_][]const u8{ "⠋", "⠙", "⠚", "⠞", "⠖", "⠦", "⠴", "⠲", "⠳", "⠓" },
            .dots8 => &[_][]const u8{ "⠀", "⠁", "⠂", "⠃", "⠄", "⠅", "⠆", "⠇", "⡀", "⡁", "⡂", "⡃", "⡄", "⡅", "⡆", "⡇", "⠈", "⠉", "⠊", "⠋", "⠌", "⠍", "⠎", "⠏", "⡈", "⡉", "⡊", "⡋", "⡌", "⡍", "⡎", "⡏", "⠐", "⠑", "⠒", "⠓", "⠔", "⠕", "⠖", "⠗", "⡐", "⡑", "⡒", "⡓", "⡔", "⡕", "⡖", "⡗", "⠘", "⠙", "⠚", "⠛", "⠜", "⠝", "⠞", "⠟", "⡘", "⡙", "⡚", "⡛", "⡜", "⡝", "⡞", "⡟", "⠠", "⠡", "⠢", "⠣", "⠤", "⠥", "⠦", "⠧", "⡠", "⡡", "⡢", "⡣", "⡤", "⡥", "⡦", "⡧", "⠨", "⠩", "⠪", "⠫", "⠬", "⠭", "⠮", "⠯", "⡨", "⡩", "⡪", "⡫", "⡬", "⡭", "⡮", "⡯", "⠰", "⠱", "⠲", "⠳", "⠴", "⠵", "⠶", "⠷", "⡰", "⡱", "⡲", "⡳", "⡴", "⡵", "⡶", "⡷", "⠸", "⠹", "⠺", "⠻", "⠼", "⠽", "⠾", "⠿", "⡸", "⡹", "⡺", "⡻", "⡼", "⡽", "⡾", "⡿", "⢀", "⢁", "⢂", "⢃", "⢄", "⢅", "⢆", "⢇", "⣀", "⣁", "⣂", "⣃", "⣄", "⣅", "⣆", "⣇", "⢈", "⢉", "⢊", "⢋", "⢌", "⢍", "⢎", "⢏", "⣈", "⣉", "⣊", "⣋", "⣌", "⣍", "⣎", "⣏", "⢐", "⢑", "⢒", "⢓", "⢔", "⢕", "⢖", "⢗", "⣐", "⣑", "⣒", "⣓", "⣔", "⣕", "⣖", "⣗", "⢘", "⢙", "⢚", "⢛", "⢜", "⢝", "⢞", "⢟", "⣘", "⣙", "⣚", "⣛", "⣜", "⣝", "⣞", "⣟", "⢠", "⢡", "⢢", "⢣", "⢤", "⢥", "⢦", "⢧", "⣠", "⣡", "⣢", "⣣", "⣤", "⣥", "⣦", "⣧", "⢨", "⢩", "⢪", "⢫", "⢬", "⢭", "⢮", "⢯", "⣨", "⣩", "⣪", "⣫", "⣬", "⣭", "⣮", "⣯", "⢰", "⢱", "⢲", "⢳", "⢴", "⢵", "⢶", "⢷", "⣰", "⣱", "⣲", "⣳", "⣴", "⣵", "⣶", "⣷", "⢸", "⢹", "⢺", "⢻", "⢼", "⢽", "⢾", "⢿", "⣸", "⣹", "⣺", "⣻", "⣼", "⣽", "⣾", "⣿" },
            .dots9 => &[_][]const u8{ "⢹", "⢺", "⢼", "⣸", "⣇", "⡧", "⡗", "⡏" },
            .dots12 => &[_][]const u8{ "⢀⠀", "⡀⠀", "⠄⠀", "⢂⠀", "⡂⠀", "⠅⠀", "⢃⠀", "⡃⠀", "⠍⠀", "⢋⠀", "⡋⠀", "⠍⠁", "⢋⠁", "⡋⠁", "⠍⠉", "⠋⠉", "⠋⠉", "⠉⠙", "⠉⠙", "⠉⠩", "⠈⢙", "⠈⡙", "⢈⠩", "⡂⢐", "⠅⡐", "⢃⠡", "⡃⢐", "⠍⢐", "⢋⡐", "⢋⡐", "⠍⡉", "⠋⡉", "⠋⡉", "⠉⠙", "⠉⠙", "⠉⠩", "⠈⢙", "⠈⡙", "⠈⠩", "⠀⢙", "⠀⡙", "⠀⠩", "⠀⢙", "⠀⡙", "⠀⠩", "⠀⢙", "⠀⡙" },
            .line => &[_][]const u8{ "-", "\\", "|", "/" },
            .line2 => &[_][]const u8{ "⠂", "-", "–", "—", "–", "-" },
            .pipe => &[_][]const u8{ "┤", "┘", "┴", "└", "├", "┌", "┬", "┐" },
            .star => &[_][]const u8{ "✶", "✸", "✹", "✺", "✹", "✷" },
            .star2 => &[_][]const u8{ "+", "x", "*" },
            .flip => &[_][]const u8{ "_", "_", "_", "-", "`", "`", "'", "´", "-", "_", "_", "_" },
            .hamburger => &[_][]const u8{ "☱", "☲", "☴" },
            .growVertical => &[_][]const u8{ "▁", "▃", "▄", "▅", "▆", "▇", "▆", "▅", "▄", "▃" },
            .growHorizontal => &[_][]const u8{ "▏", "▎", "▍", "▌", "▋", "▊", "▉", "▊", "▋", "▌", "▍", "▎" },
            .balloon => &[_][]const u8{ " ", ".", "o", "O", "@", "*", " " },
            .balloon2 => &[_][]const u8{ ".", "o", "O", "°", "O", "o", "." },
            .noise => &[_][]const u8{ "▓", "▒", "░" },
            .bounce => &[_][]const u8{ "⠁", "⠂", "⠄", "⠂" },
            .boxBounce => &[_][]const u8{ "▖", "▘", "▝", "▗" },
            .boxBounce2 => &[_][]const u8{ "▌", "▀", "▐", "▄" },
            .triangle => &[_][]const u8{ "◢", "◣", "◤", "◥" },
            .binary => &[_][]const u8{ "010010", "001100", "100101", "111010", "111101", "010111", "101011", "111000", "110011", "110101" },
            .arc => &[_][]const u8{ "◜", "◠", "◝", "◞", "◡", "◟" },
            .circle => &[_][]const u8{ "◡", "⊙", "◠" },
            .squareCorners => &[_][]const u8{ "◰", "◳", "◲", "◱" },
            .circleQuarters => &[_][]const u8{ "◴", "◷", "◶", "◵" },
            .circleHalves => &[_][]const u8{ "◐", "◓", "◑", "◒" },
            .squish => &[_][]const u8{ "╫", "╪" },
            .toggle => &[_][]const u8{ "⊶", "⊷" },
            .toggle2 => &[_][]const u8{ "▫", "▪" },
            .toggle3 => &[_][]const u8{ "□", "■" },
            .toggle4 => &[_][]const u8{ "■", "□", "▪", "▫" },
            .toggle5 => &[_][]const u8{ "▮", "▯" },
            .toggle6 => &[_][]const u8{ "ဝ", "၀" },
            .toggle7 => &[_][]const u8{ "⦾", "⦿" },
            .toggle8 => &[_][]const u8{ "◍", "◌" },
            .toggle9 => &[_][]const u8{ "◉", "◎" },
            .toggle10 => &[_][]const u8{ "㊂", "㊀", "㊁" },
            .toggle11 => &[_][]const u8{ "⧇", "⧆" },
            .toggle12 => &[_][]const u8{ "☗", "☖" },
            .toggle13 => &[_][]const u8{ "=", "*", "-" },
            .arrow => &[_][]const u8{ "←", "↖", "↑", "↗", "→", "↘", "↓", "↙" },
            .arrow2 => &[_][]const u8{ "⬆️ ", "↗️ ", "➡️ ", "↘️ ", "⬇️ ", "↙️ ", "⬅️ ", "↖️ " },
            .arrow3 => &[_][]const u8{ "▹▹▹▹▹", "▸▹▹▹▹", "▹▸▹▹▹", "▹▹▸▹▹", "▹▹▹▸▹", "▹▹▹▹▸" },
            .bouncingBar => &[_][]const u8{ "[    ]", "[=   ]", "[==  ]", "[=== ]", "[====]", "[ ===]", "[  ==]", "[   =]", "[    ]", "[   =]", "[  ==]", "[ ===]", "[====]", "[=== ]", "[==  ]", "[=   ]" },
            .bouncingBall => &[_][]const u8{ "( ●    )", "(  ●   )", "(   ●  )", "(    ● )", "(     ●)", "(    ● )", "(   ●  )", "(  ●   )", "( ●    )", "(●     )" },
            .smiley => &[_][]const u8{ "😄 ", "😝 " },
            .monkey => &[_][]const u8{ "🙈 ", "🙈 ", "🙉 ", "🙊 " },
            .hearts => &[_][]const u8{ "💛 ", "💙 ", "💜 ", "💚 ", "❤️ " },
            .clock => &[_][]const u8{ "🕛 ", "🕐 ", "🕑 ", "🕒 ", "🕓 ", "🕔 ", "🕕 ", "🕖 ", "🕗 ", "🕘 ", "🕙 ", "🕚 " },
            .earth => &[_][]const u8{ "🌍 ", "🌎 ", "🌏 " },
            .material => &[_][]const u8{ "█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "███▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "████▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "███████▁▁▁▁▁▁▁▁▁▁▁▁▁", "████████▁▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "██████████▁▁▁▁▁▁▁▁▁▁", "███████████▁▁▁▁▁▁▁▁▁", "█████████████▁▁▁▁▁▁▁", "██████████████▁▁▁▁▁▁", "██████████████▁▁▁▁▁▁", "▁██████████████▁▁▁▁▁", "▁## ████████████▁▁▁▁", "▁▁██████████████▁▁▁▁", "▁▁▁██████████████▁▁▁", "▁▁▁▁█████████████▁▁▁", "▁▁▁▁██████████████▁▁", "▁▁▁▁██████████████▁▁", "▁▁▁▁▁██████████████▁", "▁▁▁▁▁██████████████▁", "▁▁▁▁▁██████████████▁", "▁▁▁▁▁▁██████████████", "▁▁▁▁▁▁██████████████", "▁▁▁▁▁▁▁█████████████", "▁▁▁▁▁▁▁█████████████", "▁▁▁▁▁▁▁▁████████████", "▁▁▁▁▁▁▁▁████████████", "▁▁▁▁▁▁▁▁▁███████████", "▁▁▁▁▁▁▁▁▁███████████", "▁▁▁▁▁▁▁▁▁▁██████████", "▁▁▁▁▁▁▁▁▁▁██████████", "▁▁▁▁▁▁▁▁▁▁▁▁████████", "▁▁▁▁▁▁▁▁▁▁▁▁▁███████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁██████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████", "█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████", "██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "███▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "████▁▁▁▁▁▁▁▁▁▁▁▁▁▁██", "█████▁▁▁▁▁▁▁▁▁▁▁▁▁▁█", "█████▁▁▁▁▁▁▁▁▁▁▁▁▁▁█", "██████▁▁▁▁▁▁▁▁▁▁▁▁▁█", "████████▁▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "█████████▁▁▁▁▁▁▁▁▁▁▁", "███████████▁▁▁▁▁▁▁▁▁", "████████████▁▁▁▁▁▁▁▁", "████████████▁▁▁▁▁▁▁▁", "██████████████▁▁▁▁▁▁", "██████████████▁▁▁▁▁▁", "▁██████████████▁▁▁▁▁", "▁██████████████▁▁▁▁▁", "▁▁▁█████████████▁▁▁▁", "▁▁▁▁▁████████████▁▁▁", "▁▁▁▁▁████████████▁▁▁", "▁▁▁▁▁▁███████████▁▁▁", "▁▁▁▁▁▁▁▁█████████▁▁▁", "▁▁▁▁▁▁▁▁█████████▁▁▁", "▁▁▁▁▁▁▁▁▁█████████▁▁", "▁▁▁▁▁▁▁▁▁█████████▁▁", "▁▁▁▁▁▁▁▁▁▁█████████▁", "▁▁▁▁▁▁▁▁▁▁▁████████▁", "▁▁▁▁▁▁▁▁▁▁▁████████▁", "▁▁▁▁▁▁▁▁▁▁▁▁███████▁", "▁▁▁▁▁▁▁▁▁▁▁▁███████▁", "▁▁▁▁▁▁▁▁▁▁▁▁▁███████", "▁▁▁▁▁▁▁▁▁▁▁▁▁███████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" },
            .moon => &[_][]const u8{ "🌑 ", "🌒 ", "🌓 ", "🌔 ", "🌕 ", "🌖 ", "🌗 ", "🌘 " },
            .runner => &[_][]const u8{ "🚶 ", "🏃 " },
            .pong => &[_][]const u8{ "▐⠂       ▌", "▐⠈       ▌", "▐ ⠂      ▌", "▐ ⠠      ▌", "▐  ⡀     ▌", "▐  ⠠     ▌", "▐   ⠂    ▌", "▐   ⠈    ▌", "▐    ⠂   ▌", "▐    ⠠   ▌", "▐     ⡀  ▌", "▐     ⠠  ▌", "▐      ⠂ ▌", "▐      ⠈ ▌", "▐       ⠂▌", "▐       ⠠▌", "▐       ⡀▌", "▐      ⠠ ▌", "▐      ⠂ ▌", "▐     ⠈  ▌", "▐     ⠂  ▌", "▐    ⠠   ▌", "▐    ⡀   ▌", "▐   ⠠    ▌", "▐   ⠂    ▌", "▐  ⠈     ▌", "▐  ⠂     ▌", "▐ ⠠      ▌", "▐ ⡀      ▌", "▐⠠       ▌" },
            .shark => &[_][]const u8{ "▐|\\____________▌", "▐_|\\___________▌", "▐__|\\__________▌", "▐___|\\_________▌", "▐____|\\________▌", "▐_____|\\_______▌", "▐______|\\______▌", "▐_______|\\_____▌", "▐________|\\____▌", "▐_________|\\___▌", "▐__________|\\__▌", "▐___________|\\_▌", "▐____________|\\▌", "▐____________/|▌", "▐___________/|_▌", "▐__________/|__▌", "▐_________/|___▌", "▐________/|____▌", "▐_______/|_____▌", "▐______/|______▌", "▐_____/|_______▌", "▐____/|________▌", "▐___/|_________▌", "▐__/|__________▌", "▐_/|___________▌", "▐/|____________▌" },
            .dqpb => &[_][]const u8{ "d", "q", "p", "b" },
            .weather => &[_][]const u8{ "☀️ ", "☀️ ", "☀️ ", "🌤 ", "⛅️ ", "🌥 ", "☁️ ", "🌧 ", "🌨 ", "🌧 ", "🌨 ", "🌧 ", "🌨 ", "⛈ ", "🌨 ", "🌧 ", "🌨 ", "☁️ ", "🌥 ", "⛅️ ", "🌤 ", "☀️ ", "☀️ " },
            .christmas => &[_][]const u8{ "🌲", "🎄" },
            .grenade => &[_][]const u8{ "،  ", "′  ", " ´ ", " ‾ ", "  ⸌", "  ⸊", "  |", "  ⁎", "  ⁕", " ෴ ", "  ⁂", "   ", "   ", "   " },
            .point => &[_][]const u8{ "∙∙∙", "●∙∙", "∙●∙", "∙∙●", "∙∙∙" },
            .layer => &[_][]const u8{ "-", "=", "≡" },
            .betaWave => &[_][]const u8{ "ρββββββ", "βρβββββ", "ββρββββ", "βββρβββ", "ββββρββ", "βββββρβ", "ββββββρ" },
            .fingerDance => &[_][]const u8{ "🤘 ", "🤟 ", "🖖 ", "✋ ", "🤚 ", "👆 " },
            .fistBump => &[_][]const u8{ "🤜\u{3000}\u{3000}\u{3000}\u{3000}🤛 ", "🤜\u{3000}\u{3000}\u{3000}\u{3000}🤛 ", "🤜\u{3000}\u{3000}\u{3000}\u{3000}🤛 ", "\u{3000}🤜\u{3000}\u{3000}🤛\u{3000} ", "\u{3000}\u{3000}🤜🤛\u{3000}\u{3000} ", "\u{3000}🤜✨🤛\u{3000}\u{3000} ", "🤜\u{3000}✨\u{3000}🤛\u{3000} " },
            .soccerHeader => &[_][]const u8{ " 🧑⚽️       🧑 ", "🧑  ⚽️      🧑 ", "🧑   ⚽️     🧑 ", "🧑    ⚽️    🧑 ", "🧑     ⚽️   🧑 ", "🧑      ⚽️  🧑 ", "🧑       ⚽️🧑  ", "🧑      ⚽️  🧑 ", "🧑     ⚽️   🧑 ", "🧑    ⚽️    🧑 ", "🧑   ⚽️     🧑 ", "🧑  ⚽️      🧑 " },
            .mindblown => &[_][]const u8{ "😒 ", "😬 ", "😮 ", "😵 ", "🤯 ", "💥 ", "✨ ", "\u{3000} ", "\u{3000} ", "\u{3000} " },
            .speaker => &[_][]const u8{ "🔒 ", "🔈 ", "🔉 ", "🔊 ", "📢 ", "🔊 ", "🔉 ", "🔈 " },
            .orangePulse => &[_][]const u8{ "🔸 ", "🔶 ", "🟠 ", "🟠 ", "🔶 " },
            .bluePulse => &[_][]const u8{ "🔹 ", "🔷 ", "🔵 ", "🔵 ", "🔷 " },
            .orangeBluePulse => &[_][]const u8{ "🔸 ", "🔶 ", "🟠 ", "🟠 ", "🔶 ", "🔹 ", "🔷 ", "🔵 ", "🔵 ", "🔷 " },
            .timeTravel => &[_][]const u8{ "🕛 ", "🕚 ", "🕙 ", "🕘 ", "🕗 ", "🕖 ", "🕕 ", "🕔 ", "🕓 ", "🕒 ", "🕑 ", "🕐 " },
            .aesthetic => &[_][]const u8{ "▰▱▱▱▱▱▱", "▰▰▱▱▱▱▱", "▰▰▰▱▱▱▱", "▰▰▰▰▱▱▱", "▰▰▰▰▰▱▱", "▰▰▰▰▰▰▱", "▰▰▰▰▰▰▰", "▰▱▱▱▱▱▱" },
        };
    }

    pub fn interval_ms(self: SpinnerStyle) u64 {
        return switch (self) {
            .dots, .dots2, .dots3, .dots9, .aesthetic => 80,
            .dots8 => 80,
            .dots12 => 80,
            .line, .line2 => 130,
            .pipe => 100,
            .star, .star2 => 70,
            .flip => 70,
            .hamburger => 100,
            .growVertical, .growHorizontal => 120,
            .balloon, .balloon2 => 140,
            .noise => 100,
            .bounce, .boxBounce, .boxBounce2 => 120,
            .triangle => 50,
            .binary => 100,
            .arc => 100,
            .circle => 120,
            .squareCorners, .circleQuarters, .circleHalves => 120,
            .squish => 100,
            .toggle, .toggle2, .toggle3, .toggle4, .toggle5, .toggle6, .toggle7, .toggle8, .toggle9, .toggle10, .toggle11, .toggle12, .toggle13 => 250,
            .arrow, .arrow2 => 100,
            .arrow3 => 120,
            .bouncingBar, .bouncingBall => 80,
            .smiley => 200,
            .monkey => 300,
            .hearts => 100,
            .clock => 100,
            .earth => 180,
            .material => 17,
            .moon => 80,
            .runner => 140,
            .pong => 80,
            .shark => 120,
            .dqpb => 100,
            .weather => 100,
            .christmas => 400,
            .grenade => 80,
            .point => 125,
            .layer => 150,
            .betaWave => 80,
            .fingerDance => 160,
            .fistBump => 80,
            .soccerHeader => 80,
            .mindblown => 160,
            .speaker => 160,
            .orangePulse, .bluePulse, .orangeBluePulse => 100,
            .timeTravel => 100,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Build Progress Display - Hides LLVM output, shows techy progress
// ═══════════════════════════════════════════════════════════════════════════════

pub const BuildDisplay = struct {
    allocator: std.mem.Allocator,
    running: bool = false,
    thread: ?std.Thread = null,
    start_time: i64 = 0,
    phase: Phase = .initializing,
    progress: f32 = 0.0,
    current_file: []const u8 = "",
    files_compiled: usize = 0,
    total_files: usize = 0,

    pub const Phase = enum {
        initializing,
        parsing,
        analyzing,
        codegen,
        linking,
        optimizing,
        complete,
        failed,

        pub fn toString(self: Phase) []const u8 {
            return switch (self) {
                .initializing => "Initializing",
                .parsing => "Parsing AST",
                .analyzing => "Semantic Analysis",
                .codegen => "Code Generation",
                .linking => "Linking",
                .optimizing => "Optimizing",
                .complete => "Complete",
                .failed => "Failed",
            };
        }

        pub fn icon(self: Phase) []const u8 {
            return switch (self) {
                .initializing => "⚡",
                .parsing => "📖",
                .analyzing => "🔍",
                .codegen => "⚙️ ",
                .linking => "🔗",
                .optimizing => "🚀",
                .complete => "✓",
                .failed => "✗",
            };
        }
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        self.start_time = Time.milliTimestamp();
        std.debug.print("{s}", .{Ansi.hide_cursor});
        self.thread = try std.Thread.spawn(.{}, renderLoop, .{self});
    }

    pub fn setPhase(self: *Self, phase: Phase) void {
        self.phase = phase;
    }

    pub fn setProgress(self: *Self, progress: f32) void {
        self.progress = progress;
    }

    pub fn setFile(self: *Self, file: []const u8) void {
        self.current_file = file;
    }

    pub fn incrementFiles(self: *Self) void {
        self.files_compiled += 1;
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        if (self.thread) |t| {
            t.join();
        }
        std.debug.print("{s}{s}{s}", .{ Ansi.clear_line, Ansi.move_start, Ansi.show_cursor });
    }

    pub fn success(self: *Self, _: []const u8) void {
        self.phase = .complete;
        self.stop();
        // const elapsed = Time.milliTimestamp() - self.start_time;
        // const elapsed_secs = @as(f64, @floatFromInt(elapsed)) / 1000.0;

        // std.debug.print("\n", .{});
        // printBox("Build Complete", msg, elapsed_secs, true);
    }

    pub fn fail(self: *Self, msg: []const u8) void {
        self.phase = .failed;
        self.stop();
        const elapsed = Time.milliTimestamp() - self.start_time;
        const elapsed_secs = @as(f64, @floatFromInt(elapsed)) / 1000.0;

        std.debug.print("\n", .{});
        printBox("Build Failed", msg, elapsed_secs, false);
    }

    fn renderLoop(self: *Self) void {
        const spinner_frames = SpinnerStyle.dots2.frames();
        var frame: usize = 0;

        // Gradient colors for the progress bar
        const gradient = [_][]const u8{
            "\x1b[38;5;39m", // Blue
            "\x1b[38;5;38m",
            "\x1b[38;5;44m",
            "\x1b[38;5;43m",
            "\x1b[38;5;49m", // Cyan
            "\x1b[38;5;48m",
            "\x1b[38;5;84m",
            "\x1b[38;5;83m",
            "\x1b[38;5;118m", // Green
        };

        while (self.running) {
            const elapsed = Time.milliTimestamp() - self.start_time;
            const elapsed_secs = @as(f64, @floatFromInt(elapsed)) / 1000.0;

            // Auto-increment progress based on time for visual feedback
            const auto_progress = @min(0.95, elapsed_secs / 10.0); // Max 95% over 10 seconds
            const display_progress = @max(self.progress, @as(f32, @floatCast(auto_progress)));

            // Clear and render
            std.debug.print("{s}{s}", .{ Ansi.move_start, Ansi.clear_line });

            // Spinner
            const spinner = spinner_frames[frame % spinner_frames.len];
            const color_idx = frame % gradient.len;

            // Build the display
            std.debug.print("{s}{s}{s}{s} ", .{
                gradient[color_idx],
                Ansi.bold,
                spinner,
                Ansi.reset,
            });

            // Phase info
            std.debug.print("{s}{s}{s} {s}{s}{s} ", .{
                Ansi.bold,
                Ansi.bright_white,
                self.phase.icon(),
                self.phase.toString(),
                Ansi.reset,
                Ansi.dim,
            });

            // Progress bar
            const bar_width: usize = 20;
            const filled = @as(usize, @intFromFloat(display_progress * @as(f32, @floatFromInt(bar_width))));
            const empty = bar_width - filled;

            std.debug.print("{s}[", .{Ansi.dim});

            // Filled portion with gradient
            for (0..filled) |i| {
                const grad_idx = (i * gradient.len) / bar_width;
                std.debug.print("{s}━", .{gradient[grad_idx]});
            }

            // Empty portion
            std.debug.print("{s}", .{Ansi.bright_black});
            for (0..empty) |_| {
                std.debug.print("─", .{});
            }

            std.debug.print("{s}]{s} ", .{ Ansi.dim, Ansi.reset });

            // Percentage
            const percent: u8 = @intFromFloat(display_progress * 100);
            std.debug.print("{s}{d:>3}%{s} ", .{ Ansi.bright_cyan, percent, Ansi.reset });

            // Time
            std.debug.print("{s}{d:.1}s{s}", .{ Ansi.dim, elapsed_secs, Ansi.reset });

            frame +%= 1;
            Time.sleep(80 * Time.ns_per_ms);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Startup Animation - Shows before build begins
// ═══════════════════════════════════════════════════════════════════════════════

pub fn showStartupSequence(project_name: []const u8) void {
    std.debug.print("{s}", .{Ansi.hide_cursor});

    // Clear screen
    std.debug.print("{s}", .{Ansi.clear_screen});

    // ASCII art banner with gradient
    const banner = [_][]const u8{
        "╦  ╦╔═╗╔═╗╔═╗╦═╗",
        "╚╗╔╝╠═╣╠═╝║ ║╠╦╝",
        " ╚╝ ╩ ╩╩  ╚═╝╩╚═",
    };

    const gradient = [_][]const u8{
        "\x1b[38;5;51m", // Cyan
        "\x1b[38;5;45m",
        "\x1b[38;5;39m", // Blue
    };

    std.debug.print("\n", .{});

    for (banner, 0..) |line, i| {
        std.debug.print("    {s}{s}{s}{s}\n", .{
            gradient[i % gradient.len],
            Ansi.bold,
            line,
            Ansi.reset,
        });
        Time.sleep(50 * Time.ns_per_ms);
    }

    std.debug.print("\n", .{});

    // Project info
    std.debug.print("    {s}Project:{s} {s}{s}{s}\n", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_white,
        project_name,
        Ansi.reset,
    });

    // Scanning animation
    std.debug.print("    {s}Scanning", .{Ansi.dim});
    for (0..3) |_| {
        Time.sleep(200 * Time.ns_per_ms);
        std.debug.print(".", .{});
    }
    std.debug.print("{s}\n\n", .{Ansi.reset});

    std.debug.print("{s}", .{Ansi.show_cursor});
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Result Box - Shows build result
// ═══════════════════════════════════════════════════════════════════════════════

// Fixed printBox function - replace in techy_spinner.zig

const BOX_WIDTH = 40; // Inner width of the box (between │ and │)

fn printBox(title: []const u8, message: []const u8, time_secs: f64, is_success: bool) void {
    const color = if (is_success) Ansi.bright_green else Ansi.bright_red;
    const icon = if (is_success) "✓" else "✗";

    // Top border
    std.debug.print("{s}┌", .{Ansi.dim});
    for (0..BOX_WIDTH) |_| std.debug.print("─", .{});
    std.debug.print("┐{s}\n", .{Ansi.reset});

    // Title line: │ ✓ Build Complete                      │
    // Icon "✓" takes 1 visible char, space after = 1, so prefix = 2 visible chars
    const title_prefix_len: usize = 3; // "✓ " + space before title = 3 visible chars
    const title_padding = BOX_WIDTH - title_prefix_len - title.len;

    std.debug.print("{s}│{s} {s}{s}{s} {s}{s}{s}", .{
        Ansi.dim,
        Ansi.reset,
        color,
        icon,
        Ansi.reset,
        Ansi.bold,
        title,
        Ansi.reset,
    });
    // Add padding manually
    var i: usize = 0;
    while (i < title_padding) : (i += 1) {
        std.debug.print(" ", .{});
    }
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Divider
    std.debug.print("{s}├", .{Ansi.dim});
    for (0..BOX_WIDTH) |_| std.debug.print("─", .{});
    std.debug.print("┤{s}\n", .{Ansi.reset});

    // Message line: │  Hot reload complete!                 │
    const msg_prefix_len: usize = 2; // Two spaces before message
    const msg_padding = BOX_WIDTH - msg_prefix_len - message.len;

    std.debug.print("{s}│{s}  {s}", .{ Ansi.dim, Ansi.reset, message });
    i = 0;
    while (i < msg_padding) : (i += 1) {
        std.debug.print(" ", .{});
    }
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Time line: │  Time: 0.76s                          │
    // Format time string first to know exact length
    var time_buf: [32]u8 = undefined;
    const time_str = std.fmt.bufPrint(&time_buf, "Time: {d:.2}s", .{time_secs}) catch "Time: ?s";
    const time_prefix_len: usize = 2; // Two spaces before "Time:"
    const time_padding = BOX_WIDTH - time_prefix_len - time_str.len;

    std.debug.print("{s}│{s}  {s}{s}{s}", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_cyan,
        time_str,
        Ansi.reset,
    });
    i = 0;
    while (i < time_padding) : (i += 1) {
        std.debug.print(" ", .{});
    }
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Bottom border
    std.debug.print("{s}└", .{Ansi.dim});
    for (0..BOX_WIDTH) |_| std.debug.print("─", .{});
    std.debug.print("┘{s}\n", .{Ansi.reset});
}

// Also fix serverReady to match:
pub fn serverReady(port: u16) void {
    const BOX_W = 40;

    // Top border
    std.debug.print("\n{s}┌", .{Ansi.dim});
    for (0..BOX_W) |_| std.debug.print("─", .{});
    std.debug.print("┐{s}\n", .{Ansi.reset});

    // Title: │ ⚡ Server Ready                         │
    const title = "Server Ready";
    const title_prefix: usize = 4; // "⚡ " (emoji + space) + space = ~3-4 visible
    const title_pad = BOX_W - title_prefix - title.len;

    std.debug.print("{s}│{s} {s}{s}⚡ Server Ready{s}", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bold,
        Ansi.bright_green,
        Ansi.reset,
    });
    for (0..title_pad) |_| std.debug.print(" ", .{});
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Divider
    std.debug.print("{s}├", .{Ansi.dim});
    for (0..BOX_W) |_| std.debug.print("─", .{});
    std.debug.print("┤{s}\n", .{Ansi.reset});

    // Local URL line
    var url_buf: [64]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "http://localhost:{d}", .{port}) catch "http://localhost:?";
    const local_prefix = "  Local:   ".len;
    const local_pad = BOX_W - local_prefix - url.len;

    std.debug.print("{s}│{s}  {s}Local:{s}   {s}", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.bright_cyan,
        Ansi.reset,
        url,
    });
    for (0..local_pad) |_| std.debug.print(" ", .{});
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Ctrl+C line
    const ctrl_msg = "Press Ctrl+C to stop";
    const ctrl_prefix: usize = 2;
    const ctrl_pad = BOX_W - ctrl_prefix - ctrl_msg.len;

    std.debug.print("{s}│{s}  {s}{s}{s}", .{
        Ansi.dim,
        Ansi.reset,
        Ansi.dim,
        ctrl_msg,
        Ansi.reset,
    });
    for (0..ctrl_pad) |_| std.debug.print(" ", .{});
    std.debug.print("{s}│{s}\n", .{ Ansi.dim, Ansi.reset });

    // Bottom border
    std.debug.print("{s}└", .{Ansi.dim});
    for (0..BOX_W) |_| std.debug.print("─", .{});
    std.debug.print("┘{s}\n\n", .{Ansi.reset});
}
// ═══════════════════════════════════════════════════════════════════════════════
//  Simple Spinner (for quick operations)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Spinner = struct {
    style: SpinnerStyle,
    message: []const u8,
    color: []const u8,
    frame_index: usize = 0,
    running: bool = false,
    thread: ?std.Thread = null,

    const Self = @This();

    pub fn init(style: SpinnerStyle, message: []const u8) Self {
        return .{
            .style = style,
            .message = message,
            .color = Ansi.bright_cyan,
        };
    }

    pub fn withColor(self: *Self, color: []const u8) *Self {
        self.color = color;
        return self;
    }

    pub fn start(self: *Self) !void {
        self.running = true;
        std.debug.print("{s}", .{Ansi.hide_cursor});
        self.thread = try std.Thread.spawn(.{}, spinLoop, .{self});
    }

    pub fn stop(self: *Self) void {
        self.running = false;
        if (self.thread) |t| {
            t.join();
        }
        std.debug.print("{s}{s}{s}", .{ Ansi.move_start, Ansi.clear_line, Ansi.show_cursor });
    }

    pub fn success(self: *Self, msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}✓{s} {s}\n", .{ Ansi.bold, Ansi.bright_green, Ansi.reset, msg });
    }

    pub fn fail(self: *Self, msg: []const u8) void {
        self.stop();
        std.debug.print("{s}{s}✗{s} {s}\n", .{ Ansi.bold, Ansi.bright_red, Ansi.reset, msg });
    }

    fn spinLoop(self: *Self) void {
        const frames = self.style.frames();
        const interval_ns = self.style.interval_ms() * Time.ns_per_ms;

        while (self.running) {
            const frame = frames[self.frame_index % frames.len];
            std.debug.print("{s}{s}{s}{s} {s}{s}", .{
                Ansi.move_start,
                self.color,
                Ansi.bold,
                frame,
                Ansi.reset,
                self.message,
            });
            self.frame_index +%= 1;
            Time.sleep(interval_ns);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//  Quick status helpers
// ═══════════════════════════════════════════════════════════════════════════════

pub fn info(message: []const u8) void {
    std.debug.print("{s}{s}ℹ{s} {s}\n", .{ Ansi.bold, Ansi.bright_blue, Ansi.reset, message });
}

pub fn ok(message: []const u8) void {
    std.debug.print("{s}{s}✓{s} {s}\n", .{ Ansi.bold, Ansi.bright_green, Ansi.reset, message });
}

pub fn warn(message: []const u8) void {
    std.debug.print("{s}{s}⚠{s} {s}\n", .{ Ansi.bold, Ansi.bright_yellow, Ansi.reset, message });
}

pub fn err(message: []const u8) void {
    std.debug.print("{s}{s}✗{s} {s}\n", .{ Ansi.bold, Ansi.bright_red, Ansi.reset, message });
}

pub fn fileChanged(path: []const u8) void {
    std.debug.print("{s}{s}📁{s} {s}{s}{s}\n", .{
        Ansi.bold,
        Ansi.bright_blue,
        Ansi.reset,
        Ansi.dim,
        path,
        Ansi.reset,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Demo function
// ═══════════════════════════════════════════════════════════════════════════════

pub fn demo() !void {
    const allocator = std.heap.page_allocator;

    // Show startup sequence
    showStartupSequence("my-vapor-app");

    // Demonstrate build display
    var display = BuildDisplay.init(allocator);
    try display.start();

    display.setPhase(.parsing);
    Time.sleep(1000 * Time.ns_per_ms);

    display.setPhase(.analyzing);
    Time.sleep(1000 * Time.ns_per_ms);

    display.setPhase(.codegen);
    Time.sleep(1500 * Time.ns_per_ms);

    display.setPhase(.linking);
    Time.sleep(500 * Time.ns_per_ms);

    display.success("All modules compiled");

    // Show server ready
    serverReady(5173);

    // Demo file change
    fileChanged("src/main.zig");

    // Quick spinner demo
    std.debug.print("\n{s}Spinner Styles Demo:{s}\n\n", .{ Ansi.bold, Ansi.reset });

    const styles = [_]SpinnerStyle{ .dots, .dots2, .aesthetic, .arc, .bouncingBar };
    for (styles) |style| {
        var spinner = Spinner.init(style, "Loading...");
        try spinner.start();
        Time.sleep(2000 * Time.ns_per_ms);
        spinner.success("Done!");
    }

    std.debug.print("\n{s}Status Messages:{s}\n", .{ Ansi.bold, Ansi.reset });
    info("Information message");
    ok("Success message");
    warn("Warning message");
    err("Error message");
}

pub fn main() !void {
    try demo();
}
