#!/bin/sh
# PPnode Watchdog FINAL-V8 (Alpine=OpenRC ; Debian/Ubuntu/CentOS=systemd)
# Author: echo00023 + ChatGPT 修改版

LOCKFILE="/var/run/ppnode_watchdog.lock"
WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"
PPNODE_BIN="/usr/local/PPanel-node/ppnode"

echo "==== PPnode Watchdog Installer (FINAL-V8 Modified) ===="

# ---------------------------
# 1. Kill old watchdog + remove old service
# ---------------------------
echo "→ 清理旧 watchdog..."
pkill -f ppnode_watchdog.sh 2>/dev/null

rm -f /etc/systemd/system/ppnode-watchdog.service
rm -f /usr/lib/systemd/system/ppnode-watchdog.service
rm -f /lib/systemd/system/ppnode-watchdog.service
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

rm -f /etc/local.d/ppnode-watchdog.start
rc-update del local 2>/dev/null

rm -f $LOCKFILE

# ---------------------------
# 2. Detect system
# ---------------------------
OS="linux"
[ -f /etc/alpine-release ] && OS="alpine"

# ---------------------------
# 3. Detect startup command & stop command
# ---------------------------
if [ -f /etc/init.d/PPanel-node ]; then
    START_CMD="/etc/init.d/PPanel-node start"
    STOP_CMD="/etc/init.d/PPanel-node stop"
else
    START_CMD="/usr/local/PPanel-node/ppnode server"
    STOP_CMD="pkill -f '/usr/local/PPanel-node/ppnode server'"
fi

echo "✔ START_CMD = $START_CMD"
echo "✔ STOP_CMD = $STOP_CMD"

# ---------------------------
# 4. Create FINAL-V8 watchdog script
# ---------------------------
cat > $WATCHDOG << EOF
#!/bin/sh

LOCKFILE="/var/run/ppnode_watchdog.lock"
START_CMD="$START_CMD"
STOP_CMD="$STOP_CMD"
LOGFILE="$LOGFILE"

CHECK_CMD='pgrep -f "^/usr/local/PPanel-node/ppnode server"'

# 锁文件防止多实例运行
if [ -f "\$LOCKFILE" ]; then
    exit 0
fi
echo \$\$ > \$LOCKFILE

while true
do
    if sh -c "\$CHECK_CMD" >/dev/null 2>&1; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] [translate:节点在线]" >> \$LOGFILE
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] [translate:节点离线，正在重启...]" >> \$LOGFILE
        # 先停止，确保进程结束
        sh -c "\$STOP_CMD" >> \$LOGFILE 2>&1
        # 再启动
        nohup sh -c "\$START_CMD" >> \$LOGFILE 2>&1 &
    fi
    sleep 10
done
EOF

chmod +x $WATCHDOG
echo "✔ Watchdog 脚本已创建。"

# ---------------------------
# 5. Start + Autostart
# ---------------------------
if [ "$OS" = "alpine" ]; then
    echo "→ 安装 OpenRC 自启动..."
    echo "#!/bin/sh" > /etc/local.d/ppnode-watchdog.start
    echo "nohup $WATCHDOG > $LOGFILE 2>&1 &" >> /etc/local.d/ppnode-watchdog.start
    chmod +x /etc/local.d/ppnode-watchdog.start
    rc-update add local

    nohup $WATCHDOG > $LOGFILE 2>&1 &
    echo "✔ Alpine watchdog 已启动。"

else
    echo "→ 安装 systemd 自启动..."
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
    echo "✔ systemd watchdog 已启动。"
fi

echo "🎉 FINAL-V8 修改版 安装完成！日志路径：$LOGFILE"
