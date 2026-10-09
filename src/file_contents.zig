//! Source templates for `metal <framework> gen <type> <Name>`.
//!
//! The vapor templates are written against vapor's current API and are
//! compiled in CI (see the `scaffold` job), so a vapor API change that breaks
//! them fails there instead of in a user's first `gen`.
//!
//! Placeholders, replaced by `render`:
//!   __NAME__   the type/file name as given, first letter capitalised (`UserCard`)
//!   __ROUTE__  kebab-case route for pages (`/user-card`)

const std = @import("std");

pub const CommandType = enum {
    Gen,
    Add,
};

pub const GenType = enum {
    // vapor
    page,
    component,
    card,
    button,
    fetch,
    // reverb (backend)
    crud,
    crudfull,
    database,
    null,
};

pub const Contents = @This();
allocator: *std.mem.Allocator,

const page_template =
    \\//! __NAME__ page, served at __ROUTE__.
    \\//!
    \\//! Register it once, in src/main.zig's init():
    \\//!
    \\//!     @import("routes/__NAME__.zig").init();
    \\
    \\const Vapor = @import("vapor");
    \\const Box = Vapor.Box;
    \\const Heading = Vapor.Heading;
    \\const Text = Vapor.Text;
    \\
    \\pub fn init() void {
    \\    Vapor.Page(.{ .route = "__ROUTE__" }, render, null);
    \\}
    \\
    \\fn render() void {
    \\    Box().direction(.column).padding(.all(24)).spacing(12).children({
    \\        Heading(1, "__NAME__").end();
    \\        Text("Edit src/routes/__NAME__.zig to change this page.").end();
    \\    });
    \\}
    \\
;

const component_template =
    \\//! __NAME__: a component with its own state. Every instance keeps a
    \\//! separate count.
    \\//!
    \\//!     const __NAME__ = @import("components/__NAME__.zig");
    \\//!     var counter: __NAME__ = .{};
    \\//!
    \\//!     fn render() void {
    \\//!         counter.render();
    \\//!     }
    \\
    \\const Vapor = @import("vapor");
    \\const Row = Vapor.Row;
    \\const Button = Vapor.Button;
    \\const Text = Vapor.Text;
    \\
    \\const __NAME__ = @This();
    \\
    \\count: i32 = 0,
    \\
    \\pub fn render(self: *__NAME__) void {
    \\    Row().spacing(8).children({
    \\        Button(decrement, .{self}).children({
    \\            Text("-").end();
    \\        });
    \\        Text(self.count).end();
    \\        Button(increment, .{self}).children({
    \\            Text("+").end();
    \\        });
    \\    });
    \\}
    \\
    \\fn increment(self: *__NAME__) void {
    \\    self.count += 1;
    \\}
    \\
    \\fn decrement(self: *__NAME__) void {
    \\    self.count -= 1;
    \\}
    \\
;

const card_template =
    \\//! __NAME__: a presentational card, a pure function of its arguments.
    \\//!
    \\//!     @import("components/__NAME__.zig").render("Title", "Body text");
    \\
    \\const Vapor = @import("vapor");
    \\const Box = Vapor.Box;
    \\const Heading = Vapor.Heading;
    \\const Text = Vapor.Text;
    \\
    \\pub fn render(title: []const u8, body: []const u8) void {
    \\    Box()
    \\        .direction(.column)
    \\        .padding(.all(16))
    \\        .spacing(8)
    \\        .border(.solid(.all(1), .hex("#E1E1E1"), .all(8)))
    \\        .children({
    \\        Heading(3, title).end();
    \\        Text(body).end();
    \\    });
    \\}
    \\
;

const button_template =
    \\//! __NAME__: a styled button. Takes a click handler and its arguments, the
    \\//! same way Vapor.Button does.
    \\//!
    \\//!     const __NAME__ = @import("components/__NAME__.zig");
    \\//!     __NAME__.render("Save", save, .{});
    \\
    \\const Vapor = @import("vapor");
    \\const Button = Vapor.Button;
    \\const Text = Vapor.Text;
    \\
    \\pub fn render(label: []const u8, on_click: anytype, args: anytype) void {
    \\    Button(on_click, args)
    \\        .padding(.all(12))
    \\        .border(.solid(.all(1), .palette(.tint), .all(6)))
    \\        .cursor(.pointer)
    \\        .hover(.{ .background = .palette(.tint), .text_color = .white })
    \\        .children({
    \\        Text(label).end();
    \\    });
    \\}
    \\
;

const fetch_template =
    \\//! __NAME__: loads data over HTTP and renders each state of the request.
    \\//!
    \\//!     const __NAME__ = @import("components/__NAME__.zig");
    \\//!     __NAME__.load();    // once, e.g. from your page's init()
    \\//!     __NAME__.render();  // from a render function
    \\
    \\const std = @import("std");
    \\const Vapor = @import("vapor");
    \\const Text = Vapor.Text;
    \\
    \\/// Point this at your API.
    \\const url = "/api__ROUTE__";
    \\
    \\var request: ?*Vapor.Fetch.Request = null;
    \\var body: []const u8 = "";
    \\
    \\pub fn load() void {
    \\    const req = Vapor.fetch(url, .{});
    \\    req.handle(onResponse, .{});
    \\    request = req;
    \\}
    \\
    \\fn onResponse(result: Vapor.Fetch.Result) void {
    \\    switch (result) {
    \\        .ok => |response| body = response.body,
    \\        .err => |err| std.log.err("__NAME__: {s} failed: {s}", .{ url, err.message }),
    \\    }
    \\}
    \\
    \\pub fn render() void {
    \\    const req = request orelse return;
    \\    switch (req.state()) {
    \\        .idle, .loading => Text("Loading...").end(),
    \\        .ok => Text(body).end(),
    \\        .err => Text("Could not load data.").end(),
    \\    }
    \\}
    \\
;

/// `UserCard` -> `/user-card`. Runs of capitals stay together (`HTTPLog` ->
/// `/httplog`), and anything that is not a letter or digit becomes `-`.
fn routeFromName(gpa: std.mem.Allocator, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.append(gpa, '/');
    for (name, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            const prev_lower = i > 0 and (std.ascii.isLower(name[i - 1]) or std.ascii.isDigit(name[i - 1]));
            if (prev_lower and out.items[out.items.len - 1] != '-') try out.append(gpa, '-');
            try out.append(gpa, std.ascii.toLower(c));
        } else if (std.ascii.isAlphanumeric(c)) {
            try out.append(gpa, c);
        } else if (out.items[out.items.len - 1] != '-' and out.items[out.items.len - 1] != '/') {
            try out.append(gpa, '-');
        }
    }
    return out.toOwnedSlice(gpa);
}

fn render(gpa: std.mem.Allocator, template: []const u8, name: []const u8) ![]u8 {
    const route = try routeFromName(gpa, name);
    defer gpa.free(route);
    const with_name = try std.mem.replaceOwned(u8, gpa, template, "__NAME__", name);
    defer gpa.free(with_name);
    return std.mem.replaceOwned(u8, gpa, with_name, "__ROUTE__", route);
}

fn crud(_: *const Contents) []const u8 {
    return
    \\const std = @import("std");
    \\const Context = @import("tether").Context;
    \\
    \\pub fn get(ctx: *Context) !void {
    \\}
    \\
    \\pub fn set(ctx: *Context) !void {
    \\}
    \\
    \\pub fn delete(ctx: *Context) !void {
    \\}
    \\
    \\pub fn update(ctx: *Context) !void {
    \\}
    \\
    \\pub fn lpush(ctx: *Context) !void {
    \\}
    \\
    \\pub fn lpushmany(ctx: *Context) !void {
    \\}
    \\
    \\pub fn lrange(ctx: *Context) !void {
    \\}
    \\
    ;
}

fn crudfull(_: *const Contents) []const u8 {
    return
    \\const std = @import("std");
    \\const print = std.debug.print;
    \\const Context = @import("tether").Context;
    \\const ValueType = @import("treehouse").ValueType;
    \\const db = @import("Database.zig");
    \\
    \\pub fn get(ctx: *Context) !void {
    \\    const key = ctx.http_payload;
    \\    const response = db.default_cache.get(key) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn set(ctx: *Context) !void {
    \\    const key = "";
    \\    const value = ValueType{};
    \\    const response = db.default_cache.set(key, value) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn delete(ctx: *Context) !void {
    \\    const key = ctx.http_payload;
    \\    const response = db.default_cache.del(key) catch |err| {
    \\        ctx.ERROR(404, "VALUE COULD NOT BE DELETED");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn update(ctx: *Context) !void {
    \\    const key = "";
    \\    const value = ValueType{};
    \\    const response = db.default_cache.set(key, value) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn lpush(ctx: *Context) !void {
    \\    const llname = "";
    \\    const item = ValueType{};
    \\    const response = db.default_cache.lpush(llname, item) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn lpushmany(ctx: *Context) !void {
    \\    const llname = "";
    \\    const item = &.{ ValueType{} };
    \\    const response = db.default_cache.lpushmany(llname, item) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    \\pub fn lrange(ctx: *Context) !void {
    \\    const llname = "";
    \\    const start = "0";
    \\    const end = "-1";
    \\
    \\    const response = db.default_cache.lrange(llname, start, end) catch |err| {
    \\        ctx.ERROR(404, "VALUE NOT FOUND");
    \\        return err;
    \\    };
    \\    ctx.STRING(response) catch |err| {
    \\        ctx.ERROR(404, "SERVER ERROR");
    \\        return err;
    \\    };
    \\}
    \\
    ;
}

fn database(_: *const Contents) []const u8 {
    return
    \\const std = @import("std");
    \\const Allocator = std.mem.Allocator;
    \\const Treehouse = @import("treehouse.zig");
    \\var caches: std.StringHashMap(*Treehouse) = undefined;
    \\var local_allocator: Allocator = undefined;
    \\pub var default_cache: *Treehouse = undefined;
    \\
    \\pub fn init(allocator: *Allocator) void {
    \\    caches = std.StringHashMap(*Treehouse).init(allocator.*);
    \\    local_allocator = allocator.*;
    \\}
    \\
    \\pub fn deinit() void {
    \\    var cache_itr = caches.iterator();
    \\    defer caches.deinit();
    \\    while (cache_itr.next()) |cache| {
    \\        const treehouse_ptr = cache.value_ptr.*;
    \\        local_allocator.destroy(treehouse_ptr);
    \\    }
    \\}
    \\
    \\pub fn createCache(name: []const u8, port: u16) void {
    \\    const treehouse: *Treehouse = local_allocator.create(Treehouse) catch |err| {
    \\        std.log.err("{any}", .{err});
    \\        @panic("Failed to create Treehouse struct");
    \\    };
    \\    treehouse.* = Treehouse.createClient(port, &local_allocator) catch |err| {
    \\        std.log.err("{any}", .{err});
    \\        @panic("Failed to create client");
    \\    };
    \\    default_cache = treehouse;
    \\    caches.put(name, treehouse) catch {
    \\        @panic("Failed to stash cache in hashmap");
    \\    };
    \\}
    \\
    \\pub fn fetchCache(name: []const u8) ?*Treehouse {
    \\    return caches.get(name) orelse {
    \\        std.log.err("Failed to fetch cache from hashmap", .{});
    \\    };
    \\}
    ;
}

pub fn getGenType(_: *const Contents, file_name: []const u8) GenType {
    return std.meta.stringToEnum(GenType, file_name) orelse GenType.null;
}

pub fn getContent(self: *const Contents, cmd_type: CommandType, gen_type: GenType, file_name: []const u8) ![]const u8 {
    if (cmd_type != .Gen) return error.NoCommand;
    const gpa = self.allocator.*;
    return switch (gen_type) {
        .page => try render(gpa, page_template, file_name),
        .component => try render(gpa, component_template, file_name),
        .card => try render(gpa, card_template, file_name),
        .button => try render(gpa, button_template, file_name),
        .fetch => try render(gpa, fetch_template, file_name),
        .crud => self.crud(),
        .crudfull => self.crudfull(),
        .database => self.database(),
        .null => error.NoCommand,
    };
}

test routeFromName {
    const gpa = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "About", "/about" },
        .{ "UserCard", "/user-card" },
        .{ "Page2Go", "/page2-go" },
        .{ "my_page", "/my-page" },
    };
    for (cases) |case| {
        const got = try routeFromName(gpa, case[0]);
        defer gpa.free(got);
        try std.testing.expectEqualStrings(case[1], got);
    }
}

test "vapor templates leave no placeholder behind" {
    var gpa = std.testing.allocator;
    const contents = Contents{ .allocator = &gpa };
    inline for (.{ GenType.page, .component, .card, .button, .fetch }) |kind| {
        const out = try contents.getContent(.Gen, kind, "UserCard");
        defer gpa.free(out);
        try std.testing.expect(std.mem.indexOf(u8, out, "__") == null);
        try std.testing.expect(std.mem.indexOf(u8, out, "UserCard") != null);
    }
}
