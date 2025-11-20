#!/bin/sh

echo "==== PPanel-node Watchdog Installer ===="

WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"

# Detect start command
detect_ppnode() {
    if [ -f /etc/init.d/PPanel-node ]; then
        START_CMD="/etc/init.d/PPanel-node start"
        CHECK_CMD='pgrep -f "PPanel-node"'
        echo "✔ Alpine/CentOS legacy init detected."
    elif [ -f /usr/local/PPanel-node/ppnode ]; then
        START_CMD="/usr/local/PPanel-node/ppnode server"
        CHECK_CMD='ps aux | grep "/usr/local/PPanel-node/ppnode server" | grep -v grep'
        echo "✔ Debian/Ubuntu/CentOS NodeJS mode detected."
    else
        echo "❌ Could not find PPanel-node start script."
        exit 1
    fi

    echo "✔ Start Command: $START_CMD"
}

detect_ppnode

# Create watchdog file
cat > $WATCHDOG << EOF
#!/bin/sh

START_CMD="$START_CMD"
LOGFILE="$LOGFILE"

check_process() {
    RESULT=\$(sh -c "$CHECK_CMD")
    if [ -z "\$RESULT" ]; then
        return 1
    else
        return 0
    fi
}

while true
do
    if check_process; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点在线." >> \$LOGFILE
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点离线, 正在重启..." >> \$LOGFILE
        nohup sh -c "\$START_CMD" >> \$LOGFILE 2>&1 &
    fi
    sleep 10
done
EOF

chmod +x $WATCHDOG
echo "✔ Watchdog script created."

# Start in background
nohup $WATCHDOG > $LOGFILE 2>&1 &
echo "✔ Watchdog started in background."

# Auto start setup
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
