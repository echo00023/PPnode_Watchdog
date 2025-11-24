#!/bin/sh
# ============================================================
# PPnode Watchdog — Uninstall Script
# ============================================================

echo "==== 卸载 PPnode Watchdog ===="

# 停止 watchdog
echo "→ 停止 watchdog..."
pkill -f ppnode_watchdog.sh 2>/dev/null

# 删除 systemd 服务（Debian/Ubuntu/CentOS）
if [ -f /etc/systemd/system/ppnode-watchdog.service ]; then
    echo "→ 清除 systemd 服务..."
    systemctl disable --now ppnode-watchdog 2>/dev/null
    rm -f /etc/systemd/system/ppnode-watchdog.service
    systemctl daemon-reload
fi

# 删除 Alpine OpenRC 启动项
if [ -f /etc/local.d/ppnode-watchdog.start ]; then
    echo "→ 清除 OpenRC 启动项..."
    rm -f /etc/local.d/ppnode-watchdog.start
    rc-update del local 2>/dev/null
fi

# 删除运行文件
echo "→ 删除运行文件..."
rm -f /root/ppnode_watchdog.sh
rm -f /var/run/ppnode_watchdog.lock
rm -f /var/run/ppnode_last_restart

# 删除日志（可选，如果不想删除注释掉）
echo "→ 删除日志文件..."
rm -f /root/ppnode_watchdog.log
rm -f /root/ppnode_watchdog_*.log.gz

echo "🎉 卸载完成！Watchdog 已彻底删除。"
