-- 文件路径: E:\\桌面\\ssid_proxy\\api\\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)

function api_nodes()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local uci = require"luci.model.uci".cursor()
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

    -- 生成适用于redsocks的INI格式配置
    local function generate_redsocks_config(node, listen_port)
        local config = string.format([[
base {
    log_debug = 0;
    log_info = 1;
    daemon = 1;
    redirector = iptables;
}

redsocks {
    type = %s;
    ip = %s;
    port = %d;
    login = "%s";
    password = "%s";
    local_ip = 0.0.0.0;
    local_port = %d;
}
]],
            node.protocol or "socks5",
            node.address,
            tonumber(node.port),
            node.username or "",
            node.password or "",
            listen_port
        )
        return config
    end

    -- 获取下一个可用的监听端口（从10000开始）
    local function get_next_listen_port()
        local port = 10000
        uci:foreach("ssid-proxy", "node", function(s)
            local listen_port = tonumber(s["listen_port"] or 0)
            if listen_port >= port then
                port = listen_port + 1
            end
        end)
        return port
    end

    -- 启动redsocks实例
    local function start_redsocks(node_id, config_file)
        -- 检查是否已存在redsocks实例
        local pid_file = "/var/run/redsocks_" .. node_id .. ".pid"
        if fs.access(pid_file) then
            local pid = tonumber(fs.readfile(pid_file))
            if pid and sys.process.signal(pid, 0) then
                -- 实例已在运行，无需重启
                return true
            end
        end

        -- 启动新的redsocks实例
        local cmd = string.format("redsocks -c %s -p %s", config_file, pid_file)
        local pid = sys.process.exec(cmd)
        if pid then
            fs.writefile(pid_file, tostring(pid))
            return true
        else
            return false
        end
    end

    -- 停止redsocks实例
    local function stop_redsocks(node_id)
        local pid_file = "/var/run/redsocks_" .. node_id .. ".pid"
        if fs.access(pid_file) then
            local pid = tonumber(fs.readfile(pid_file))
            if pid then
                sys.process.signal(pid, 9) -- SIGKILL
                fs.unlink(pid_file)
            end
        end
    end

    -- 保存INI配置到文件并更新UCI配置
    local function save_redsocks_config(node_id, config)
        local config_file = "/etc/ssid-proxy/redsocks_" .. node_id .. ".conf"
        fs.writefile(config_file, config)
        uci:set("ssid-proxy", node_id, "redsocks_config", config_file)
        uci:commit("ssid-proxy")
        return config_file
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
        local listen_port = get_next_listen_port()
        local redsocks_config = generate_redsocks_config(data, listen_port)
        local config_file = save_redsocks_config(id, redsocks_config)
        uci:set("ssid-proxy", id, "listen_port", listen_port)

        -- 启动redsocks实例
        if not start_redsocks(id, config_file) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to start redsocks"
            })
            return
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
        local config_file = save_redsocks_config(id, redsocks_config)
        uci:set("ssid-proxy", id, "listen_port", listen_port)

        -- 重启redsocks实例
        stop_redsocks(id)
        if not start_redsocks(id, config_file) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to restart redsocks"
            })
            return
        end

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

        -- 停止redsocks实例
        stop_redsocks(nodeId)

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
