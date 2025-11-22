#!/bin/sh
# ============================================================
# PPnode Watchdog FINAL-V10.2
# - Alpine: OpenRC + 每小时自动重启
# - Debian/Ubuntu/CentOS: systemd STOP+START + 每日凌晨4点强制重启
# - 日志每日轮替 + 自动压缩 + 保留最近7天
# ============================================================

LOCKFILE="/var/run/ppnode_watchdog.lock"
WATCHDOG="/root/ppnode_watchdog.sh"
LOGFILE="/root/ppnode_watchdog.log"
LAST_RESTART="/var/run/ppnode_last_restart"
DAILY_RESTART="/var/run/ppnode_daily_restart"

echo "==== PPnode Watchdog Installer (FINAL-V10.2) ===="

# ============================================================
# 清理旧 watchdog
# ============================================================
echo "→ 清理旧 watchdog..."
pkill -f ppnode_watchdog.sh 2>/dev/null

rm -f /etc/systemd/system/ppnode-watchdog.service
rm -f /usr/lib/systemd/system/ppnode-watchdog.service
rm -f /lib/systemd/system/ppnode-watchdog.service
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

rm -f /etc/local.d/ppnode-watchdog.start
rc-update del local 2>/dev/null

rm -f "$LOCKFILE" "$LAST_RESTART" "$DAILY_RESTART"

# ============================================================
# 检测系统类型
# ============================================================
OS="linux"
[ -f /etc/alpine-release ] && OS="alpine"

# ============================================================
# 设置启动方式（不同系统）
# ============================================================
if [ "$OS" = "alpine" ]; then
    START_CMD="/etc/init.d/PPanel-node start"
    STOP_CMD="/etc/init.d/PPanel-node stop"
else
    START_CMD="systemctl start PPanel-node"
    STOP_CMD="systemctl stop PPanel-node"
fi

echo "✔ START_CMD = $START_CMD"
echo "✔ STOP_CMD = $STOP_CMD"

# ============================================================
# 生成 Watchdog（FINAL-V10.2）
# ============================================================
cat > $WATCHDOG << 'EOF'
#!/bin/sh

LOCKFILE="/var/run/ppnode_watchdog.lock"
LOGFILE="/root/ppnode_watchdog.log"
LAST_RESTART="/var/run/ppnode_last_restart"
DAILY_RESTART="/var/run/ppnode_daily_restart"

START_CMD="__START_CMD__"
STOP_CMD="__STOP_CMD__"
OS="__OS__"

# =====================================================
# 日志轮替 + 压缩 + 删除 7 天前日志
# =====================================================
rotate_log() {
    TODAY=$(date +%Y-%m-%d)
    CURRENT="/root/ppnode_watchdog.log"
    ARCHIVE="/root/ppnode_watchdog_$TODAY.log"

    if [ ! -f "$ARCHIVE.gz" ]; then
        if [ -f "$CURRENT" ]; then
            mv "$CURRENT" "$ARCHIVE"
            gzip "$ARCHIVE"
        fi
        touch "$CURRENT"
    fi

    find /root/ -maxdepth 1 -type f -name "ppnode_watchdog_*.log.gz" -mtime +7 -delete
}

# =====================================================
# 防重复实例
# =====================================================
[ -f "$LOCKFILE" ] && exit 0
echo $$ > "$LOCKFILE"

# 初始计时
[ ! -f "$LAST_RESTART" ] && date +%s > "$LAST_RESTART"
[ ! -f "$DAILY_RESTART" ] && echo "0" > "$DAILY_RESTART"

# =====================================================
# Watchdog 主循环
# =====================================================
while true
do
    rotate_log

    # =====================================================
    # Alpine：每小时强制重启
    # =====================================================
    if [ "$OS" = "alpine" ]; then
        if ! pgrep -f "^/usr/local/PPanel-node/ppnode server" >/dev/null 2>&1; then
            echo "$(date '+%F %T') [Watchdog] 离线 → 自动重启" >> "$LOGFILE"
            sh -c "$STOP_CMD" >> "$LOGFILE"
            nohup sh -c "$START_CMD" >> "$LOGFILE" &
        else
            echo "$(date '+%F %T') [Watchdog] 在线" >> "$LOGFILE"
        fi

        NOW=$(date +%s)
        LAST=$(cat "$LAST_RESTART" 2>/dev/null)
        [ $((NOW - LAST)) -ge 3600 ] && {
            echo "$(date '+%F %T') [Watchdog] 每小时自动重启" >> "$LOGFILE"
            sh -c "$STOP_CMD" >> "$LOGFILE"
            nohup sh -c "$START_CMD" >> "$LOGFILE" &
            date +%s > "$LAST_RESTART"
        }

    else
    # =====================================================
    # Debian / Ubuntu / CentOS：systemd + 每日 4 点强制重启
    # =====================================================
        if systemctl is-active --quiet PPanel-node; then
            echo "$(date '+%F %T') [Watchdog] 在线" >> "$LOGFILE"
        else
            echo "$(date '+%F %T') [Watchdog] 离线 → STOP + START" >> "$LOGFILE"
            systemctl stop PPanel-node >> "$LOGFILE"
            systemctl start PPanel-node >> "$LOGFILE"
        fi

        HOUR=$(date +%H)
        TODAY=$(date +%Y-%m-%d)
        LAST_DAY=$(cat "$DAILY_RESTART" 2>/dev/null)

        if [ "$HOUR" = "04" ] && [ "$TODAY" != "$LAST_DAY" ]; then
            echo "$(date '+%F %T') [Watchdog] 每日凌晨4点强制重启" >> "$LOGFILE"
            systemctl stop PPanel-node >> "$LOGFILE"
            systemctl start PPanel-node >> "$LOGFILE"
            echo "$TODAY" > "$DAILY_RESTART"
        fi
    fi

    sleep 10
done
EOF

# 占位符注入
sed -i "s#__START_CMD__#$START_CMD#" $WATCHDOG
sed -i "s#__STOP_CMD__#$STOP_CMD#" $WATCHDOG
sed -i "s#__OS__#$OS#" $WATCHDOG

chmod +x $WATCHDOG
echo "✔ Watchdog 脚本已生成。"

# ============================================================
# 自启动配置
# ============================================================
if [ "$OS" = "alpine" ]; then
    echo "→ 安装 OpenRC 自启动..."
    echo "#!/bin/sh" > /etc/local.d/ppnode-watchdog.start
    echo "nohup $WATCHDOG >> $LOGFILE 2>&1 &" >> /etc/local.d/ppnode-watchdog.start
    chmod +x /etc/local.d/ppnode-watchdog.start
    rc-update add local
    nohup $WATCHDOG >> $LOGFILE 2>&1 &
else
    echo "→ 安装 systemd 自启动..."
    cat > /etc/systemd/system/ppnode-watchdog.service << EOF
[Unit]
Description=PPnode Watchdog
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
fi

echo "🎉 FINAL-V10.2（含每日4点重启 + 日志增强）安装完成！日志：$LOGFILE"
