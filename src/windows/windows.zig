const std = @import("std");

const wincred = @import("wincred.zig");

const share = @import("../share.zig");

fn formatErrorMessage(allocator: std.mem.Allocator, err_code: u32) ?[]const u8 {
    var buffer: [*:0]u16 = undefined;
    const num_chars = wincred.FormatMessageW(
        wincred.FORMAT_MESSAGE_ALLOCATE_BUFFER | wincred.FORMAT_MESSAGE_FROM_SYSTEM | wincred.FORMAT_MESSAGE_IGNORE_INSERTS,
        null,
        err_code,
        0,
        &buffer,
        0,
        null,
    );
    defer _ = wincred.LocalFree(@ptrCast(buffer));
    if (num_chars == 0) return null;
    const msg_u16 = buffer[0..num_chars];
    return std.unicode.utf16LeToUtf8Alloc(allocator, msg_u16) catch null;
}

pub fn set(cred: share.Credential, diagnostic: ?*share.CredentialDiagnostic) !void {
    if (diagnostic) |diag| {
        diag.* = share.CredentialDiagnostic{ .service = cred.service, .account = cred.account, .error_message = null };
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const target_name_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, try std.fmt.allocPrint(allocator, "{s}\\{s}", .{ cred.service, cred.account }));
    const account_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, try std.fmt.allocPrint(allocator, "{s}", .{cred.account}));
    const password_w: [:0]u16 = if (cred.secret) |secret|
        try std.unicode.utf8ToUtf16LeAllocZ(allocator, try std.fmt.allocPrint(allocator, "{s}", .{secret}))
    else
        try std.unicode.utf8ToUtf16LeAllocZ(allocator, "");
    const description_w: [:0]u16 = if (cred.description) |desc|
        try std.unicode.utf8ToUtf16LeAllocZ(allocator, try std.fmt.allocPrint(allocator, "{s}", .{desc}))
    else
        try std.unicode.utf8ToUtf16LeAllocZ(allocator, try std.fmt.allocPrint(allocator, "Credential for {s} ({s})", .{ cred.service, cred.account }));

    const blob_size: u32 = @intCast(password_w.len * @sizeOf(u16));

    var win_cred = wincred.CREDENTIALW{
        .Flags = 0,
        .Type = 1,
        .TargetName = @ptrCast(@constCast(target_name_w.ptr)),
        .Comment = @ptrCast(@constCast(description_w.ptr)),
        .LastWritten = wincred.FILETIME{ .dwLowDateTime = 0, .dwHighDateTime = 0 },
        .CredentialBlobSize = blob_size,
        .CredentialBlob = if (blob_size > 0) @ptrCast(@constCast(@as([*:0]u16, password_w.ptr))) else null,
        .Persist = 2,
        .AttributeCount = 0,
        .Attributes = null,
        .TargetAlias = null,
        .UserName = @ptrCast(@constCast(account_w.ptr)),
    };

    const is_success = wincred.CredWriteW(&win_cred, 0);

    if (is_success != 0) {
        return;
    } else {
        const err_code = std.os.windows.GetLastError();
        if (diagnostic) |diag| {
            diag.error_message = formatErrorMessage(allocator, @intFromEnum(err_code));
        }
        return share.CredentialError.SetFailed;
    }
}

pub fn get(
    allocator: std.mem.Allocator,
    service: []const u8,
    account: []const u8,
    diagnostic: ?*share.CredentialDiagnostic,
) share.CredentialError!share.Credential {
    if (diagnostic) |diag| {
        diag.* = share.CredentialDiagnostic{ .service = service, .account = account, .error_message = null };
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const target_name_w = std.unicode.utf8ToUtf16LeAllocZ(arena_allocator, std.fmt.allocPrint(arena_allocator, "{s}\\{s}", .{ service, account }) catch return share.CredentialError.UnicodeError) catch return share.CredentialError.UnicodeError;

    var cred_ptr: ?wincred.PCREDENTIALW = null;
    const is_success = wincred.CredReadW(target_name_w.ptr, 1, 0, &cred_ptr);
    defer wincred.CredFree(cred_ptr);

    if (is_success == 0) {
        const err_code = std.os.windows.GetLastError();
        if (diagnostic) |diag| {
            diag.error_message = formatErrorMessage(arena_allocator, @intFromEnum(err_code));
        }
        return share.CredentialError.GetFailed;
    }

    const cred = cred_ptr.?;
    const user_name_slice = std.mem.sliceTo(cred.UserName orelse return share.CredentialError.GetFailed, 0);
    const comment_slice: ?[]const u16 = if (cred.Comment) |c| std.mem.sliceTo(c, 0) else null;

    const blob_byte_len = cred.CredentialBlobSize;
    const secret_slice: ?[]const u8 = if (blob_byte_len > 0 and cred.CredentialBlob != null) blk: {
        const blob_u16: [*]const u16 = @ptrCast(@alignCast(cred.CredentialBlob.?));
        const num_u16 = blob_byte_len / @sizeOf(u16);
        break :blk std.unicode.utf16LeToUtf8Alloc(allocator, blob_u16[0..num_u16]) catch null;
    } else null;

    return share.Credential{
        .service = try allocator.dupe(u8, service),
        .account = std.unicode.utf16LeToUtf8Alloc(allocator, user_name_slice) catch return share.CredentialError.UnicodeError,
        .secret = secret_slice,
        .description = if (comment_slice) |cs| std.unicode.utf16LeToUtf8Alloc(allocator, cs) catch return share.CredentialError.UnicodeError else null,
        .persist = true,
    };
}

pub fn delete(service: []const u8, account: []const u8, diagnostic: ?*share.CredentialDiagnostic) !void {
    if (diagnostic) |diag| {
        diag.* = share.CredentialDiagnostic{ .service = service, .account = account, .error_message = null };
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const target_name_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, std.fmt.allocPrint(allocator, "{s}\\{s}", .{ service, account }) catch return share.CredentialError.UnicodeError) catch return share.CredentialError.UnicodeError;

    const is_success = wincred.CredDeleteW(target_name_w.ptr, 1, 0);

    if (is_success != 0) {
        return;
    } else {
        const err_code = std.os.windows.GetLastError();
        if (diagnostic) |diag| {
            diag.error_message = formatErrorMessage(allocator, @intFromEnum(err_code));
        }
        return share.CredentialError.DeleteFailed;
    }
}
