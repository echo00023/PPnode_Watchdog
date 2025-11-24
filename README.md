# PPnode Watchdog

PPnode Watchdog 是一个跨 Linux 发行版的 **轻量级守护进程**，用于：

- 监控 PPanel-node（PPnode）是否正常运行  
- 离线自动重启  
- **每小时强制重启一次（防止 Xray/SS 内存泄露）**  
- 日志自动每日轮替 + 自动压缩  
- 仅保留最近 7 天日志  
- 兼容 Alpine / Debian / Ubuntu / CentOS  

支持的系统：
- Alpine Linux（OpenRC）
- Debian 8+
- Ubuntu 16+
- CentOS 7+
- Rocky / Alma / Oracle Linux

---

## ✨ 功能列表

| 功能 | 说明 |
|------|------|
| 进程监控 | 检测 PPnode 是否离线 |
| 自动重启 | 离线立即重启 |
| **每小时自动重启** | Alpine / Debian / Ubuntu / CentOS 全统一 |
| 日志轮替 | 每天自动切割日志，gzip 压缩 |
| 自动清理 | 自动删除 7 天以前日志 |
| 防多实例运行 | 使用 lockfile |
| 开机自启 | systemd / OpenRC 自适应 |

---

## 📦 安装 Watchdog

```bash
wget -O install.sh https://raw.githubusercontent.com/echo00023/PPnode_Watchdog/main/install.sh && chmod +x install.sh && bash install.sh

