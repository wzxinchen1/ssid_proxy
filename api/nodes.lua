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

    -- 保存配置到 v2ray.config.json 并通知 v2ray 重新加载
    local function save_v2ray_config(new_config)
        -- 保存新配置到文件
        fs.writefile(v2ray_config_path, json.stringify(new_config, { indent = true }))

        -- 通知 v2ray 重新加载配置（不重启进程）
        os.execute("kill -SIGHUP $(pidof v2ray) 2>/dev/null")
        return true
    end

    -- 添加新节点到 v2ray 配置
    local function add_node_to_v2ray(node)
        local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

        -- 生成唯一的 inbound tag
        local inbound_tag = "inbound_" .. node.id
        local outbound_tag = "outbound_" .. node.id

        -- 添加 inbound
        table.insert(new_config.inbounds, {
            port = tonumber(node.port),
            protocol = "dokodemo-door",
            tag = inbound_tag,
            settings = {
                network = "tcp,udp",
                followRedirect = true
            }
        })

        -- 添加 outbound
        table.insert(new_config.outbounds, {
            protocol = "socks",
            tag = outbound_tag,
            settings = {
                servers = {
                    {
                        address = node.address,
                        port = tonumber(node.port),
                        users = {
                            {
                                user = node.username,
                                pass = node.password
                            }
                        }
                    }
                }
            }
        })

        -- 添加路由规则
        table.insert(new_config.routing.rules, {
            type = "field",
            inboundTag = { inbound_tag },
            outboundTag = outbound_tag
        })

        -- 保存并通知 v2ray
        return save_v2ray_config(new_config)
    end

    -- 更新节点配置
    local function update_node_in_v2ray(node_id, node)
        local new_config = json.parse(json.stringify(v2ray_config)) -- 深拷贝

        -- 查找并更新对应的 inbound 和 outbound
        for _, inbound in ipairs(new_config.inbounds) do
            if inbound.tag == node_id then
                inbound.port = tonumber(node.port)
                break
            end
        end

        for _, outbound in ipairs(new_config.outbounds) do
            if outbound.tag == "outbound_" .. node_id then
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

        -- 移除 inbound
        for i, inbound in ipairs(new_config.inbounds) do
            if inbound.tag == node_id then
                table.remove(new_config.inbounds, i)
                break
            end
        end

        -- 移除 outbound
        for i, outbound in ipairs(new_config.outbounds) do
            if outbound.tag == "outbound_" .. node_id then
                table.remove(new_config.outbounds, i)
                break
            end
        end

        -- 移除路由规则
        for i, rule in ipairs(new_config.routing.rules) do
            if rule.inboundTag and rule.inboundTag[1] == node_id then
                table.remove(new_config.routing.rules, i)
                break
            end
        end

        -- 保存并通知 v2ray
        return save_v2ray_config(new_config)
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
