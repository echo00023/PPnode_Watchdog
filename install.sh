#!/bin/sh
# PPnode Watchdog FINAL-V7 (Alpine=OpenRC ; Debian/Ubuntu/CentOS=systemd)

LOCKFILE="/var/run/ppnode_watchdog.lock"
WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"

echo "==== PPnode Watchdog Installer (FINAL-V7) ===="

# ---------------------------
# 1. Kill old watchdog
# ---------------------------
echo "→ Cleaning old watchdog..."
pkill -f ppnode_watchdog.sh 2>/dev/null

# Remove old systemd services
rm -f /etc/systemd/system/ppnode-watchdog.service
rm -f /usr/lib/systemd/system/ppnode-watchdog.service
rm -f /lib/systemd/system/ppnode-watchdog.service
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

# Remove old OpenRC services
rm -f /etc/local.d/ppnode-watchdog.start
rc-update del local 2>/dev/null

# ---------------------------
# 2. Detect system type
# ---------------------------
OS=""
if [ -f /etc/alpine-release ]; then
    OS="alpine"
else
    OS="linux"
fi

# ---------------------------
# 3. Detect ppnode startup
# ---------------------------
if [ -f /etc/init.d/PPanel-node ]; then
    START_CMD="/etc/init.d/PPanel-node start"
elif [ -f /usr/local/PPanel-node/ppnode ]; then
    START_CMD="/usr/local/PPanel-node/ppnode server"
else
    echo "❌ 未找到 PPanel-node 启动文件"
    exit 1
fi

echo "✔ START_CMD = $START_CMD"

# ---------------------------
# 4. Create watchdog file
# ---------------------------
cat > $WATCHDOG << EOF
#!/bin/sh

LOCKFILE="/var/run/ppnode_watchdog.lock"
START_CMD="$START_CMD"
LOGFILE="$LOGFILE"

# lockfile 防止多实例
if [ -f "\$LOCKFILE" ]; then
    echo "已有 watchdog 实例运行，退出。" >> \$LOGFILE
    exit 0
fi
echo $$ > \$LOCKFILE

while true
do
    if pgrep -x ppnode >/dev/null 2>&1; then
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

# ---------------------------
# 5. Start watchdog + enable autostart
# ---------------------------
if [ "$OS" = "alpine" ]; then
    echo "→ Installing OpenRC autostart..."
    echo "#!/bin/sh" > /etc/local.d/ppnode-watchdog.start
    echo "nohup $WATCHDOG > $LOGFILE 2>&1 &" >> /etc/local.d/ppnode-watchdog.start
    chmod +x /etc/local.d/ppnode-watchdog.start
    rc-update add local

    nohup $WATCHDOG > $LOGFILE 2>&1 &
    echo "✔ Alpine OpenRC watchdog started."

else
    echo "→ Installing systemd autostart..."
    cat > /etc/systemd/system/ppnode-watchdog.service << EOF
[Unit]
Description=PPanel-node Watchdog
After=network.target

[Service]
Type=simple
ExecStart=$WATCHDOG
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now ppnode-watchdog

    echo "✔ systemd watchdog started."
fi

echo "🎉 安装完成！日志：$LOGFILE"
