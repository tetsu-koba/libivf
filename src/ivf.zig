const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;

pub const IVFSignature = "DKIF";
pub const IVFHeaderSize = 32;
pub const IVFFrameHeaderSize = 12;

pub const IVFHeader = struct {
    //signature: [IVFSignature.len]u8, // "DKIF"
    //version: u16, // File format version (usually 0)
    //header_size: u16, // Size of the header in bytes (32 bytes for version 0)
    fourcc: [4]u8, // Codec used (e.g., "VP80" for VP8, "VP90" for VP9)
    width: u16, // Width of the video in pixels
    height: u16, // Height of the video in pixels
    frame_rate: u32, // Frame rate in Hz
    time_scale: u32, // Time scale (number of time units per second, usually the same as frame rate)
    num_frames: u32, // Total number of frames in the file
    //unused: u32, // Reserved for future use (set to 0)
};

pub const IVFFrameHeader = struct {
    frame_size: u32, // Size of the frame data in bytes
    timestamp: u64, // Presentation timestamp of the frame in time units
};

pub const IVFReader = struct {
    header: IVFHeader,
    file: fs.File,
    reader: fs.File.Reader,

    const Self = @This();

    pub fn init(file: fs.File) !IVFReader {
        var self = IVFReader{
            .file = file,
            .reader = file.reader(),
            .header = undefined,
        };
        try self.readIVFHeader();
        return self;
    }

    pub fn deinit(_: *Self) void {}

    fn readIVFHeader(self: *Self) !void {
        var r = self.reader;
        var sig: [IVFSignature.len]u8 = undefined;
        if (IVFSignature.len != try r.readAll(&sig) or !mem.eql(u8, &sig, IVFSignature)) {
            return error.IvfFormat;
        }
        const version = try r.readIntLittle(u16);
        if (version != 0) {
            return error.IvfFormat;
        }
        const header_size = try r.readIntLittle(u16);
        if (header_size != 32) {
            return error.IvfFormat;
        }
        var fourcc = &self.header.fourcc;
        if (fourcc.len != try r.readAll(fourcc)) {
            return error.IvfFormat;
        }
        self.header.width = try r.readIntLittle(u16);
        self.header.height = try r.readIntLittle(u16);
        self.header.frame_rate = try r.readIntLittle(u32);
        self.header.time_scale = try r.readIntLittle(u32);
        self.header.num_frames = try r.readIntLittle(u32);
        _ = try r.readIntLittle(u32); // unused
    }

    pub fn readIVFFrameHeader(self: *Self, frame_header: *IVFFrameHeader) !void {
        frame_header.frame_size = try self.reader.readIntLittle(u32);
        frame_header.timestamp = try self.reader.readIntLittle(u64);
    }

    pub fn readFrame(self: *Self, frame: []u8) !usize {
        return try self.file.readAll(frame);
    }

    pub fn skipFrame(self: *Self, frame_size: u32) !void {
        try self.file.seekBy(frame_size);
    }
};

pub const IVFWriter = struct {
    file: fs.File,
    writer: fs.File.Writer,
    frame_count: u32,

    const Self = @This();

    pub fn init(file: fs.File, header: *const IVFHeader) !IVFWriter {
        var self = IVFWriter{
            .file = file,
            .writer = file.writer(),
            .frame_count = 0,
        };
        try self.writeIVFHeader(header);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.file.seekTo(24) catch {
            // Not seekable. return silently.
            return;
        };
        self.writer.writeIntLittle(u32, self.frame_count) catch {
            return;
        };
        self.file.seekFromEnd(0) catch {
            return;
        };
    }

    fn writeIVFHeader(self: *Self, header: *const IVFHeader) !void {
        try self.writer.writeAll(IVFSignature);
        try self.writer.writeIntLittle(u16, 0);
        try self.writer.writeIntLittle(u16, IVFHeaderSize);
        try self.writer.writeAll(&header.fourcc);
        try self.writer.writeIntLittle(u16, header.width);
        try self.writer.writeIntLittle(u16, header.height);
        try self.writer.writeIntLittle(u32, header.frame_rate);
        try self.writer.writeIntLittle(u32, header.time_scale);
        try self.writer.writeIntLittle(u32, header.num_frames);
        try self.writer.writeIntLittle(u32, 0);
    }

    pub fn writeIVFFrame(self: *Self, frame: []const u8, timestamp: u64) !void {
        try self.writer.writeIntLittle(u32, @truncate(u32, frame.len));
        try self.writer.writeIntLittle(u64, timestamp);
        try self.writer.writeAll(frame);
        self.frame_count += 1;
    }
};
