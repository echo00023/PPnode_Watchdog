# PPanel-node Watchdog
ppnode守护脚本

支持：

✔ Debian
✔ Ubuntu
✔ CentOS / RHEL
✔ Alpine

功能包含：

自动检测系统类型

自动创建 watchdog 守护脚本

自动后台运行

自动设置开机自启动（systemd/OpenRC/cron 均适配）

自动检查 /etc/init.d/PPanel-node 是否存在

自动生成日志目录

命令安装：wget -O install.sh https://raw.githubusercontent.com/echo00023/PPnode_Watchdog/main/install.sh && bash install.sh
