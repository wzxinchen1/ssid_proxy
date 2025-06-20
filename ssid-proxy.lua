-- SSID代理系统 - 主控制器
-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua

module("luci.controller.ssid-proxy.ssid-proxy", package.seeall)
-- 引入API模块
local status = require "luci.controller.ssid-proxy.api.status"
local config= require "luci.controller.ssid-proxy.api.config"
local monitor = require "luci.controller.ssid-proxy.api.monitor"
local nodes= require "luci.controller.ssid-proxy.api.nodes"

function index()
    -- 主菜单入口
    entry({"admin", "services", "ssid-proxy"}, call("serve_index"), _("接口代理"), 60)
    
    -- API路由
    entry({"api", "status"}, call("api_status"), nil, 10)
    entry({"api", "config"}, call("api_config"), nil, 20)
    entry({"api", "logs"}, call("api_logs"), nil, 30)
    entry({"api", "monitor"}, call("api_monitor"), nil, 40)
    entry({"api", "service", "restart"}, call("api_service_restart"), nil, 50)
    entry({"api", "service", "start"}, call("api_service_start"), nil, 60)
    entry({"api", "service", "stop"}, call("api_service_stop"), nil, 70)
    entry({"api", "service", "toggle"}, call("api_service_toggle"), nil, 80)
    entry({"api", "nodes"}, call("api_nodes"), nil, 90)
end

function serve_index()
    local http = require "luci.http"
    http.redirect("/luci-static/resources/ssid-proxy/index.html")
end

api_monitor = monitor.api_monitor
api_status = status.api_status
api_nodes = nodes.api_nodes
api_config = config.api_config