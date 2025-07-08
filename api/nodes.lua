-- 文件路径: E:\桌面\ssid_proxy\api\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)


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
local function get_nodes_from_v2ray()
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
local function get_next_id()
    local port = 1
    local nodes = get_nodes_from_v2ray()
    for _, node in ipairs(nodes) do
        port = port + 1
    end
    return port
end

-- 保存配置到 v2ray.config.json 并通知 v2ray 重新加载
local function save_v2ray_config(new_config)
    -- 保存新配置到文件
    fs.writefile(v2ray_config_path, json.stringify(new_config, {
        indent = true
    }))

    -- 通知 v2ray 重新加载配置（不重启进程）
    os.execute("kill -SIGHUP $(pidof v2ray) 2>/dev/null")
    return true
end

-- 添加新节点到 v2ray 配置
local function add_node_to_v2ray(node)
    local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

    -- 生成唯一的 inbound tag 和监听端口
    local inbound_tag = "inbound_" .. node.id
    local outbound_tag = "outbound_" .. node.id

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
local function update_node_in_v2ray(node_id, node)
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
local function delete_node_from_v2ray(node_id)
    local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

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
function api_add_node_by_url()
    local http = require "luci.http"
    if luci.http.cors() then
        return
    end
    http.write_json({
        success = true
    })
end

function api_nodes()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local fs = require "nixio.fs"
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
        local nodes={}

        uci:foreach("ssid-proxy", "node", function(s)
            table.insert(config.configs, {
                id = s[".name"],
                enabled = s.enabled or "1",
                interface = s.interface or "",
                mode = s.mode or "proxy",
                proxy_server_id = s.proxy_server_id or ""
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


function M.toggle_node()
    local http = require "luci.http"
    if luci.http.cors() then
        return
    end
    local path = http.getenv("PATH_INFO") or ""
    local uci = require"luci.model.uci".cursor()
    local id = path:match("api/config/node/([^/]+)$")
    local http = require "luci.http"
    local enabled = uci:get("ssid-proxy", id, "enabled")
    local port = uci:get("ssid-proxy", id, "port")
    local interface = uci:get("ssid-proxy", id, "interface")
    if enabled == "0" then
        enabled = " 1"
        local cmd = "iptables -t nat -A PREROUTING -i " .. interface .. " -p tcp -j REDIRECT --to-port " .. port
        success, exit_code, exit_signal = os.execute(cmd)
        cmd = "iptables -t nat -A PREROUTING -i " .. interface .. " -p udp -j REDIRECT --to-port " .. port
        success, exit_code, exit_signal = os.execute(cmd)
    else
        enabled = "0"
        local cmd = "iptables -t nat -D PREROUTING -i " .. interface .. " -p tcp -j REDIRECT --to-port " .. port
        success, exit_code, exit_signal = os.execute(cmd)
        success, exit_code, exit_signal = os.execute(cmd)
        cmd = "iptables -t nat -D PREROUTING -i " .. interface .. " -p udp -j REDIRECT --to-port " .. port
        success, exit_code, exit_signal = os.execute(cmd)
        success, exit_code, exit_signal = os.execute(cmd)
    end

    uci:set("ssid-proxy", id, "enabled", enabled)
    uci:commit("ssid-proxy")
    local handle = io.popen("iptables -t nat -L -v -n | grep " .. interface)
    local result = handle:read("*a") -- 读取所有输出
    handle:close()
    if result and result ~= "" then
        enabled = "1"
    else
        enabled = "0"
    end
    http.write_json({
        success = true,
        enabled = enabled,
        id = id
    })
end