#!/bin/sh

echo "==== PPanel-node Watchdog Installer ===="

WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"

# -----------------------------
# 自动检测启动方式
# -----------------------------
detect_ppnode() {
    if [ -f /etc/init.d/PPanel-node ]; then
        # Alpine 或某些系统
        START_CMD="/etc/init.d/PPanel-node start"
        CHECK_CMD="pgrep -f PPanel-node"
        echo "✔ 检测到 PPanel-node 启动方式: /etc/init.d/PPanel-node"
    elif [ -f /usr/local/PPanel-node/ppnode ]; then
        # Debian/CentOS
        START_CMD="/usr/local/PPanel-node/ppnode server"
        CHECK_CMD="pgrep -f 'ppnode server'"
        echo "✔ 检测到 PPanel-node 启动方式: /usr/local/PPanel-node/ppnode server"
    else
        echo "❌ 未找到 PPanel-node 启动脚本"
        echo "请确认 PPanel-node 已成功安装。"
        exit 1
    fi
}

detect_ppnode


# -----------------------------
# 创建 Watchdog 脚本
# -----------------------------
cat > $WATCHDOG << EOF
#!/bin/sh

START_CMD="$START_CMD"
CHECK_CMD="$CHECK_CMD"

while true
do
    if ! sh -c "\$CHECK_CMD" >/dev/null 2>&1; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 检测到 PPanel-node 已停止，重启中..." >> $LOGFILE
        nohup sh -c "\$START_CMD" >> $LOGFILE 2>&1 &
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 正在运行..." >> $LOGFILE
    fi
    sleep 10
done
EOF

chmod +x $WATCHDOG
echo "✔ 已创建守护脚本: $WATCHDOG"


# -----------------------------
# 后台运行 Watchdog
# -----------------------------
nohup $WATCHDOG > $LOGFILE 2>&1 &
echo "✔ Watchdog 已在后台运行"


# -----------------------------
# 设置开机自启
# -----------------------------
if [ -f /etc/alpine-release ]; then
    # Alpine 使用 OpenRC
    cat > /etc/local.d/ppnode-watchdog.start << EOF
#!/bin/sh
nohup $WATCHDOG > $LOGFILE 2>&1 &
EOF
    chmod +x /etc/local.d/ppnode-watchdog.start
    rc-update add local
    echo "✔ 开机自启已安装 (OpenRC)"

else
    # Debian/CentOS 使用 systemd
    cat > /etc/systemd/system/ppnode-watchdog.service << EOF
[Unit]
Description=PPanel-node Watchdog
After=network.target

[Service]
ExecStart=$WATCHDOG
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now ppnode-watchdog
    echo "✔ 开机自启已安装 (systemd)"
fi


echo ""
echo "🎉 安装完成！PPanel-node Watchdog 已启动并将在后台守护运行。"
echo "日志文件: $LOGFILE"
echo ""
