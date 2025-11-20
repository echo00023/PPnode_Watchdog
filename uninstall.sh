#!/bin/sh
echo "==== 卸载 PPnode Watchdog FINAL-V7 ===="

pkill -f ppnode_watchdog.sh 2>/dev/null
rm -f /root/ppnode_watchdog.sh
rm -f /root/ppnode_watchdog.log
rm -f /var/run/ppnode_watchdog.lock

# Remove systemd
rm -f /etc/systemd/system/ppnode-watchdog.service
rm -f /usr/lib/systemd/system/ppnode-watchdog.service
rm -f /lib/systemd/system/ppnode-watchdog.service
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

# Remove OpenRC
rc-update del local 2>/dev/null
rm -f /etc/local.d/ppnode-watchdog.start

echo "✔ Watchdog 已彻底卸载"
