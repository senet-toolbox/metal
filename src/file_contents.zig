const std = @import("std");

pub const CommandType = enum {
    Gen,
    Add,
};

pub const GenType = enum {
    crud,
    crudfull,
    database,
    client,
    card,
    component,
    tutorial,
    complex,
    button,
    template,
    fetch,
    page,
    null,
};

pub const Contents = @This();
allocator: *std.mem.Allocator,

fn tutorial(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\
        \\// Styles.
        \\const Styles = Fabric.Styles;
        \\
        \\// Reactive Signals for updating state.
        \\const Signal = Fabric.Signal;
        \\
        \\// Style
        \\const Style = Fabric.Style;
        \\
        \\// Static components never rerender.
        \\const Static = Fabric.Static;
        \\
        \\// Animation Components.
        \\const Animation = Fabric.Animation;
        \\
        \\// Pure components only rerender when props change.
        \\const Pure = Fabric.Pure;
        \\
        \\// Dynamic components depend on signals and props.
        \\const Dynamic = Fabric.Dynamic;
        \\
        \\// Colors/Themes/Styling
        \\var styles: Styles = undefined;
        \\var primary: [4]f32 = undefined;
        \\var secondary: [4]f32 = undefined;
        \\var border_color: [4]f32 = undefined;
        \\var text_color: [4]f32 = undefined;
        \\var text_tint_color: [4]f32 = undefined;
        \\var tint: [4]f32 = undefined;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init(self: *{s}) void {{
        \\    primary = ...;
        \\    secondary = ...;
        \\    border_color = ...;
        \\    text_color = ...;
        \\    text_tint_color = ...;
        \\    tint = ...;
        \\
        \\    self.* = {s}{{}};
        \\}}
        \\
        \\// Deinitialization
        \\pub fn deinit(self: *{s}) void {{}}
        \\
        \\// Render
        \\pub fn render(self: *{s}) void {{}}
    ;

    return try std.fmt.allocPrint(self.allocator.*, content, .{ file_name, file_name, file_name, file_name, file_name });
}

/// Minimal card component: bordered box, title + body.
/// Usage: try writer.writeAll(try contents.card("CardComponent"));
fn card(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Static = Fabric.Static;
        \\const Style = Fabric.Style;
        \\const Pure = Fabric.Pure;
        \\
        \\// Component instance
        \\const {s} = @This();
        \\
        \\pub fn init() void {{}}
        \\
        \\pub fn deinit() void {{}}
        \\
        \\pub fn render() void {{
        \\    Static.FlexBox(.{{
        \\        .direction = .column,
        \\        .gap = 8,
        \\        .padding = .all(16),
        \\        .border_thickness = .all(1),
        \\        .border_radius = .all(8),
        \\        .width = .fixed(260),
        \\    }})({{
        \\        Static.Text("Card Title", .{{
        \\            .font_size   = 18,
        \\            .font_weight = 700,
        \\        }});
        \\
        \\        Static.Text("Card body content goes here — replace me.", .{{
        \\            .font_size = 14,
        \\        }});
        \\    }});
        \\}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
}

fn alterBuildZon(self: *const Contents, dir_name: []const u8) ![]const u8 {
    const content =
        \\.{
        \\    .name = .{s},
        \\    .version = "0.0.0",
        \\    .fingerprint = 0xf8deace55d76bf2c, // Changing this has security and trust implications.
        \\    .minimum_zig_version = "0.14.0",
        \\    .dependencies = .{
        \\        .fabric = .{
        \\            .url = "zig fetch https://github.com/vic-Rokx/fabric/archive/refs/tags/v1.1.0.tar.gz",
        \\            .hash = "{s}",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\        // For example...
        \\        //"LICENSE",
        \\        //"README.md",
        \\    },
        \\}
    ;

    return try std.fmt.allocPrint(self.allocator.*, content, .{ dir_name, dir_name });
}

fn page(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Signal = Fabric.Signal;
        \\const Style = Fabric.Style;
        \\const Static = Fabric.Static;
        \\const Pure = Fabric.Pure;
        \\const Page = Fabric.Page;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init() void {{
        \\    Page(@src(), render, null, .{{}});
        \\}}
        \\
        \\// Deinitialization
        \\pub fn deinit() void {{}}
        \\
        \\// Render
        \\pub fn render() void {{}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
}

fn fetch(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Kit = Fabric.Kit;
        \\const Signal = Fabric.Signal;
        \\const Style = Fabric.Style;
        \\const Static = Fabric.Static;
        \\const BtnProps = Fabric.BtnProps;
        \\const Pure = Fabric.Pure;
        \\const Page = Fabric.Page;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init() void {{
        \\  Fabric.Kit.fetch("/api/...", callback, .{{ .method = "GET" }});
        \\}}
        \\
        \\// Deinitialization
        \\pub fn deinit() void {{}}
        \\
        \\// Callback 
        \\pub fn callback(resp: Kit.Response) void {{
        \\  Fabric.println("We fetched some stuff! {{any}}", .{{resp.code}});
        \\}}
        \\
        \\// Render
        \\pub fn render() void {{
        \\  Static.Button(
        \\      BtnProps{{
        \\         .onPress = callback,
        \\      }},
        \\      Style.apply(.{{
        \\          .padding = .all(8),
        \\          .border_thickness = .all(1),
        \\          .width = .fixed(120),
        \\          .height = .fixed(40),
        \\      }}),
        \\  )({{
        \\      Static.Text("Press!", .{{
        \\          .font_size = 16,
        \\      }});
        \\  }});
        \\}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
}

fn button(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Signal = Fabric.Signal;
        \\const Style = Fabric.Style;
        \\const Static = Fabric.Static;
        \\const BtnProps = Fabric.BtnProps;
        \\const Pure = Fabric.Pure;
        \\const Page = Fabric.Page;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init() void {{}}
        \\
        \\// Deinitialization
        \\pub fn deinit() void {{}}
        \\
        \\// Callback 
        \\pub fn callback() void {{
        \\  Fabric.println("Clicked!", .{{}});
        \\}}
        \\
        \\// Render
        \\pub fn render() void {{
        \\  Static.Button(
        \\      BtnProps{{
        \\         .onPress = callback,
        \\      }},
        \\      Style.apply(.{{
        \\          .padding = .all(8),
        \\          .border_thickness = .all(1),
        \\          .width = .fixed(120),
        \\          .height = .fixed(40),
        \\      }}),
        \\  )({{
        \\      Static.Text("Press!", .{{
        \\          .font_size = 16,
        \\      }});
        \\  }});
        \\}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
}

fn template(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Signal = Fabric.Signal;
        \\const Style = Fabric.Style;
        \\const Static = Fabric.Static;
        \\const Pure = Fabric.Pure;
        \\const Page = Fabric.Page;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init() void {{}}
        \\
        \\// Deinitialization
        \\pub fn deinit() void {{}}
        \\
        \\// Mounted 
        \\pub fn mount() void {{}}
        \\
        \\// Render
        \\pub fn render() void {{
        \\  Static.Hooks(.{{ .mounted = mount }}, .{{}})({{
        \\      Static.FlexBox(.{{
        \\          .height = .percent(100),
        \\          .width = .percent(100),
        \\          .direction = .column,
        \\          .child_gap = 16,
        \\      }})({{
        \\          Static.Text("...text...", .{{}});
        \\      }});
        \\  }});
        \\}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
}

fn component(self: *const Contents, file_name: []const u8) ![]const u8 {
    const content =
        \\const std = @import("std");
        \\const Fabric = @import("fabric");
        \\const Signal = Fabric.Signal;
        \\const Style = Fabric.Style;
        \\const Static = Fabric.Static;
        \\const Pure = Fabric.Pure;
        \\const Page = Fabric.Page;
        \\
        \\// Component Instance
        \\const {s} = @This();
        \\
        \\// Initialization
        \\pub fn init() void {{}}
        \\
        \\// Deinitialization
        \\pub fn deinit() void {{}}
        \\
        \\// Render
        \\pub fn render() void {{}}
    ;
    return try std.fmt.allocPrint(self.allocator.*, content, .{file_name});
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
    switch (cmd_type) {
        .Gen => {
            switch (gen_type) {
                .tutorial => {
                    return try self.tutorial(file_name);
                },
                .component => {
                    return try self.component(file_name);
                },
                .template => {
                    return try self.template(file_name);
                },
                .button => {
                    return try self.button(file_name);
                },
                .card => {
                    return try self.card(file_name);
                },
                .fetch => {
                    return try self.fetch(file_name);
                },
                .page => {
                    return try self.page(file_name);
                },
                .crudfull => {
                    return self.crudfull();
                },
                .crud => {
                    return self.crud();
                },
                .database => {
                    return self.database();
                },
                else => {},
            }
        },
        else => {},
    }
    return error.NoCommand;
}
