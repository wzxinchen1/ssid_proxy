-- 文件路径: E:\\桌面\\ssid_proxy\\api\\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)

function api_nodes()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local uci = require"luci.model.uci".cursor()
    local fs = require "nixio.fs"

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

    -- 生成适用于redsocks的JSON配置
    local function generate_redsocks_config(node, listen_port)
        local config = {
            base = {
                log_debug = 0,
                log_info = 1,
                daemon = 1,
                redirector = "iptables"
            },
            redsocks = {
                type = node.protocol or "socks5",
                ip = node.address,
                port = tonumber(node.port),
                login = node.username or "",
                password = node.password or "",
                local_ip = "127.0.0.1",
                local_port = listen_port
            }
        }
        return config
    end

    -- 获取下一个可用的监听端口（从10000开始）
    local function get_next_listen_port()
        local port = 10000
        uci:foreach("ssid-proxy", "node", function(s)
            local config_file = s["redsocks_config"]
            if config_file and fs.access(config_file) then
                local content = fs.readfile(config_file)
                if content then
                    local config = json.parse(content)
                    if config and config.redsocks and config.redsocks.local_port then
                        if config.redsocks.local_port >= port then
                            port = config.redsocks.local_port + 1
                        end
                    end
                end
            end
        end)
        return port
    end

    -- 保存JSON配置到文件并更新UCI配置
    local function save_redsocks_config(node_id, config)
        local json_file = "/etc/ssid-proxy/redsocks_" .. node_id .. ".json"
        local json_content = json.stringify(config, true)
        fs.writefile(json_file, json_content)
        uci:set("ssid-proxy", node_id, "redsocks_config", json_file)
        uci:commit("ssid-proxy")
    end

    if method == "GET" then
        -- 获取节点列表
        local nodes = {}
        uci:foreach("ssid-proxy", "node", function(s)
            table.insert(nodes, {
                id = s[".name"],
                name = s["name"],
                address = s["address"],
                port = s["port"],
                protocol = s["protocol"],
                username = s["username"],
                password = s["password"],
                status = s["status"] or "inactive"
            })
        end)

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            data = nodes
        })
    elseif method == "POST" then
        -- 确保有有效数据
        if not data then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "Invalid JSON data"
            })
            return
        end

        -- 添加或更新节点
        local id = data.id or uci:add("ssid-proxy", "node")
        uci:set("ssid-proxy", id, "name", data.name)
        uci:set("ssid-proxy", id, "address", data.address)
        uci:set("ssid-proxy", id, "port", data.port)
        uci:set("ssid-proxy", id, "protocol", data.protocol)
        uci:set("ssid-proxy", id, "username", data.username)
        uci:set("ssid-proxy", id, "password", data.password)
        uci:set("ssid-proxy", id, "status", data.status)

        -- 分配监听端口并生成redsocks配置
        if not data.id then
            local listen_port = get_next_listen_port()
            local redsocks_config = generate_redsocks_config(data, listen_port)
            save_redsocks_config(id, redsocks_config)
            uci:set("ssid-proxy", id, "listen_port", listen_port)
        end
        http.prepare_content("application/json")
        http.write_json({
            success = true,
            id = id,
            listen_port = listen_port
        })
    elseif method == "PUT" then
        -- 确保有有效数据
        if not nodeId and (not data or not data.id) then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "没有NodeID"
            })
            return
        end

        -- 更新节点
        local id = nodeId or data.id
        uci:set("ssid-proxy", id, "name", data.name)
        uci:set("ssid-proxy", id, "address", data.address)
        uci:set("ssid-proxy", id, "port", data.port)
        uci:set("ssid-proxy", id, "protocol", data.protocol)
        uci:set("ssid-proxy", id, "username", data.username)
        uci:set("ssid-proxy", id, "password", data.password)
        uci:set("ssid-proxy", id, "status", data.status)

        -- 如果节点已有监听端口，则复用；否则分配新的
        local listen_port = uci:get("ssid-proxy", id, "listen_port") or get_next_listen_port()
        local redsocks_config = generate_redsocks_config(data, listen_port)
        save_redsocks_config(id, redsocks_config)
        uci:set("ssid-proxy", id, "listen_port", listen_port)

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            id = id,
            listen_port = listen_port
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

        -- 检查节点是否存在
        if not uci:get("ssid-proxy", nodeId) then
            http.status(404, "Not Found")
            http.write_json({
                success = false,
                error = "节点不存在" + nodeId
            })
            return
        end

        -- 删除节点
        uci:delete("ssid-proxy", nodeId)
        if not uci:commit("ssid-proxy") then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "删除失败"
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
