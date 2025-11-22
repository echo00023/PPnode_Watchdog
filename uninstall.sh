#!/bin/sh
# PPnode Watchdog Uninstaller (FINAL-V10)

WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"
LOCKFILE="/var/run/ppnode_watchdog.lock"
LAST_RESTART="/var/run/ppnode_last_restart"

echo "==== 卸载 PPnode Watchdog (FINAL-V10) ===="

# ---------------------------
# Stop running watchdog
# ---------------------------
echo "→ 停止 Watchdog..."
pkill -f ppnode_watchdog.sh 2>/dev/null

# ---------------------------
# Remove systemd part
# ---------------------------
if [ -f /etc/systemd/system/ppnode-watchdog.service ]; then
    echo "→ 移除 systemd 服务..."
    systemctl stop ppnode-watchdog 2>/dev/null
    systemctl disable ppnode-watchdog 2>/dev/null
    rm -f /etc/systemd/system/ppnode-watchdog.service
    systemctl daemon-reload
    systemctl reset-failed
fi

# ---------------------------
# Remove Alpine OpenRC hooks
# ---------------------------
if [ -f /etc/alpine-release ]; then
    echo "→ 移除 Alpine OpenRC 自启..."
    rc-update del local 2>/dev/null
    rm -f /etc/local.d/ppnode-watchdog.start
fi

# ---------------------------
# Clean files
# ---------------------------
echo "→ 清理文件..."
rm -f "$WATCHDOG"
rm -f "$LOGFILE"
rm -f "$LOCKFILE"
rm -f "$LAST_RESTART"

echo "✔ PPnode Watchdog 已完全卸载。"
echo "（PPnode 本体未受影响，需要可使用 ppnode 命令继续管理）"
