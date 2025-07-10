-- /usr/lib/lua/luci/controller/api.lua
module("luci.controller.api", package.seeall)

function index()
    entry({"api"}, call("handle_api"), nil, 10)
end

function handle_api()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local dispatcher = require "luci.dispatcher"

    -- 获取请求方法和路径
    local method = http.getenv("REQUEST_METHOD")
    local path = http.getenv("PATH_INFO")

    -- 解析路径，格式为 /api/<controller>/<action>
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    if #parts < 3 then
        http.status(400, "Bad Request")
        http.prepare_content("application/json")
        http.write(json.stringify({ status = "error", message = "Invalid API path" }))
        return
    end

    local controller_name = parts[2]
    local action = parts[3]

    -- 动态加载 controller
    local controller, err = load_controller(controller_name)
    if not controller then
        http.status(404, "Not Found")
        http.prepare_content("application/json")
        http.write(json.stringify({ status = "error", message = "Controller not found: " .. err }))
        return
    end

    -- 检查 action 是否存在
    local handler = controller[action]
    if not handler then
        http.status(404, "Not Found")
        http.prepare_content("application/json")
        http.write(json.stringify({ status = "error", message = "Action not found" }))
        return
    end

    -- 执行处理函数
    local ok, response = pcall(handler)
    if not ok then
        http.status(500, "Internal Server Error")
        http.prepare_content("application/json")
        http.write(json.stringify({ status = "error", message = response }))
        return
    end

    -- 返回响应
    http.prepare_content("application/json")
    http.write(json.stringify(response))
end

-- 动态加载 controller 模块
function load_controller(name)
    local ok, controller = pcall(require, "luci.controller.api." .. name)
    if not ok then
        return nil, "Failed to load controller: " .. controller
    end
    return controller
end
