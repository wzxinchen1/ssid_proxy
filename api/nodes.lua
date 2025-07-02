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
    log_debug = on;
    log_info = on;
    daemon = on;
    redirector = iptables;
    log = "file:/mnt/usb1/redsocks_log/%s";
}

redsocks {
    type = socks5;
    ip = %s;
    port = %d;
    login = "%s";
    password = "%s";
    local_ip = 0.0.0.0;
    local_port = %d;
}
]], node.id, node.address, tonumber(node.port), node.username or "", node.password or "", listen_port)
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

    -- 启动redsocks服务
    local function start_redsocks(node_id, config_file)
        -- 检查是否已存在redsocks服务
        local service_name = "redsocks_" .. node_id
        local status = sys.init.enabled(service_name)
        if status then
            -- 服务已在运行，无需重启
            return true
        end

        -- 创建服务脚本
        local service_script = string.format([[
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    touch /var/run/redsocks_%s.pid
    /usr/sbin/redsocks -c %s -p /var/run/redsocks_%s.pid
}

stop() {
    kill -9 $(cat /var/run/redsocks_%s.pid)
    rm -f /var/run/redsocks_%s.pid
}
]], node_id, config_file, node_id, node_id, node_id)

        -- 写入服务脚本
        local service_path = "/etc/init.d/" .. service_name
        fs.writefile(service_path, service_script)
        fs.chmod(service_path, 755)

        -- 启用并启动服务
        sys.init.enable(service_name)
        sys.init.start(service_name)
        return true
    end

    -- 停止redsocks服务
    local function stop_redsocks(node_id)
        local service_name = "redsocks_" .. node_id
        if sys.init.enabled(service_name) then
            sys.init.stop(service_name)
            sys.init.disable(service_name)
            fs.unlink("/etc/init.d/" .. service_name)
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

        -- 启动redsocks服务
        if not start_redsocks(id, config_file) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to start redsocks service"
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
        http.prepare_content("application/json")
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
        data.id = id

        -- 如果节点已有监听端口，则复用；否则分配新的
        local listen_port = uci:get("ssid-proxy", id, "listen_port") or get_next_listen_port()
        local redsocks_config = generate_redsocks_config(data, listen_port)
        local config_file = save_redsocks_config(id, redsocks_config)
        uci:set("ssid-proxy", id, "listen_port", listen_port)

        -- 重启redsocks服务
        stop_redsocks(id)
        if not start_redsocks(id, config_file) then
            http.status(500, "Internal Server Error")
            http.write_json({
                success = false,
                error = "Failed to restart redsocks service"
            })
            return
        end

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

        -- 检查节点是否存在
        if not uci:get("ssid-proxy", nodeId) then
            http.status(404, "Not Found")
            http.write_json({
                success = false,
                error = "节点不存在" + nodeId
            })
            return
        end

        -- 停止redsocks服务
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
