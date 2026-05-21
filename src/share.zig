pub const Credential = struct {
    // --- 必填项 ---
    /// 服务或目标的唯一标识，例如 "github.com" 或 "myapp.auth"
    service: []const u8,

    /// 账号名或用户名，例如 "admin"
    account: []const u8,

    /// 敏感数据（密码、Token、二进制密钥等）
    /// 由于通用于增删查，所以可以不带密码
    secret: ?[]const u8,

    // --- 可选项（带默认值） ---
    /// 友好的显示描述，部分平台（如 Windows/macOS）会在凭据管理器界面显示这个
    description: ?[]const u8 = null,

    /// 是否持久化保存。如果是 false，可能重启后就消失（主要针对 Windows Session 凭据）
    persist: bool = true,
};

pub const CredentialError = error{
    // Set 操作失败（可携带具体原因）
    SetFailed,

    // Get 操作失败
    GetFailed,

    // 删除失败
    DeleteFailed,

    // 找不到（建议携带 service/account 信息）
    NotFound,

    // 权限问题（建议携带哪个操作被拒绝）
    AccessDenied,

    // 其他错误（建议携带原始错误）
    Unexpected,
};

pub const CredentialDiagnostic = struct {
    // 涉及到的凭据的服务和账号信息
    service: []const u8,
    account: []const u8,

    // 失败时的错误信息（如果有的话）
    error_message: ?[]const u8,
};
