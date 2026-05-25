# justfile 重构计划：test-onWindows → check-onWindows

## 背景

Windows Docker 容器会话不支持 Credential Manager 的写入操作（`CMDKEY: Credentials cannot be saved from this logon session.`），导致所有 runtime 测试必然失败。

将验证策略从 **"编译 + 运行"** 改为 **"仅编译/静态检查"**，是跨平台系统级开发的标准做法（CI 阶段做编译验证，Manual/RDP 阶段做真实 runtime 测试）。

## 技术路径

1. **删除** `test-onWindows` 配方（原 `zig build test`）
2. **新建** `check-onWindows` 配方（`zig build --summary all`，仅静态编译检查）
3. 保留 `sftp-smart-sync` 内部配方不变

## 阶段目标

- [x] 删除 `test-onWindows`
- [x] 新建 `check-onWindows`（编译检查而非 runtime 测试）
- [x] `sftp-smart-sync` 保持不变