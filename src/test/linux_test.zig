const std = @import("std");
const root = @import("../root.zig");
const Credential = @import("../share.zig").Credential;

test "linux : set,get,delete the credentials" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_service",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };

    // set
    root.set(cred) catch |err| {
        std.debug.print("Failed to set credential: {}\n", .{err});
        return;
    };

    // get
    const retrieved_cred = root.get(gpa, cred.service, cred.account) catch |err| {
        std.debug.print("Failed to get credential: {}\n", .{err});
        return;
    };
    defer {
        gpa.free(retrieved_cred.service);
        gpa.free(retrieved_cred.account);
        gpa.free(retrieved_cred.secret);
    }

    try std.testing.expectEqualStrings(cred.service, retrieved_cred.service);
    try std.testing.expectEqualStrings(cred.account, retrieved_cred.account);
    try std.testing.expectEqualStrings(cred.secret, retrieved_cred.secret);

    // delete
    root.delete(gpa, cred.service, cred.account) catch |err| {
        std.debug.print("Failed to delete credential: {}\n", .{err});
        return;
    };
}
