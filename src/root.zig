//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const AllCred = @import("AllCred");
const builtin = @import("builtin");

const Credential = @import("share.zig").Credential;
const CredentialError = @import("share.zig").CredentialError;
const CredentialDiagnostic = @import("share.zig").CredentialDiagnostic;

const impl = switch (builtin.os.tag) {
    .linux => @import("linux.zig"),
    .windows => @import("windows.zig"),
    .macos => @import("macos.zig"),
    else => @compileError("Unsupported OS"),
};

pub fn set(cred: Credential, diagnostic: *CredentialDiagnostic) !void {
    return impl.set(cred, diagnostic);
}

pub fn get(
    allocator: std.mem.Allocator,
    service: []const u8,
    account: []const u8,
    diagnostic: ?*CredentialDiagnostic,
) CredentialError!Credential {
    return impl.get(allocator, service, account, diagnostic);
}

pub fn delete(allocator: std.mem.Allocator, service: []const u8, account: []const u8, diagnostic: ?*CredentialDiagnostic) !void {
    return impl.delete(allocator, service, account, diagnostic);
}
