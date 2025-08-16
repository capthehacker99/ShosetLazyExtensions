const std = @import("std");

const Library = struct {
    name: []const u8,
    ver: []const u8,
};

const Script = struct {
    name: []const u8,
    fileName: []const u8,
    imageURL: []const u8,
    id: i32,
    lang: []const u8,
    ver: []const u8,
    libVer: []const u8,
    md5: []u8,
};

const IndexJson = struct {
    libraries: []Library,
    scripts: []Script,

    pub fn calculateHashes(this: @This(), dir: std.fs.Dir, allocator: std.mem.Allocator) !void {
        var buf: [4096]u8 = undefined;
        for(this.scripts) |*script| {
            const file_path = try std.fmt.bufPrint(&buf, "{s}{s}{c}{s}{s}", .{
                "src/",
                script.lang,
                '/',
                script.fileName,
                ".lua"
            });
            const file = try dir.openFile(file_path, .{});
            var md5 = std.crypto.hash.Md5.init(.{});
            while (true) {
                const len = try file.readAll(&buf);
                md5.update(buf[0..len]);
                if(len != buf.len)
                    break;
            }
            md5.final(buf[0..std.crypto.hash.Md5.digest_length]);
            script.md5 = try allocator.realloc(script.md5, std.crypto.hash.Md5.digest_length * 2);
            const charset = "0123456789abcdef";
            for (buf[0..std.crypto.hash.Md5.digest_length], 0..) |b, i| {
                script.md5[i * 2 + 0] = charset[b >> 4];
                script.md5[i * 2 + 1] = charset[b & 15];
            }
            defer file.close();
        }
    }
};

pub noinline fn testScript(allocator: std.mem.Allocator, stdout: *std.Io.Writer, mutex: *std.Thread.Mutex, count: *u32, total: u32, script: Script, args: [][:0]u8) void {
    var buf: [1024]u8 = undefined;
    const file_path = std.fmt.bufPrint(&buf, "{s}{s}{c}{s}{s}", .{
        "src/",
        script.lang,
        '/',
        script.fileName,
        ".lua"
    }) catch return;
    var arr_buf: [32][]const u8 = undefined;
    var arr = std.ArrayListUnmanaged([]const u8).initBuffer(&arr_buf);
    // arr.appendSlice(if(std.mem.eql(u8, script.name, "Cliche Novel")) @as([]const []const u8, &.{ "cmd", "/c", "timeout /NOBREAK /T 30 > nul" }) else @as([]const []const u8, &.{ "cmd", "/c", "timeout /NOBREAK /T 1 > nul" })) catch {};
    arr.appendSliceBounded(&.{ "java", "-jar", "extension-tester.jar", file_path }) catch return;
    arr.appendSliceBounded(args) catch return;
    var child = std.process.Child.init(arr.items, allocator);
    child.stdin_behavior = .Close;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch return;
    var child_stdout: std.ArrayListUnmanaged(u8) = .{};
    var child_stderr: std.ArrayListUnmanaged(u8) = .{};
    defer child_stdout.deinit(allocator);
    defer child_stderr.deinit(allocator);
    child.collectOutput(allocator, &child_stdout, &child_stderr, std.math.maxInt(usize)) catch return;
    const term = child.wait() catch return;
    mutex.lock();
    defer mutex.unlock();
    count.* += 1;
    stdout.print("{s}{d}{c}{d}{s}{s}{s}{s}{s}{c}", .{ "\x1b[90m(", count.* , '/', total , ") \x1b[10", if(term.Exited == 0) "2;1m PASSED \x1b[0;39;49m \x1b[47;1m " else "1;1m FAILED \x1b[0;39;49m \x1b[47;1m ", script.name, " \x1b[0;39;49m ", file_path, '\n' }) catch {};
    if(term.Exited == 0)
        return;
    stdout.writeAll(child_stdout.items) catch {};
    stdout.writeAll(child_stderr.items) catch {};
}

pub fn main() !void {
    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = aa.allocator();
    defer aa.deinit();
    const dir = std.fs.cwd();
    const file = try dir.openFile("index.json", .{
        .mode = .read_write
    });
    defer file.close();
    const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    const index = try std.json.parseFromSliceLeaky(IndexJson, allocator, file_content, .{});
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var stdout_buffer: [4096]u8 = undefined;
    var obw = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &obw.interface;
    defer stdout.flush() catch {};
    cmd_check: { if(args.len >= 2) {
        const Command = enum {
            hash,
            @"test",
            testall,
        };
        const cmd_type = std.meta.stringToEnum(Command, args[1]) orelse {
            try stdout.print("{s}{s}{s}", .{ "Unknown command: `", args[1], "`.\n" });
            break :cmd_check;
        };
        switch (cmd_type) {
            .hash => {},
            .@"test" => {
                if(args.len < 3)
                    return error.MissingArgument;
                var count: u32 = 0;
                var mutex: std.Thread.Mutex = .{};
                const target = for(index.scripts) |script| {
                    if(std.mem.eql(u8, script.name, args[2]))
                        break script;
                } else return error.ScriptNotFound;
                testScript(allocator, stdout, &mutex, &count, 1, target, args[3..]);
            },
            .@"testall" => {
                var count: u32 = 0;
                var mutex: std.Thread.Mutex = .{};
                var wg: std.Thread.WaitGroup = .{};
                var tsa: std.heap.ThreadSafeAllocator = .{
                    .child_allocator = allocator
                };
                for(index.scripts) |script|
                    wg.spawnManager(testScript, .{ tsa.allocator(), stdout, &mutex, &count, @as(u32, @intCast(index.scripts.len)), script, args[2..] });
                wg.wait();
            },
        }
    } }
    try index.calculateHashes(dir, allocator);
    try file.seekTo(0);
    var fileout_buffer: [4096]u8 = undefined;
    var bw = file.writer(&fileout_buffer);
    try std.json.Stringify.value(index, .{ .whitespace = .indent_tab }, &bw.interface);
    try bw.interface.flush();
}