#!/bin/sh
# PPnode Watchdog FINAL-V9 (Alpine=OpenRC ; Debian/Ubuntu/CentOS=systemd)
# Author: echo00023 + ChatGPT

LOCKFILE="/var/run/ppnode_watchdog.lock"
WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"
LAST_RESTART="/var/run/ppnode_last_restart"

echo "==== PPnode Watchdog Installer (FINAL-V9) ===="

# ----------------------------------------------------
# 1. Kill old watchdog + remove old service
# ----------------------------------------------------
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
rm -f $LAST_RESTART

# ----------------------------------------------------
# 2. Detect system
# ----------------------------------------------------
OS="linux"
[ -f /etc/alpine-release ] && OS="alpine"

# ----------------------------------------------------
# 3. Detect PPnode startup / stop commands
# ----------------------------------------------------
if [ -f /etc/init.d/PPanel-node ]; then
    START_CMD="/etc/init.d/PPanel-node start"
    STOP_CMD="/etc/init.d/PPanel-node stop"
else
    START_CMD="/usr/local/PPanel-node/ppnode server"
    STOP_CMD="
pkill -9 -f '/usr/local/PPanel-node/ppnode server';
pkill -9 -f 'sh -c /usr/local/PPanel-node/ppnode server';
"
fi

echo "✔ START_CMD = $START_CMD"
echo "✔ STOP_CMD = $STOP_CMD"

# ----------------------------------------------------
# 4. Create FINAL-V9 Watchdog Script
# ----------------------------------------------------
cat > $WATCHDOG << 'EOF'
#!/bin/sh

LOCKFILE="/var/run/ppnode_watchdog.lock"
LOGFILE="/root/ppnode_watchdog.log"
LAST_RESTART="/var/run/ppnode_last_restart"

START_CMD="__START_CMD__"
STOP_CMD="__STOP_CMD__"

# 正确区分 Alpine VS Linux 检测规则
if [ -f /etc/alpine-release ]; then
    CHECK_CMD='pgrep -f "^/usr/local/PPanel-node/ppnode server"'
else
    # Debian/Ubuntu/CentOS —— 不误判 wrapper
    CHECK_CMD='ps -eo pid,comm,args | grep "ppnode " | grep "server" | grep -v "sh -c" | grep -v grep'
fi

# 防止重复实例
if [ -f "$LOCKFILE" ]; then
    exit 0
fi
echo $$ > $LOCKFILE

# 初始化强制重启计时器
if [ ! -f "$LAST_RESTART" ]; then
    date +%s > $LAST_RESTART
fi

while true
do
    # 检查是否在线
    if sh -c "$CHECK_CMD" >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点在线" >> $LOGFILE
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] 节点离线 → 重启中..." >> $LOGFILE

        # 彻底停止
        sh -c "$STOP_CMD" >> $LOGFILE 2>&1

        # 重启
        nohup sh -c "$START_CMD" >> $LOGFILE 2>&1 &
    fi

    # Alpine：每小时强制重启（可选增强）
    if [ -f /etc/alpine-release ]; then
        NOW=$(date +%s)
        LAST=$(cat $LAST_RESTART 2>/dev/null)
        [ -z "$LAST" ] && LAST=0
        DIFF=$((NOW - LAST))

        if [ $DIFF -ge 3600 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] [每小时自动重启]" >> $LOGFILE
            sh -c "$STOP_CMD" >> $LOGFILE 2>&1
            nohup sh -c "$START_CMD" >> $LOGFILE 2>&1 &
            date +%s > $LAST_RESTART
        fi
    fi

    sleep 10
done
EOF

# 插入变量（防 shell 转义问题）
sed -i "s#__START_CMD__#$START_CMD#g" $WATCHDOG
sed -i "s#__STOP_CMD__#$STOP_CMD#g" $WATCHDOG

chmod +x $WATCHDOG
echo "✔ Watchdog 脚本已创建。"

# ----------------------------------------------------
# 5. Start + Enable Autostart
# ----------------------------------------------------
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

echo "🎉 FINAL-V9 安装完成！日志路径：$LOGFILE"
