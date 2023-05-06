const std = @import("std");
const testing = std.testing;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const IVF = @import("ivf.zig");

fn checkIVF(dirname: []const u8, filename: []const u8) !void {
    var dir = try fs.cwd().openDir(dirname, .{});
    defer dir.close();
    var file = try dir.openFile(filename, .{});
    defer file.close();
    var reader = try IVF.IVFReader.init(file);
    defer reader.deinit();

    try testing.expectEqualSlices(u8, &reader.header.fourcc, "VP80");
    try testing.expect(reader.header.width == 160);
    try testing.expect(reader.header.height == 120);
    try testing.expect(reader.header.frame_rate == 15);
    try testing.expect(reader.header.time_scale == 1);
    try testing.expect(reader.header.num_frames == 75);

    var frame_index: usize = 0;
    while (true) {
        var ivf_frame_header: IVF.IVFFrameHeader = undefined;
        reader.readIVFFrameHeader(&ivf_frame_header) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        try testing.expect(ivf_frame_header.timestamp == frame_index);

        // Skip the frame data according to frame_size
        try reader.skipFrame(ivf_frame_header.frame_size);

        frame_index += 1;
    }
}

test "IVF reader" {
    try checkIVF("testfiles", "sample01_vp8.ivf");
}

fn copyIVF(dirname: []const u8, filename: []const u8, outfiename: []const u8) !void {
    var dir = try fs.cwd().openDir(dirname, .{});
    defer dir.close();
    var file = try dir.openFile(filename, .{});
    defer file.close();
    var outfile = try dir.createFile(outfiename, .{});
    defer outfile.close();
    var reader = try IVF.IVFReader.init(file);
    defer reader.deinit();

    try testing.expectEqualSlices(u8, &reader.header.fourcc, "VP80");
    try testing.expect(reader.header.width == 160);
    try testing.expect(reader.header.height == 120);
    try testing.expect(reader.header.frame_rate == 15);
    try testing.expect(reader.header.time_scale == 1);
    try testing.expect(reader.header.num_frames == 75);

    var writer = try IVF.IVFWriter.init(outfile, &reader.header);
    defer writer.deinit();

    var frame_index: usize = 0;
    var buf: [64 * 1024]u8 = undefined;
    while (true) {
        var ivf_frame_header: IVF.IVFFrameHeader = undefined;
        reader.readIVFFrameHeader(&ivf_frame_header) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        try testing.expect(ivf_frame_header.timestamp == frame_index);

        try testing.expect(ivf_frame_header.frame_size == try reader.readFrame(buf[0..ivf_frame_header.frame_size]));
        try writer.writeIVFFrame(buf[0..ivf_frame_header.frame_size], ivf_frame_header.timestamp);

        frame_index += 1;
    }
}

test "IVF writer" {
    try copyIVF("testfiles", "sample01_vp8.ivf", "out.ivf");
    try checkIVF("testfiles", "out.ivf");
}
