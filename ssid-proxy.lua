-- SSID代理系统 - 主控制器
-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua
module("luci.controller.ssid-proxy.ssid-proxy", package.seeall)
-- 引入API模块
local status = require "luci.controller.ssid-proxy.api.status"
local config = require "luci.controller.ssid-proxy.api.config"
local monitor = require "luci.controller.ssid-proxy.api.monitor"
local nodes = require "luci.controller.ssid-proxy.api.nodes"
local logs = require "luci.controller.ssid-proxy.api.logs"
local http = require "luci.http"

-- 封装原有的 http.prepare_content 方法，自动添加 CORS 头
local old_prepare_content = http.prepare_content
http.prepare_content = function(self, content_type)
    -- 设置跨域头（对所有响应生效）
    http.header("Access-Control-Allow-Origin", "*")
    http.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    http.header("Access-Control-Allow-Headers", "*")

    -- 如果是 OPTIONS 预检请求，直接返回 204
    if http.getenv("REQUEST_METHOD") == "OPTIONS" then
        http.status(204, "No Content")
        http.close()
        return
    end

    -- 继续原有逻辑
    return old_prepare_content(self, content_type)
end
http.cors = function()
    -- 设置跨域头（对所有响应生效）
    http.header("Access-Control-Allow-Origin", "*")
    http.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    http.header("Access-Control-Allow-Headers", "*")

    -- 如果是 OPTIONS 预检请求，直接返回 204
    if http.getenv("REQUEST_METHOD") == "OPTIONS" then
        http.status(204, "No Content")
        http.close()
        return true
    end

    return false
end
function index()
    -- 主菜单入口
    entry({"admin", "services", "ssid-proxy"}, call("serve_index"), _("接口代理"), 60)

    -- API路由
    entry({"api", "status"}, call("api_status"), nil, 10)
    entry({"api", "config", "get"}, call("api_config"), nil, 20)
    entry({"api", "config", "get_global"}, call("api_config_get_global"), nil, 25)
    entry({"api", "config", "update_global"}, call("api_config_update_global"), nil, 30)
    entry({"api", "config", "update"}, call("api_config_update"), nil, 35)
    entry({"api", "config", "add"}, call("api_config_add"), nil, 40)
    entry({"api", "config", "toggle"}, call("api_config_toggle"), nil, 40)
    entry({"api", "config", "delete"}, call("api_config_delete"), nil, 45)
    entry({"api", "logs"}, call("api_logs"), nil, 50)
    entry({"api", "monitor"}, call("api_monitor"), nil, 60)
    entry({"api", "service", "restart"}, call("api_service_restart"), nil, 70)
    entry({"api", "service", "start"}, call("api_service_start"), nil, 80)
    entry({"api", "service", "stop"}, call("api_service_stop"), nil, 90)
    entry({"api", "service", "toggle"}, call("api_service_toggle"), nil, 100)
    entry({"api", "nodes"}, call("api_nodes"), nil, 110)
    entry({"api", "node", "add_by_url", call("api_add_node_by_url")}, nil, 110)
end

function serve_index()
    http.redirect("/luci-static/resources/ssid-proxy/index.html")
end

api_monitor = monitor.api_monitor
api_status = status.api_status
api_nodes = nodes.api_nodes
api_add_node_by_url = nodes.api_add_node_by_url
api_logs = logs.api_logs
api_config = config.get_config
api_config_get_global = config.get_global_config
api_config_update_global = config.update_global_config
api_config_add = config.add_config
api_config_delete = config.delete_config
api_config_update = config.update_config
api_config_toggle = config.toggle_config
