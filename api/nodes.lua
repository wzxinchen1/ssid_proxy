-- 文件路径: E:\桌面\ssid_proxy\api\nodes.lua

module("luci.controller.ssid-proxy.api.nodes", package.seeall)

function api_nodes()
    local http = require "luci.http"
    local json = require "luci.jsonc"
    local uci = require "luci.model.uci".cursor()
    
    local method = http.getenv("REQUEST_METHOD")
    local path_info = http.getenv("PATH_INFO") or ""
    
    -- 从路径中提取 nodeId
    local nodeId = nil
    local path_parts = {}
    for part in path_info:gmatch("[^/]+") do
        table.insert(path_parts, part)
    end
    if #path_parts >= 2 then
        nodeId = path_parts[2]
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
        http.write_json({ success = true, data = nodes })
    elseif method == "POST" then
        -- 确保有有效数据
        if not data then
            http.status(400, "Bad Request")
            http.write_json({ success = false, error = "Invalid JSON data" })
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
        http.write_json({ success = true, id = id })
    elseif method == "PUT" then
        -- 确保有有效数据
        if not nodeId and (not data or not data.id) then
            http.status(400, "Bad Request")
            http.write_json({ success = false, error = "没有NodeID" })
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
        http.write_json({ success = true, id = id })
    elseif method == "DELETE" then
        -- 确保有有效数据
        if not nodeId and (not data or not data.id) then
            http.status(400, "Bad Request")
            http.write_json({ success = false, error = "没有NodeID" })
            return
        end
        
        -- 删除节点
        local id = nodeId or data.id
        uci:delete("ssid-proxy", id)
        uci:commit("ssid-proxy")
        
        http.prepare_content("application/json")
        http.write_json({ success = true })
    else
        http.status(405, "Method Not Allowed")
        http.write_json({ success = false, error = "Method not allowed: " .. method })
    end
end