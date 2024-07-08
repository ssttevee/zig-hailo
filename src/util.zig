const std = @import("std");

pub fn cstr(s: []const u8) []const u8 {
    if (s.len > 0) {
        if (std.mem.indexOfScalar(u8, s, 0)) |end| {
            return s[0..end];
        }
    }

    return s;
}
