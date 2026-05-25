const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const LPCWSTR = windows.LPCWSTR;
pub const FILETIME = windows.FILETIME;
const BYTE = windows.BYTE;
const LPBYTE = [*]BYTE;
const LPSTR = windows.LPSTR;
const LPWSTR = windows.LPWSTR;

const CREDENTIAL_ATTRIBUTEA = extern struct {
    Keyword: LPSTR,
    Flags: DWORD,
    ValueSize: DWORD,
    Value: LPBYTE,
};
const PCREDENTIAL_ATTRIBUTEA = [*]CREDENTIAL_ATTRIBUTEA;

const CREDENTIAL_ATTRIBUTEW = extern struct {
    Keyword: ?[*:0]u16, // 对应 wchar_t* 或 LPWSTR（属性的键名）
    Flags: u32, // 对应 DWORD
    ValueSize: u32, // 对应 DWORD（Value 数据的字节大小）
    Value: ?[*]u8, // 对应 LPBYTE（属性的值，二进制数据）
};

const PCREDENTIAL_ATTRIBUTEW = [*]CREDENTIAL_ATTRIBUTEW;

pub const CREDENTIALW = extern struct {
    Flags: DWORD,
    Type: DWORD,
    TargetName: ?LPWSTR, // 对应 C 里的 wchar_t* 或 LPWSTR
    Comment: ?LPWSTR, // 对应 C 里的 wchar_t* 或 LPWSTR
    LastWritten: FILETIME,
    CredentialBlobSize: DWORD,
    CredentialBlob: ?LPBYTE,
    Persist: DWORD,
    AttributeCount: DWORD,
    Attributes: ?PCREDENTIAL_ATTRIBUTEW,
    TargetAlias: ?LPWSTR, // 对应 C 里的 wchar_t* 或 LPWSTR
    UserName: ?LPWSTR, // 对应 C 里的 wchar_t* 或 LPWSTR
};

pub const PCREDENTIALW = *CREDENTIALW;

// FormatMessageW 关键常量
pub const FORMAT_MESSAGE_ALLOCATE_BUFFER: DWORD = 0x00000100;
pub const FORMAT_MESSAGE_FROM_SYSTEM: DWORD = 0x00001000;
pub const FORMAT_MESSAGE_IGNORE_INSERTS: DWORD = 0x00000200;

// 声明外部 Win32 函数（来自 kernel32）
pub extern "kernel32" fn FormatMessageW(
    dwFlags: DWORD,
    lpSource: ?*const anyopaque,
    dwMessageId: DWORD,
    dwLanguageId: DWORD,
    lpBuffer: *[*:0]u16, // 这里传指针的指针，让 Windows 帮我们分配内存
    nSize: DWORD,
    Arguments: ?*anyopaque,
) DWORD;

pub extern "kernel32" fn LocalFree(
    hMem: *anyopaque,
) ?*anyopaque;

pub extern "advapi32" fn CredWriteW(Credential: PCREDENTIALW, Flags: DWORD) BOOL;

pub extern "advapi32" fn CredReadW(TargetName: LPCWSTR, Type: DWORD, Flags: DWORD, Credential: *?PCREDENTIALW) BOOL;

pub extern "advapi32" fn CredDeleteW(TargetName: LPCWSTR, Type: DWORD, Flags: DWORD) BOOL;

pub extern "advapi32" fn CredFree(Buffer: ?*anyopaque) void;
