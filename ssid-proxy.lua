-- SSID代理系统 - 主控制器
-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua

module("luci.controller.ssid-proxy.ssid-proxy", package.seeall)
-- 引入API模块
local status = require "luci.controller.ssid-proxy.api.status"
local config= require "luci.controller.ssid-proxy.api.config"
local monitor = require "luci.controller.ssid-proxy.api.monitor"
local nodes= require "luci.controller.ssid-proxy.api.nodes"
local http = require "luci.http"

-- 跨域处理函数
function action_cors()
    http = nil
    http.header("Access-Control-Allow-Origin", "*")
    http.header("Access-Control-Allow-Methods", "*")
    http.header("Access-Control-Allow-Headers", "*")
    http.header("Access-Control-Max-Age", "86400")
    if http.getenv("REQUEST_METHOD") == "OPTIONS" then
        http.status(204, "No Content")
        return true
    end
    
    -- 非OPTIONS请求继续后续处理
    return false
end
function index()
    entry({"api"}, call("action_cors"), nil, 0)  -- 优先级0最高
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
    http.redirect("/luci-static/resources/ssid-proxy/index.html")
end

api_monitor = monitor.api_monitor
api_status = status.api_status
api_nodes = nodes.api_nodes
api_config = config.api_config