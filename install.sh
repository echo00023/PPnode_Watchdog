#!/bin/sh

echo "==== PPanel-node Watchdog Installer ===="

WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"

# 清理残留实例
pkill -f ppnode_watchdog.sh 2>/dev/null

# Detect PPnode startup mode
if [ -f /etc/init.d/PPanel-node ]; then
    START_CMD="/etc/init.d/PPanel-node start"
    CHECK_CMD='pgrep -f "^/usr/local/PPanel-node/ppnode"'
    echo "✔ Alpine mode detected."
elif [ -f /usr/local/PPanel-node/ppnode ]; then
    START_CMD="/usr/local/PPanel-node/ppnode server"
    CHECK_CMD='pgrep -f "^/usr/local/PPanel-node/ppnode"'
    echo "✔ Debian/Ubuntu/CentOS Node mode detected."
else
    echo "❌ 未找到 PPanel-node 启动文件"
    exit 1
fi

echo "✔ Start Command: $START_CMD"

# Create watchdog script
cat > $WATCHDOG << EOF
#!/bin/sh

START_CMD="$START_CMD"
LOGFILE="$LOGFILE"

check_ppnode() {
    if pgrep -f "^/usr/local/PPanel-node/ppnode" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

while true
do
    if check_ppnode; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点在线." >> \$LOGFILE
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点离线，正在重启..." >> \$LOGFILE
        nohup sh -c "\$START_CMD" >> \$LOGFILE 2>&1 &
    fi
    sleep 10
done
EOF

chmod +x $WATCHDOG
echo "✔ Watchdog script created."

# Start watchdog
nohup $WATCHDOG > $LOGFILE 2>&1 &
echo "✔ Watchdog started."

# Enable autostart
if [ -f /etc/alpine-release ]; then
    echo "#!/bin/sh" > /etc/local.d/ppnode-watchdog.start
    echo "nohup $WATCHDOG > $LOGFILE 2>&1 &" >> /etc/local.d/ppnode-watchdog.start
    chmod +x /etc/local.d/ppnode-watchdog.start
    rc-update add local
    echo "✔ OpenRC autostart enabled."
else
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
    echo "✔ systemd autostart enabled."
fi

echo "🎉 完成！日志：$LOGFILE"
