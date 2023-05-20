const std = @import("std");
const fs = std.fs;
const io = std.io;
const os = std.os;

const IVF = @import("ivf.zig");

pub fn main() !void {
    const alc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alc);
    defer std.process.argsFree(alc, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} ivf-file\n", .{args[0]});
        os.exit(1);
    }
    const filename = args[1];
    try dumpIVFFile(filename);
}

pub fn dumpIVFFile(filename: []const u8) !void {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();
    var reader = try IVF.IVFReader.init(file);
    defer reader.deinit();

    // Print IVF header information
    std.debug.print("IVF Header Information:\n", .{});
    std.debug.print("  FourCC: {s}\n", .{reader.header.fourcc});
    std.debug.print("  Width: {d}\n", .{reader.header.width});
    std.debug.print("  Height: {d}\n", .{reader.header.height});
    std.debug.print("  Num of framerate: {d}\n", .{reader.header.framerate_num});
    std.debug.print("  Den of framerate: {d}\n", .{reader.header.framerate_den});
    std.debug.print("  Number of Frames: {d}\n", .{reader.header.num_frames});

    // Read and print IVF frame headers until the end of the file
    var frame_index: usize = 0;
    while (true) {
        var ivf_frame_header: IVF.IVFFrameHeader = undefined;
        reader.readIVFFrameHeader(&ivf_frame_header) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        std.debug.print("Frame {}:{}\n", .{ frame_index, ivf_frame_header });

        // Skip the frame data according to frame_size
        try reader.skipFrame(ivf_frame_header.frame_size);

        frame_index += 1;
    }
}
