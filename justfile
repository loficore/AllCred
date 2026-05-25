# 变量配置
win_port   := "2222"
win_user   := "Docker"
win_host   := "localhost"
win_target := "./workspace/project"

# 本地 Linux 测试
test:
    zig build test

# 远程 Windows 静态编译检查（方案 3）
check-onWindows: sftp-smart-sync
    @echo "▶ 正在验证 Windows 平台下的静态编译与 API 绑定合规性..."
    ssh -p {{win_port}} {{win_user}}@{{win_host}} "pwsh.exe -Command \"cd '{{win_target}}'; Remove-Item -Recurse -Force '.zig-cache' -ErrorAction SilentlyContinue; zig build --summary all\""

# 内部高效同步配方（SFTP 打包闪传）
@sftp-smart-sync:
    @echo "📦 正在本地打包代码（自动过滤缓存与版本控制目录）..."
    tar --exclude='.git' \
        --exclude='.jj' \
        --exclude='.zig-cache' \
        --exclude='zig-out' \
        -czf /tmp/project_transfer.tar.gz ./

    @echo "🚚 正在通过 SFTP 闪传单个压缩包..."
    ssh -p {{win_port}} {{win_user}}@{{win_host}} "pwsh.exe -Command \"New-Item -ItemType Directory -Path '{{win_target}}' -Force | Out-Null\""
    ( \
      echo "cd {{win_target}}"; \
      echo "put /tmp/project_transfer.tar.gz"; \
      echo "bye"; \
    ) | sftp -P {{win_port}} -b - {{win_user}}@{{win_host}}

    @echo "💥 正在远程解压并清理临时包..."
    ssh -p {{win_port}} {{win_user}}@{{win_host}} "pwsh.exe -Command \"cd '{{win_target}}'; tar -xzf project_transfer.tar.gz; Remove-Item project_transfer.tar.gz -Force\""
    rm -f /tmp/project_transfer.tar.gz