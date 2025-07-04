-- 文件路径: E:\桌面\ssid_proxy\api\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)

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

    -- 读取 v2ray.config.json 文件
    local v2ray_config_path = "/mnt/usb/v2ray.config.json"
    local v2ray_config_content = fs.readfile(v2ray_config_path)
    local v2ray_config = json.parse(v2ray_config_content)

    -- 从 v2ray.config.json 中提取节点信息
    local function get_nodes_from_v2ray()
        local nodes = {}
        for _, inbound in ipairs(v2ray_config.inbounds or {}) do
            if inbound.tag then
                local outbound_tag = nil
                for _, rule in ipairs(v2ray_config.routing.rules or {}) do
                    if rule.inboundTag and rule.inboundTag[1] == inbound.tag then
                        outbound_tag = rule.outboundTag
                        break
                    end
                end
                if outbound_tag then
                    for _, outbound in ipairs(v2ray_config.outbounds or {}) do
                        if outbound.tag == outbound_tag then
                            local server = outbound.settings.servers[1]
                            table.insert(nodes, {
                                id = inbound.tag,
                                name = inbound.tag,
                                address = server.address,
                                port = server.port,
                                protocol = outbound.protocol,
                                username = server.users[1].user,
                                password = server.users[1].pass,
                                status = "active"
                            })
                            break
                        end
                    end
                end
            end
        end
        return nodes
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
        local nodes = get_nodes_from_v2ray()
        for _, node in ipairs(nodes) do
            local listen_port = tonumber(node.listen_port or 0)
            if listen_port >= port then
                port = listen_port + 1
            end
        end
        return port
    end

    -- 启动redsocks服务
    local function start_redsocks(node_id, config_file)
        local service_name = "redsocks_" .. node_id
        local status = sys.init.enabled(service_name)
        if status then
            return true
        end

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

        local service_path = "/etc/init.d/" .. service_name
        fs.writefile(service_path, service_script)
        fs.chmod(service_path, 755)

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

    -- 保存INI配置到文件
    local function save_redsocks_config(node_id, config)
        local config_file = "/etc/ssid-proxy/redsocks_" .. node_id .. ".conf"
        fs.writefile(config_file, config)
        return config_file
    end

    if method == "GET" then
        local nodes = get_nodes_from_v2ray()
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

        -- 分配监听端口并生成redsocks配置
        local listen_port = get_next_listen_port()
        local redsocks_config = generate_redsocks_config(data, listen_port)
        local config_file = save_redsocks_config(data.id, redsocks_config)

        -- 启动redsocks服务
        if not start_redsocks(data.id, config_file) then
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
            id = data.id,
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
        local listen_port = get_next_listen_port()
        local redsocks_config = generate_redsocks_config(data, listen_port)
        local config_file = save_redsocks_config(id, redsocks_config)

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

        -- 停止redsocks服务
        stop_redsocks(nodeId)

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
