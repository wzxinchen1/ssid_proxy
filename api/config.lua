-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua
module("luci.controller.ssid-proxy.api.config", package.seeall)
local M = {}

local json = require "luci.jsonc"
local fs = require "nixio.fs"
-- 读取 v2ray.config.json 文件
local v2ray_config_path = "/mnt/usb/v2ray.config.json"
local v2ray_config_content = fs.readfile(v2ray_config_path)
local v2ray_config = json.parse(v2ray_config_content)

if not v2ray_config.routing then
    v2ray_config.routing = {}
end

if not v2ray_config.routing.rules then
    v2ray_config.routing.rules = {}
end
-- 从 v2ray.config.json 中提取节点信息
function get_nodes_from_v2ray()
    local nodes = {}
    for _, inbound in ipairs(v2ray_config.inbounds or {}) do
        table.insert(nodes, inbound)
    end
    return nodes
end

-- 获取下一个可用的监听端口（从10000开始）
function get_next_listen_port()
    local port = 10000
    local nodes = get_nodes_from_v2ray()
    for _, node in ipairs(nodes) do
        local listen_port = tonumber(node.listen_port or 0)
        if listen_port >= port then
            port = listen_port + 1
        end
    end
    return port
end

local function get_next_id()
    local port = 1
    local nodes = get_nodes_from_v2ray()
    for _, node in ipairs(nodes) do
        port = port + 1
    end
    return port
end

-- 保存配置到 v2ray.config.json 并通知 v2ray 重新加载
function save_v2ray_config(new_config)
    -- 保存新配置到文件
    fs.writefile(v2ray_config_path, json.stringify(new_config, {
        indent = true
    }))

    -- 通知 v2ray 重新加载配置（不重启进程）
    os.execute("kill -SIGHUP $(pidof v2ray) 2>/dev/null")
    return true
end

-- 添加新节点到 v2ray 配置
function add_node_to_v2ray(node)
    local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

    -- 生成唯一的 inbound tag 和监听端口
    local inbound_tag = node.id
    local outbound_tag = node.id

    -- 添加 outbound（设置代理信息）
    table.insert(new_config.inbounds, {
        protocol = "dokodemo-door",
        tag = inbound_tag,
        port = node.port,
        settings = {
            network = "tcp,udp",
            followRedirect = true
        }
    })

    -- 保存并通知 v2ray
    return save_v2ray_config(new_config)
end

-- 删除节点配置
function delete_node_from_v2ray(node_id)
    local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

    -- 移除 outbound
    for i, outbound in ipairs(new_config.inbounds) do
        if outbound.tag == node_id then
            table.remove(new_config.inbounds, i)
            break
        end
    end

    -- 保存并通知 v2ray
    return save_v2ray_config(new_config)
end
-- 获取配置
function M.get_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local config = {
        configs = {}
    }

    uci:foreach("ssid-proxy", "config", function(s)
        local proxy_server = {}
        if s.proxy_server_id then
            local node = uci:get_all("ssid-proxy", s.proxy_server_id)
            if node then
                proxy_server = {
                    address = node.address or "",
                    protocol = node.protocol or "",
                    port = node.port or ""
                }
            end
        end

        table.insert(config.configs, {
            id = s[".name"],
            enabled = s.enabled or "1",
            interface = s.interface or "",
            mode = s.mode or "proxy",
            proxy_server_id = s.proxy_server_id or "",
            proxy_server = proxy_server
        })
    end)

    -- 获取可用接口
    config.interfaces = {}
    local ifaces = luci.sys.exec("ip -o link show | awk -F': ' '!/lo|^ /{print $2}' | sort | uniq")
    for iface in ifaces:gmatch("[^\n]+") do
        table.insert(config.interfaces, iface)
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = true,
        data = config
    })
end

-- 获取全局配置
function M.get_global_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end

    local global_config = uci:get_all("ssid-proxy", "global") or {}

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = true,
        data = global_config
    })
end

-- 更新全局配置
function M.update_global_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local data = http.content()
    local json = require "luci.jsonc"
    local config = json.parse(data)

    if not config then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Invalid JSON data"
        })
        return
    end

    -- 更新全局配置
    for key, value in pairs(config.global) do
        uci:set("ssid-proxy", "global", key, value)
    end

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    -- 应用配置
    text = apply_configuration()

    http.write_json({
        success = true,
        message = text
    })
end

-- 更新单个配置
function M.update_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local data = http.content()
    local json = require "luci.jsonc"
    local config = json.parse(data)

    if not config then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Invalid JSON data"
        })
        return
    end

    -- 从路径中获取ID
    local path = http.getenv("PATH_INFO") or ""
    local id = path:match("api/config/update/([^/]+)$")

    if not id then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Missing ID in path"
        })
        return
    end

    -- 检查配置是否存在
    if not uci:get("ssid-proxy", id) then
        http.status(404, "Not Found")
        http.write_json({
            error = "Config not found"
        })
        return
    end

    -- 更新配置
    for key, value in pairs(config) do
        uci:set("ssid-proxy", id, key, value)
    end

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    http.write_json({
        success = true
    })
end

-- 添加新配置
function M.add_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local data = http.content()
    local json = require "luci.jsonc"
    local config = json.parse(data)

    if not config then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Invalid JSON data"
        })
        return
    end

    -- 添加新配置
    local sid = uci:section("ssid-proxy", "config")
    uci:set("ssid-proxy", sid, "enabled", config.enabled or "1")
    uci:set("ssid-proxy", sid, "interface", config.interface or "")
    uci:set("ssid-proxy", sid, "mode", config.mode or "proxy")

    if config.mode == "proxy" and config.proxy_server_id then
        uci:set("ssid-proxy", sid, "proxy_server_id", config.proxy_server_id)
    end

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    data.id = sid
    data.port = get_next_listen_port()
    add_node_to_v2ray(data)
    http.write_json({
        success = true,
        id = sid
    })
end

-- 删除配置
function M.delete_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end

    -- 从路径中获取ID
    local path = http.getenv("PATH_INFO") or ""
    local id = path:match("api/config/delete/([^/]+)$")

    if not id then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Missing ID in path"
        })
        return
    end

    -- 检查配置是否存在
    if not uci:get("ssid-proxy", id) then
        http.status(404, "Not Found")
        http.write_json({
            error = "Config not found"
        })
        return
    end

    -- 删除配置
    uci:delete("ssid-proxy", id)

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    http.write_json({
        success = true
    })
end

return M
