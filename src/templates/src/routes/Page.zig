const Vapor = @import("vapor");
const Text = Vapor.Text;

pub fn init() void {
    Vapor.Page(.{ .src = @src() }, render, null);
}

fn render() void {
    Text("Hello, world!").end();
    // Content...
}
