# PPnode Watchdog  
跨平台自动守护脚本（Debian / Ubuntu / CentOS / Alpine 全支持）  

本项目用于自动监控 **PPanel-node（PPnode）** 的运行状态，一旦进程停止或崩溃，将自动重启。

支持特性：

- 🟩 自动检测系统类型（Debian/Ubuntu/CentOS/Alpine）
- 🟦 自动识别 PPnode 启动方式  
  - Alpine 使用 `/etc/init.d/PPanel-node start`
  - Debian/Ubuntu 使用 `/usr/local/PPanel-node/ppnode server`
- 🟨 自动后台运行
- 🟧 自动开机自启（systemd / OpenRC）
- 🟫 无 PID 文件环境兼容（基于进程检测）
- 🔁 支持自动更新安装脚本
- ❌ 一键卸载脚本（uninstall.sh）

---

## 🚀 一键安装（推荐）

```bash
wget -O install.sh https://raw.githubusercontent.com/echo00023/PPnode_Watchdog/main/install.sh && chmod +x install.sh && bash install.sh
