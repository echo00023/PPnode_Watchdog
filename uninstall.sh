#!/bin/sh

echo "==== 卸载 PPanel-node Watchdog ===="

# 停止后台脚本
pkill -f ppnode_watchdog.sh 2>/dev/null

# 删除主文件
rm -f /root/ppnode_watchdog.sh
rm -f /root/ppnode_watchdog.log

# systemd 卸载
if [ -f /etc/systemd/system/ppnode-watchdog.service ]; then
    systemctl stop ppnode-watchdog 2>/dev/null
    systemctl disable ppnode-watchdog 2>/dev/null
    rm -f /etc/systemd/system/ppnode-watchdog.service
    systemctl daemon-reload
    echo "✔ 已移除 systemd 自启服务"
fi

# OpenRC 卸载（Alpine）
if [ -f /etc/local.d/ppnode-watchdog.start ]; then
    rc-update del local 2>/dev/null
    rm -f /etc/local.d/ppnode-watchdog.start
    echo "✔ 已移除 OpenRC 自启服务"
fi

echo "✔ Watchdog 已成功卸载"
