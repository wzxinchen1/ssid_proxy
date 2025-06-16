-- 文件路径: E:\桌面\ssid_proxy\api\nodes.lua
module("luci.controller.ssid-proxy.api.nodes", package.seeall)

function api_nodes()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local uci = require"luci.model.uci".cursor()

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
        -- 获取节点列表
        local nodes = {}
        uci:foreach("ssid-proxy", "node", function(s)
            table.insert(nodes, {
                id = s[".name"],
                name = s["name"],
                address = s["address"],
                port = s["port"],
                protocol = s["protocol"],
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
        uci:commit("ssid-proxy")

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            id = id
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
        uci:commit("ssid-proxy")

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
    else
        http.status(405, "Method Not Allowed")
        http.write_json({
            success = false,
            error = "Method not allowed: " .. method
        })
    end
end
