#!/bin/sh

# SSID 代理插件安装脚本 (前后端分离版)
# 版本: 3.0
# 描述: 安装轻量级 SSID 代理插件，提供基于网络接口的代理管理功能

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 此脚本必须以 root 用户身份运行" >&2
    exit 1
fi

# 定义源目录
SRC_DIR="."

echo "========== SSID 代理插件安装开始 =========="
echo "安装时间: $(date)"

# 步骤1: 创建必要的系统目录
mkdir -p /etc/ssid-proxy
mkdir -p /usr/lib/lua/luci/controller/ssid-proxy/api
mkdir -p /www/luci-static/resources/ssid-proxy/{css,js,pages,assets}
echo "目录创建完成"

# 步骤3: 复制核心脚本
cp "$SRC_DIR/sbin/ssid-proxy" /usr/sbin/ssid-proxy
cp "$SRC_DIR/sbin/ssid-proxy-validate" /usr/sbin/ssid-proxy-validate

# 步骤4: 复制启动脚本
cp "$SRC_DIR/init.d/ssid-proxy" /etc/init.d/ssid-proxy

# 步骤5: 复制前端文件
# 主入口文件
cp "$SRC_DIR/index.html" /www/luci-static/resources/ssid-proxy/index.html

# CSS 文件
cp "$SRC_DIR/css/base.css" /www/luci-static/resources/ssid-proxy/css/base.css
cp "$SRC_DIR/css/style.css" /www/luci-static/resources/ssid-proxy/css/style.css
cp "$SRC_DIR/css/pages/config.css" /www/luci-static/resources/ssid-proxy/css/pages/config.css
cp "$SRC_DIR/css/pages/logs.css" /www/luci-static/resources/ssid-proxy/css/pages/
cp "$SRC_DIR/css/pages/monitor.css" /www/luci-static/resources/ssid-proxy/css/pages/
cp "$SRC_DIR/css/pages/status.css" /www/luci-static/resources/ssid-proxy/css/pages/status.css
cp "$SRC_DIR/css/pages/nodes.css" /www/luci-static/resources/ssid-proxy/css/pages/

# JavaScript 文件
cp "$SRC_DIR/js/utils.js" /www/luci-static/resources/ssid-proxy/js/utils.js
cp "$SRC_DIR/js/router.js" /www/luci-static/resources/ssid-proxy/js/router.js
cp "$SRC_DIR/js/global.js" /www/luci-static/resources/ssid-proxy/js/global.js
cp "$SRC_DIR/js/pages/config.js" /www/luci-static/resources/ssid-proxy/js/pages/config.js
cp "$SRC_DIR/js/pages/logs.js" /www/luci-static/resources/ssid-proxy/js/pages/
cp "$SRC_DIR/js/pages/monitor.js" /www/luci-static/resources/ssid-proxy/js/pages/
cp "$SRC_DIR/js/pages/status.js" /www/luci-static/resources/ssid-proxy/js/pages/status.js
cp "$SRC_DIR/js/pages/nodes.js" /www/luci-static/resources/ssid-proxy/js/pages/

# HTML 页面片段
cp "$SRC_DIR/pages/config.html" /www/luci-static/resources/ssid-proxy/pages/config.html
cp "$SRC_DIR/pages/logs.html" /www/luci-static/resources/ssid-proxy/pages/
cp "$SRC_DIR/pages/monitor.html" /www/luci-static/resources/ssid-proxy/pages/
cp "$SRC_DIR/pages/status.html" /www/luci-static/resources/ssid-proxy/pages/status.html
cp "$SRC_DIR/pages/nodes.html" /www/luci-static/resources/ssid-proxy/pages/

# 静态资源
cp -r "$SRC_DIR/assets/" /www/luci-static/resources/ssid-proxy/css/

# 步骤6: 复制后端 API
cp "$SRC_DIR/api/config.lua" /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua
cp "$SRC_DIR/api/nodes.lua" /usr/lib/lua/luci/controller/ssid-proxy/api/nodes.lua
cp "$SRC_DIR/api/logs.lua" /usr/lib/lua/luci/controller/ssid-proxy/api/
cp "$SRC_DIR/api/monitor.lua" /usr/lib/lua/luci/controller/ssid-proxy/api/
cp "$SRC_DIR/api/status.lua" /usr/lib/lua/luci/controller/ssid-proxy/api/

# 步骤7: 复制主控制器
cp "$SRC_DIR/ssid-proxy.lua" /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua
cp "$SRC_DIR/api/" /usr/lib/lua/luci/controller/ssid-proxy/

# 步骤8: 设置文件权限
chmod 755 /usr/sbin/ssid-proxy
chmod 755 /usr/sbin/ssid-proxy-validate
chmod 755 /etc/init.d/ssid-proxy
chmod 600 /etc/ssid-proxy/config.json
chmod 644 /etc/config/ssid-proxy
chmod 644 /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua
chmod 644 /usr/lib/lua/luci/controller/ssid-proxy/api/*.lua
find /www/luci-static/resources/ssid-proxy/ -type f -exec chmod 644 {} \;
echo "文件权限设置完成"

# 步骤9: 创建日志文件
touch /var/log/ssid-proxy.log
chmod 644 /var/log/ssid-proxy.log
echo "日志文件创建完成"

# 步骤10: 确保默认禁用
rm -f /etc/ssid-proxy/enabled

# 步骤11: 启用服务
echo ">> 步骤10: 启用服务"
/etc/init.d/ssid-proxy enable
echo "服务已启用"

# 步骤12: 启动服务（如果配置了启用）
if [ -f "/etc/ssid-proxy/enabled" ]; then
    echo "检测到已启用配置，启动服务..."
    /etc/init.d/ssid-proxy start
else
    echo "服务已安装但未启用，请在界面启用"
fi

# 安装完成
echo "========== SSID 代理插件安装完成 =========="