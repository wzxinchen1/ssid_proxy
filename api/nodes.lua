-- 文件路径: E:\桌面\ssid_proxy\api\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)

local fs = require "nixio.fs"
local json = require "luci.jsonc"
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
    for _, outbound in ipairs(v2ray_config.outbounds or {}) do
        local server = outbound.settings.servers[1]
        table.insert(nodes, {
            id = outbound.tag,
            name = outbound.tag,
            address = server.address,
            port = server.port,
            protocol = outbound.protocol,
            username = server.users[1].user,
            password = server.users[1].pass,
            status = "active"
        })
    end
    return nodes
end
function get_next_id()
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
    local new_config = v2ray_config

    -- 生成唯一的 inbound tag 和监听端口
    local inbound_tag = node.id
    local outbound_tag = node.id

    -- 添加 outbound（设置代理信息）
    table.insert(new_config.outbounds, {
        protocol = "socks",
        tag = outbound_tag,
        settings = {
            servers = {{
                address = node.address,
                port = tonumber(node.port),
                users = {{
                    user = node.username,
                    pass = node.password
                }}
            }}
        }
    })

    -- 保存并通知 v2ray
    return save_v2ray_config(new_config)
end

-- 更新节点配置（仅修改出口信息）
function update_node_in_v2ray(node_id, node)
    local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

    -- 查找并更新对应的 outbound（不修改 inbound 的端口）
    for _, outbound in ipairs(new_config.outbounds) do
        if outbound.tag == node_id then
            outbound.settings.servers[1].address = node.address
            outbound.settings.servers[1].port = tonumber(node.port)
            outbound.settings.servers[1].users[1].user = node.username
            outbound.settings.servers[1].users[1].pass = node.password
            break
        end
    end

    -- 保存并通知 v2ray
    return save_v2ray_config(new_config)
end

-- 删除节点配置
function delete_node_from_v2ray(node_id)
    local new_config = v2ray_config

    -- 移除 outbound
    for i, outbound in ipairs(new_config.outbounds) do
        if outbound.tag == node_id then
            table.remove(new_config.outbounds, i)
            break
        end
    end

    -- 保存并通知 v2ray
    return save_v2ray_config(new_config)
end
function api_nodes()
    local http = require "luci.http"
    local sys = require "luci.sys"

    local method = http.getenv("REQUEST_METHOD")
    local path_info = http.getenv("PATH_INFO") or ""

    -- 从路径中提取 nodeId
    local nodeId = nil
    local pattern = "/api/nodes/([^/]+)$"
    if path_info then
        local match = path_info:match(pattern)
        if match then
            nodeId = match
        end
    end

    -- 正确获取请求体内容
    local content = http.content()
    local data = nil

    -- 尝试解析JSON数据
    if content and #content > 0 then
        data = json.parse(content)
    end

    if method == "GET" then
        if http.cors() then
            return
        end
        local uci = require"luci.model.uci".cursor()
        local nodes = {}
        uci:foreach("ssid-proxy", "node", function(s)
            local status = "inactive"
            local name = ""
            for i, value in pairs(v2ray_config.outbounds) do
                local server = value.settings.servers[1]
                local user = server.users[1]
                if s.ip == server.address and s.password == user.pass and tostring(s.port) == tostring(server.port) and
                    s.account == user.user then
                    status = "active"
                    name = value.tag
                    break
                end
            end
            local interfaces = {}
            for index, value in pairs(v2ray_config.routing.rules) do
                if value.outboundTag == s[".name"] then
                    for inboundIndex, tag in pairs(value.inboundTag) do
                        table.insert(interfaces, uci:get("ssid-proxy", tag, "interface"))
                    end
                    break
                end
            end
            table.insert(nodes, {
                username = s.account,
                port = s.port,
                address = s.ip,
                protocol = "socks",
                status = status,
                password = s.password,
                name = name,
                id = s[".name"],
                interfaces = table.concat(interfaces, ",")
            })
        end)
        http.prepare_content("application/json")
        http.write_json({
            success = true,
            data = nodes
        })
    elseif method == "POST" then
        if http.cors() then
            return
        end
        -- 确保有有效数据
        if not data then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "Invalid JSON data"
            })
            return
        end

        data.id = get_next_id()
        -- 添加新节点
        if not add_node_to_v2ray(data) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to add node to v2ray config"
            })
            return
        end

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            id = data.id
        })
    elseif method == "PUT" then
        if http.cors() then
            return
        end
        -- 确保有有效数据
        if not nodeId and (not data or not data.id) then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "没有NodeID"
            })
            return
        end

        -- 更新节点（仅修改出口信息）
        local id = nodeId or data.id
        if not update_node_in_v2ray(id, data) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to update node in v2ray config"
            })
            return
        end

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            id = id
        })
    elseif method == "DELETE" then
        -- 确保有有效数据
        if not nodeId then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "没有NodeID"
            })
            return
        end

        -- 删除节点
        if not delete_node_from_v2ray(nodeId) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to delete node from v2ray config"
            })
            return
        end

        http.prepare_content("application/json")
        http.write_json({
            success = true
        })
    elseif method == "OPTIONS" then
        http.cors()
    else
        http.status(405, "Method Not Allowed")
        http.write_json({
            success = false,
            error = "Method not allowed: " .. method
        })
    end
end
function api_add_node_by_url()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    if luci.http.cors() then
        return
    end
    local content = http.content()
    local url = ""
    if content and #content > 0 then
        url = json.parse(content).url
    end
    local httpRequest = require("socket.http")
    local result = httpRequest.request(url)
    local nodes = json.parse(result).obj

    local uci = require"luci.model.uci".cursor()
    for i, value in pairs(nodes) do
        local found = false
        uci:foreach("ssid-proxy", "node", function(s)
            if found then
                return
            end
            if s.ip == value.ip and s.password == value.password and s.port == value.port and s.account == value.account then
                found = true
                return
            else

            end
        end)
        if not found then
            local sid = uci:section("ssid-proxy", "node")
            uci:set("ssid-proxy", sid, "ip", value.ip)
            uci:set("ssid-proxy", sid, "password", value.password)
            uci:set("ssid-proxy", sid, "port", value.port)
            uci:set("ssid-proxy", sid, "account", value.account)
            uci:commit("ssid-proxy")
        end
    end
    uci:foreach("ssid-proxy", "node", function(s)
        local found = false
        for i, value in pairs(nodes) do
            if found then
                return
            end
            if s.ip == value.ip and s.password == value.password and s.port == value.port and s.account == value.account then
                found = true
                break
            else

            end
            if not found then
                uci:delete("ssid-proxy", s.id)
            end
        end
    end)
    uci:commit("ssid-proxy")
    http.write_json({
        success = true,
        result = result
    })
end

function api_toggle_node()
    local http = require "luci.http"
    if http.cors() then
        return
    end
    local path = http.getenv("PATH_INFO") or ""
    local uci = require"luci.model.uci".cursor()
    local id = path:match("api/node/toggle/([^/]+)$")
    local node = {
        id = id,
        username = uci:get("ssid-proxy", id, "account"),
        password = uci:get("ssid-proxy", id, "password"),
        address = uci:get("ssid-proxy", id, "ip"),
        port = uci:get("ssid-proxy", id, "port")
    }
    for i, value in pairs(v2ray_config.outbounds) do
        local server = value.settings.servers[1]
        local user = server.users[1]
        if value.tag == id then
            delete_node_from_v2ray(id)
            save_v2ray_config(v2ray_config)
            luci.sys.init.start("v2ray")
            http.write_json({
                success = true
            })
            return
        end
    end
    add_node_to_v2ray(node)
    save_v2ray_config(v2ray_config)
    luci.sys.init.start("v2ray")
    http.write_json({
        success = true
    })
end
