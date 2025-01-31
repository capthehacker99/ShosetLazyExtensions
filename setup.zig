const std = @import("std");

pub fn main() !void {
    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();
    const doc = try std.fs.cwd().createFile("_doc.lua", .{});
    defer doc.close();
    var client: std.http.Client = .{
        .allocator = allocator,
    };
    defer client.deinit();
    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = try client.open(.GET, try std.Uri.parse("https://gitlab.com/shosetsuorg/kotlin-lib/-/raw/main/_doc.lua"), .{
        .server_header_buffer = &server_header_buffer,
        .keep_alive = false,
    });
    defer req.deinit();
    try req.send();
    try req.finish();
    try req.wait();
    var br = std.io.bufferedReader(req.reader());
    var bw = std.io.bufferedWriter(doc.writer());
    while (true) {
        const byte = br.reader().readByte() catch |err| {
            if(err == error.EndOfStream)
                break;
            return err;
        };
        try bw.writer().writeByte(byte);
    }
    try bw.flush();
}