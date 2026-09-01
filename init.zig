const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const cwd: std.Io.Dir = .cwd();
    const doc = try cwd.createFile(init.io, "_doc.lua", .{});
    defer doc.close(init.io);
    var client: std.http.Client = .{
        .io = init.io,
        .allocator = allocator,
    };
    defer client.deinit();
    var writer_buffer: [4096]u8 = undefined;
    var doc_writer = doc.writer(init.io, &writer_buffer);
    const req = try client.fetch(.{
        .location = .{ .url = "https://gitlab.com/shosetsuorg/kotlin-lib/-/raw/main/_doc.lua" },
        .response_writer = &doc_writer.interface,
        .keep_alive = false,
    });
    if(req.status != .ok)
        return error.NotOk;
    try doc_writer.flush();
}