#!/bin/sh

# -----------------------------
#  PPanel-node Watchdog Installer
#  Supports: Debian/Ubuntu, CentOS, Alpine
# -----------------------------

WATCHDOG_PATH="/root/ppnode_watchdog.sh"
LOG_PATH="/root/ppnode_watchdog.log"
SERVICE_SCRIPT="/etc/init.d/PPanel-node"

echo "==== PPanel-node Watchdog Installer ===="

# -----------------------------
# 0. 检查 PPanel-node 服务脚本是否存在
# -----------------------------
if [ ! -f "$SERVICE_SCRIPT" ]; then
    echo "❌ 未找到 $SERVICE_SCRIPT"
    echo "请确认 PPanel-node 已正确安装。"
    exit 1
fi


# -----------------------------
# 1. 创建 Watchdog 脚本
# -----------------------------
cat > $WATCHDOG_PATH << 'EOF'
#!/bin/sh

SERVICE_SCRIPT="/etc/init.d/PPanel-node"

echo "PPanel-node 守护脚本已启动..."

while true
do
    if ! pgrep -f "PPanel-node" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') 检测到 PPanel-node 已停止，正在重启..." >> /root/ppnode_watchdog.log
        $SERVICE_SCRIPT start
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') PPanel-node 正常运行中..." >> /root/ppnode_watchdog.log
    fi
    sleep 10
done
EOF

chmod +x $WATCHDOG_PATH
echo "✔ 守护脚本已创建：$WATCHDOG_PATH"


# -----------------------------
# 2. 检测系统类型
# -----------------------------
OS=""
if [ -f /etc/alpine-release ]; then
    OS="alpine"
elif grep -qi "debian" /etc/os-release; then
    OS="debian"
elif grep -qi "ubuntu" /etc/os-release; then
    OS="ubuntu"
elif grep -qi "centos" /etc/os-release || grep -qi "rhel" /etc/os-release; then
    OS="centos"
else
    OS="unknown"
fi

echo "✔ 检测到系统类型：$OS"


# -----------------------------
# 3. 启动 Watchdog
# -----------------------------
nohup $WATCHDOG_PATH > $LOG_PATH 2>&1 &
echo "✔ Watchdog 已后台运行"
echo "日志路径：$LOG_PATH"


# -----------------------------
# 4. 设置开机启动
# -----------------------------
echo "正在设置开机自动启动..."

case "$OS" in
    alpine)
        mkdir -p /etc/local.d
        cat > /etc/local.d/ppnode-watchdog.start << EOF
#!/bin/sh
nohup $WATCHDOG_PATH > $LOG_PATH 2>&1 &
EOF
        chmod +x /etc/local.d/ppnode-watchdog.start
        rc-update add local
        echo "✔ Alpine 已设置开机自启动 (OpenRC)"
        ;;

    debian|ubuntu)
        # 使用 systemd 配置服务
        cat > /etc/systemd/system/ppnode-watchdog.service << EOF
[Unit]
Description=PPanel-node Watchdog

[Service]
ExecStart=$WATCHDOG_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable --now ppnode-watchdog
        echo "✔ Debian/Ubuntu 已设置 systemd 自启动"
        ;;

    centos)
        # CentOS 同样 systemd
        cat > /etc/systemd/system/ppnode-watchdog.service << EOF
[Unit]
Description=PPanel-node Watchdog

[Service]
ExecStart=$WATCHDOG_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable --now ppnode-watchdog
        echo "✔ CentOS/RHEL 已设置 systemd 自启动"
        ;;

    *)
        # 兜底方案使用 cron @reboot
        echo "@reboot nohup $WATCHDOG_PATH > $LOG_PATH 2>&1 &" >> /etc/crontab
        echo "✔ 系统未知，已使用 cron @reboot 作为启动方式"
        ;;
esac


echo ""
echo "==========================================="
echo " 🎉 PPanel-node 自动守护脚本安装完成！"
echo " - 自动检测运行状态"
echo " - 自动重启崩溃节点"
echo " - 已开启后台运行"
echo " - 已设置开机自启"
echo "==========================================="
