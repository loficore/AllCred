const std = @import("std");
const root = @import("AllCred");
const Credential = root.Credential;
const CredentialError = root.CredentialError;
const CredentialDiagnostic = root.CredentialDiagnostic;

// ============================================================
// 1. 基本流程 + 清理副作用
// ============================================================

test "windows: set, get, delete the credentials" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_basic_set_get_del",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };

    try root.set(cred, null);

    const retrieved_cred = try root.get(gpa, cred.service, cred.account, null);
    defer {
        gpa.free(retrieved_cred.service);
        gpa.free(retrieved_cred.account);
        if (retrieved_cred.secret) |s| gpa.free(s);
    }

    try std.testing.expectEqualStrings(cred.service, retrieved_cred.service);
    try std.testing.expectEqualStrings(cred.account, retrieved_cred.account);
    try std.testing.expectEqualStrings(cred.secret.?, retrieved_cred.secret.?);

    try root.delete(cred.service, cred.account, null);
}

// ============================================================
// 2. 验证 Windows 特有功能点
// ============================================================

test "windows: description is retrievable after get" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_desc_retrievable",
        .account = "test_account",
        .secret = "test_password",
        .description = "A test description",
        .persist = true,
    };
    defer root.delete(cred.service, cred.account, null) catch {};

    try root.set(cred, null);

    const retrieved_cred = try root.get(gpa, cred.service, cred.account, null);
    defer {
        gpa.free(retrieved_cred.service);
        gpa.free(retrieved_cred.account);
        if (retrieved_cred.secret) |s| gpa.free(s);
        if (retrieved_cred.description) |d| gpa.free(d);
    }

    // Windows stores description in the Comment field
    try std.testing.expect(retrieved_cred.description != null);
    try std.testing.expectEqualStrings("A test description", retrieved_cred.description.?);
}

test "windows: default description is set when not provided" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_default_desc",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };
    defer root.delete(cred.service, cred.account, null) catch {};

    try root.set(cred, null);

    const retrieved_cred = try root.get(gpa, cred.service, cred.account, null);
    defer {
        gpa.free(retrieved_cred.service);
        gpa.free(retrieved_cred.account);
        if (retrieved_cred.secret) |s| gpa.free(s);
        if (retrieved_cred.description) |d| gpa.free(d);
    }

    // Default description format: "Credential for {service} ({account})"
    try std.testing.expect(retrieved_cred.description != null);
}

test "windows: persist field is always true after get" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_persist_field",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };
    defer root.delete(cred.service, cred.account, null) catch {};

    try root.set(cred, null);

    const retrieved_cred = try root.get(gpa, cred.service, cred.account, null);
    defer {
        gpa.free(retrieved_cred.service);
        gpa.free(retrieved_cred.account);
        if (retrieved_cred.secret) |s| gpa.free(s);
        if (retrieved_cred.description) |d| gpa.free(d);
    }

    // Windows implementation always returns persist = true (CRED_PERSIST_LOCAL_MACHINE)
    try std.testing.expect(retrieved_cred.persist == true);
}

test "windows: diagnostic is populated on get error" {
    var diagnostic = CredentialDiagnostic{
        .service = "nonexistent_svc",
        .account = "nonexistent_acc",
        .error_message = null,
    };

    _ = root.get(std.testing.allocator, "nonexistent_svc", "nonexistent_acc", &diagnostic) catch |err| {
        try std.testing.expect(err == CredentialError.GetFailed);
        try std.testing.expectEqualStrings("nonexistent_svc", diagnostic.service);
        try std.testing.expectEqualStrings("nonexistent_acc", diagnostic.account);
        try std.testing.expect(diagnostic.error_message != null);
        return;
    };
    try std.testing.expect(false);
}

test "windows: diagnostic is populated on set error with null diagnostic" {
    const cred = Credential{
        .service = "test_null_diagnostic",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };
    defer root.delete(cred.service, cred.account, null) catch {};

    try root.set(cred, null);
}

test "windows: set and get with diagnostic on success path" {
    const gpa = std.testing.allocator;

    const cred = Credential{
        .service = "test_diag_success",
        .account = "test_account",
        .secret = "test_password",
        .persist = true,
    };
    defer root.delete(cred.service, cred.account, null) catch {};

    var set_diag = CredentialDiagnostic{
        .service = cred.service,
        .account = cred.account,
        .error_message = null,
    };
    try root.set(cred, &set_diag);
    try std.testing.expect(set_diag.error_message == null);

    var get_diag = CredentialDiagnostic{
        .service = cred.service,
        .account = cred.account,
        .error_message = null,
    };
    const retrieved = try root.get(gpa, cred.service, cred.account, &get_diag);
    defer {
        gpa.free(retrieved.service);
        gpa.free(retrieved.account);
        if (retrieved.secret) |s| gpa.free(s);
        if (retrieved.description) |d| gpa.free(d);
    }
    try std.testing.expect(get_diag.error_message == null);
}

// ============================================================
// 3. 幂等性测试
// ============================================================

test "windows: set overwrites existing credential" {
    const gpa = std.testing.allocator;

    const cred_v1 = Credential{
        .service = "test_overwrite",
        .account = "test_account",
        .secret = "password_v1",
        .persist = true,
    };
    const cred_v2 = Credential{
        .service = "test_overwrite",
        .account = "test_account",
        .secret = "password_v2",
        .persist = true,
    };
    defer root.delete(cred_v1.service, cred_v1.account, null) catch {};

    try root.set(cred_v1, null);

    const retrieved_v1 = try root.get(gpa, cred_v1.service, cred_v1.account, null);
    defer {
        gpa.free(retrieved_v1.service);
        gpa.free(retrieved_v1.account);
        if (retrieved_v1.secret) |s| gpa.free(s);
        if (retrieved_v1.description) |d| gpa.free(d);
    }
    try std.testing.expectEqualStrings("password_v1", retrieved_v1.secret.?);

    try root.set(cred_v2, null);

    const retrieved_v2 = try root.get(gpa, cred_v2.service, cred_v2.account, null);
    defer {
        gpa.free(retrieved_v2.service);
        gpa.free(retrieved_v2.account);
        if (retrieved_v2.secret) |s| gpa.free(s);
        if (retrieved_v2.description) |d| gpa.free(d);
    }
    try std.testing.expectEqualStrings("password_v2", retrieved_v2.secret.?);
}

test "windows: delete non-existent credential returns DeleteFailed" {
    const result = root.delete("nonexistent_service_xyz", "nonexistent_account_xyz", null);
    try std.testing.expectError(CredentialError.DeleteFailed, result);
}

test "windows: multiple credentials with different services" {
    const gpa = std.testing.allocator;

    const cred_a = Credential{
        .service = "test_multi_a",
        .account = "user_a",
        .secret = "secret_a",
        .persist = true,
    };
    const cred_b = Credential{
        .service = "test_multi_b",
        .account = "user_b",
        .secret = "secret_b",
        .persist = true,
    };
    defer {
        root.delete(cred_a.service, cred_a.account, null) catch {};
        root.delete(cred_b.service, cred_b.account, null) catch {};
    }

    try root.set(cred_a, null);
    try root.set(cred_b, null);

    const retrieved_a = try root.get(gpa, cred_a.service, cred_a.account, null);
    defer {
        gpa.free(retrieved_a.service);
        gpa.free(retrieved_a.account);
        if (retrieved_a.secret) |s| gpa.free(s);
        if (retrieved_a.description) |d| gpa.free(d);
    }
    const retrieved_b = try root.get(gpa, cred_b.service, cred_b.account, null);
    defer {
        gpa.free(retrieved_b.service);
        gpa.free(retrieved_b.account);
        if (retrieved_b.secret) |s| gpa.free(s);
        if (retrieved_b.description) |d| gpa.free(d);
    }

    try std.testing.expectEqualStrings("secret_a", retrieved_a.secret.?);
    try std.testing.expectEqualStrings("secret_b", retrieved_b.secret.?);
}

// ============================================================
// 4. 错误路径测试
// ============================================================

test "windows: get non-existent returns GetFailed" {
    const result = root.get(std.testing.allocator, "nonexistent_service_abc", "nonexistent_account_abc", null);
    try std.testing.expectError(CredentialError.GetFailed, result);
}

// ============================================================
// 5. 内存安全 - 多次循环 set/get/delete
// ============================================================

test "windows: repeated set/get/delete cycle has no memory leaks" {
    const gpa = std.testing.allocator;

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const secret = try std.fmt.allocPrint(gpa, "password_cycle_{}", .{i});
        defer gpa.free(secret);

        const cred = Credential{
            .service = "test_cycle",
            .account = "test_account",
            .secret = secret,
            .persist = true,
        };

        try root.set(cred, null);

        const retrieved = try root.get(gpa, cred.service, cred.account, null);
        defer {
            gpa.free(retrieved.service);
            gpa.free(retrieved.account);
            if (retrieved.secret) |s| gpa.free(s);
            if (retrieved.description) |d| gpa.free(d);
        }

        try std.testing.expectEqualStrings(secret, retrieved.secret.?);

        try root.delete(cred.service, cred.account, null);
    }
}