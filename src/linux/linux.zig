const std = @import("std");
const c = @cImport({
    @cInclude("libsecret/secret.h");
});

const Credential = @import("../share.zig").Credential;
const CredentialError = @import("../share.zig").CredentialError;

var allcred_schema: ?*c.SecretSchema = null;

fn getSchema() *c.SecretSchema {
    if (allcred_schema == null) {
        allcred_schema = c.secret_schema_new(
            "org.allcred.Credential",
            c.SECRET_SCHEMA_NONE,
            "service\x00",
            c.SECRET_SCHEMA_ATTRIBUTE_STRING,
            "account\x00",
            c.SECRET_SCHEMA_ATTRIBUTE_STRING,
            @as(?*anyopaque, null),
        );
    }
    return allcred_schema.?;
}

const CredentialDiagnostic = @import("../share.zig").CredentialDiagnostic;

pub fn set(cred: Credential, diagnostic: ?*CredentialDiagnostic) !void {
    if (diagnostic) |diag| {
        diag.* = CredentialDiagnostic{ .service = cred.service, .account = cred.account, .error_message = null };
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const service_z = try std.fmt.allocPrintSentinel(allocator, "{s}", .{cred.service}, '\x00');
    const account_z = try std.fmt.allocPrintSentinel(allocator, "{s}", .{cred.account}, '\x00');
    const password_z = if (cred.secret) |secret| try std.fmt.allocPrintSentinel(allocator, "{s}", .{secret}, '\x00') else try std.fmt.allocPrintSentinel(allocator, "", .{}, '\x00');
    const description_z = if (cred.description) |desc| try std.fmt.allocPrintSentinel(allocator, "{s}", .{desc}, '\x00') else try std.fmt.allocPrintSentinel(allocator, "Credential for {s} ({s})", .{ cred.service, cred.account }, '\x00');

    // 用一个可选的 GError 指针来捕获错误信息，如果不为空，就需要在后续处理完毕后释放它
    var set_error: ?*c.GError = null;

    const is_success = c.secret_password_store_sync(
        getSchema(),
        c.SECRET_COLLECTION_DEFAULT,
        description_z.ptr,
        password_z.ptr,
        null,
        &set_error,
        "service\x00",
        service_z.ptr,
        "account\x00",
        account_z.ptr,
        @as(?*anyopaque, null), // 同上
    );

    if (is_success != 0) {
        return;
    } else {
        if (set_error) |err| {
            defer c.g_error_free(err);

            std.debug.print("Failed to set credential: {s}\n", .{std.mem.sliceTo(err.message, 0)});
            if (diagnostic) |diag| {
                diag.*.error_message = std.mem.sliceTo(err.message, 0);
            }
            return CredentialError.SetFailed;
        } else {
            std.debug.print("Failed to set credential: Unknown error\n", .{});
            if (diagnostic) |diag| {
                diag.*.error_message = "Unknown error";
            }
            return CredentialError.SetFailed;
        }
    }
}

/// 获取凭据的函数实现
/// - **参数** : **allocator**  用户传入任意的内存分配器，用于分配返回的 Credential 结构体中的字符串字段
/// - **参数** : **service** 和 **account** 这两个字符串参数用于指定要获取的凭据的服务和账户信息，必须以 null 结尾
/// - **返回值** : 成功时返回 Credential 结构体，失败时返回 CredentialError 错误码，当然也有可能是其他错误，如内存不足
pub fn get(allocator: std.mem.Allocator, service: []const u8, account: []const u8, diagnostic: ?*CredentialDiagnostic) !Credential {

    // 前置工作
    if (diagnostic) |diag| {
        diag.* = CredentialDiagnostic{ .service = service, .account = account, .error_message = null };
    }

    var get_error: ?*c.GError = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const service_z = try std.fmt.allocPrintSentinel(arena_alloc, "{s}", .{service}, '\x00');
    const account_z = try std.fmt.allocPrintSentinel(arena_alloc, "{s}", .{account}, '\x00');

    const password_ptr = c.secret_password_lookup_sync(
        getSchema(),
        null,
        &get_error,
        "service\x00",
        service_z.ptr,
        "account\x00",
        account_z.ptr,
        @as(?*anyopaque, null), // 同上
    );
    defer c.secret_password_free(password_ptr);

    if (password_ptr) |value| {
        const password = std.mem.sliceTo(value, 0);
        // 这里直接返回一个 Credential 结构体，包含 service、account 和 password 字段
        const credential_temp = Credential{
            .service = try allocator.dupe(u8, service),
            .account = try allocator.dupe(u8, account),
            .secret = try allocator.dupe(u8, password),
            .description = null, // libsecret 没有提供 description 字段的接口，所以暂时设置为 null
            .persist = true, // libsecret 默认是持久化存储的，所以设置为 true
        };
        return credential_temp;
    } else {
        if (get_error) |err| {
            defer c.g_error_free(get_error);

            std.debug.print("Failed to get credential: {s}\n", .{std.mem.sliceTo(err.message, 0)});
            if (diagnostic) |diag| {
                diag.*.error_message = std.mem.sliceTo(err.message, 0);
            }
            return CredentialError.GetFailed;
        } else {
            std.debug.print("Failed to get credential: Unknown error\n", .{});
            if (diagnostic) |diag| {
                diag.*.error_message = "Unknown error";
            }
            return CredentialError.GetFailed;
        }
    }
}

/// 删除凭据的函数实现
/// - **参数** : **allocator**  用户传入任意的内存分配器，用于分配返回的 Credential 结构体中的字符串字段
/// - **参数** : **service** 和 **account** 这两个字符串参数用于指定要删除的凭据的服务和账户信息，必须以 null 结尾
/// - **返回值** : 成功时返回 void，失败时返回 CredentialError 错误码，当然也有可能是其他错误，如内存不足
pub fn delete(service: []const u8, account: []const u8, diagnostic: ?*CredentialDiagnostic) !void {
    if (diagnostic) |diag| {
        diag.* = CredentialDiagnostic{ .service = service, .account = account, .error_message = null };
    }

    var delete_error: ?*c.GError = null;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const service_z = try std.fmt.allocPrintSentinel(arena_alloc, "{s}", .{service}, '\x00');
    const account_z = try std.fmt.allocPrintSentinel(arena_alloc, "{s}", .{account}, '\x00');

    const is_success = c.secret_password_clear_sync(
        getSchema(),
        null,
        &delete_error,
        "service\x00",
        service_z.ptr,
        "account\x00",
        account_z.ptr,
        @as(?*anyopaque, null), // 同上
    );

    if (is_success != 0) {
        return;
    } else {
        if (delete_error) |err| {
            defer c.g_error_free(delete_error);

            std.debug.print("Failed to delete credential: {s}\n", .{std.mem.sliceTo(err.message, 0)});
            if (diagnostic) |diag| {
                diag.*.error_message = std.mem.sliceTo(err.message, 0);
            }
            return CredentialError.DeleteFailed;
        } else {
            std.debug.print("Failed to delete credential: Unknown error\n", .{});
            if (diagnostic) |diag| {
                diag.*.error_message = "Unknown error";
            }
            return CredentialError.DeleteFailed;
        }
    }
}
