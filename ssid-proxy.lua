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

    entry({"api"}, call("handle_api"), nil, 0)
    -- -- API路由
    -- entry({"api", "status"}, call("get_interface_status"), nil, 15)
    -- entry({"api", "status", "clients"}, call("get_game_clients"), nil, 15)
    -- entry({"api", "config", "get"}, call("api_config"), nil, 20)
    -- entry({"api", "config", "get_global"}, call("api_config_get_global"), nil, 25)
    -- entry({"api", "config", "update_global"}, call("api_config_update_global"), nil, 30)
    -- entry({"api", "config", "update"}, call("api_config_update"), nil, 35)
    -- entry({"api", "config", "add"}, call("api_config_add"), nil, 40)
    -- entry({"api", "config", "toggle"}, call("api_config_toggle"), nil, 40)
    -- entry({"api", "config", "delete"}, call("api_config_delete"), nil, 45)
    -- entry({"api", "logs"}, call("api_logs"), nil, 50)
    -- entry({"api", "monitor"}, call("api_monitor"), nil, 60)
    -- entry({"api", "service", "restart"}, call("api_service_restart"), nil, 70)
    -- entry({"api", "service", "start"}, call("api_service_start"), nil, 80)
    -- entry({"api", "service", "stop"}, call("api_service_stop"), nil, 90)
    -- entry({"api", "service", "toggle"}, call("api_service_toggle"), nil, 100)
    -- entry({"api", "nodes"}, call("api_nodes"), nil, 110)
    -- entry({"api", "node", "available"}, call("available_nodes"), nil, 110)
    -- entry({"api", "node", "add_by_url"}, call("api_add_node_by_url"), nil, 120)
    -- entry({"api", "node", "toggle"}, call("api_toggle_node"), nil, 120)
end
function handle_api()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local dispatcher = require "luci.dispatcher"

    -- 获取请求方法和路径
    local method = string.lower(http.getenv("REQUEST_METHOD"))
    local path = http.getenv("PATH_INFO")

    -- 解析路径，格式为 /api/<controller>/<action>
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    if #parts < 2 then
        http.status(400, "Bad Request")
        http.prepare_content("application/json")
        http.write(json.stringify({
            status = "error",
            message = "Invalid API path"
        }))
        return
    end

    local controller_name = parts[2]
    local action_name = parts[3] or "Index"
    -- 动态加载 controller
    local controller, err = load_controller(controller_name)
    if not controller then
        http.prepare_content("application/json")
        http.write(json.stringify({
            status = "error",
            message = "Controller not found: " .. err
        }))
        return
    end

    -- 检查请求方法是否支持
    local method_table = controller[method]
    local query = http.getenv("QUERY_STRING")
    if not method_table then
        http.status(405, "Method Not Allowed")
        http.prepare_content("application/json")
        http.write(json.stringify({
            status = "error",
            message = "Method not allowed"
        }))
        return
    end

    -- 检查 action 是否存在
    local action = method_table[action_name]
    if not action then
        http.prepare_content("application/json")
        http.write(json.stringify({
            status = "error",
            message = "Action not found " .. action_name,
            method_table = method_table
        }))
        return
    end
    -- 处理无参数路由（直接调用函数）
    if type(action) == "function" then
        local ok, response = pcall(action)
        if not ok then
            return json_error(500, response)
        end
        return json_response(response)
    end

    -- 处理带参数路由（通过 path 模板）
    if type(action) == "table" then
        local handler = action[1]
        local path_template = action.path

        -- 从路径提取参数
        local args = {}
        if path_template then
            args = extract_path_params(path_template, path)
            http.write_json(args)
            return
        end

        -- 从查询字符串提取参数（GET/DELETE）
        if method == "GET" or method == "DELETE" then
            if query then
                for key, value in query:gmatch("([^&=]+)=([^&=]+)") do
                    args[key] = value
                end
            end
        end

        -- 从 Body 提取参数（POST/PUT）
        if method == "POST" or method == "PUT" then
            local content_type = http.getenv("CONTENT_TYPE")
            if content_type and content_type:find("application/json") then
                local data = http.read()
                if data and #data > 0 then
                    local body_params = json.parse(data) or {}
                    for k, v in pairs(body_params) do
                        args[k] = v
                    end
                end
            end
        end

        -- 调用处理函数
        local ok, response
        if path_template then
            -- 按 path 定义的顺序传递参数
            local param_order = {}
            for param in path_template:gmatch("{(.-)}") do
                table.insert(param_order, param)
            end
            local call_args = {}
            for _, param in ipairs(param_order) do
                table.insert(call_args, args[param])
            end
            ok, response = pcall(handler, unpack(call_args))
        else
            -- 无 path 模板，直接调用
            ok, response = pcall(handler)
        end

        if not ok then
            return json_error(500, response)
        end
        return json_response(response)
    end

    return json_error(400, "Invalid action type")
end

function extract_path_params(template, path)
    local params = {}
    -- 分割模板和路径为部分
    local template_parts = {}
    for part in template:gmatch("[^/]+") do
        if part ~= "{controller}" and part ~= "{action}" then
            table.insert(template_parts, part)
        end
    end
    local path_parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(path_parts, part)
    end

    -- 提取动态参数
    for i, part in ipairs(template_parts) do
        if part:match("^{.+}$") then
            local param_name = part:sub(2, -2)  -- 去掉花括号
            params[param_name] = path_parts[i]
        end
    end

    return params
end

-- 返回 JSON 响应
function json_response(data)
    local http = require "luci.http"
    http.prepare_content("application/json")
    http.write_json(data or {})
end

-- 返回 JSON 错误
function json_error(code, message)
    local http = require "luci.http"
    http.status(code, message)
    http.prepare_content("application/json")
    http.write_json({
        status = "error",
        message = message
    })
end
function load_controller(name)
    local ok, controller = pcall(require, "luci.controller.ssid-proxy.api." .. name)
    if not ok then
        return nil, "Failed to load controller: " .. controller
    end
    return controller
end
function serve_index()
    http.redirect("/luci-static/resources/ssid-proxy/index.html")
end

api_monitor = monitor.api_monitor
get_interface_status = status.get_interface_status
get_game_clients = status.get_game_clients
api_nodes = nodes.api_nodes
available_nodes = nodes.available_nodes
api_add_node_by_url = nodes.api_add_node_by_url
api_logs = logs.api_logs
api_config = config.get_config
api_config_get_global = config.get_global_config
api_config_update_global = config.update_global_config
api_config_add = config.add_config
api_config_delete = config.delete_config
api_config_update = config.update_config
api_config_toggle = config.toggle_config
api_toggle_node = nodes.api_toggle_node
