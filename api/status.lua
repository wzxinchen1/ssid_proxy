-- 文件路径: E:\桌面\ssid_proxy\api\status.lua
module("luci.controller.ssid-proxy.api.status", package.seeall)

local fs = require "nixio.fs"
local json = require "luci.jsonc"
local http = require "luci.http"
local sys = require "luci.sys"

-- 获取指定接口的连接状态
function get_status(interface)
    local conntrack_cmd = "conntrack -L | grep " .. interface ..
                              " | awk '{print $4,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20}'"
    local handle = io.popen(conntrack_cmd)
    local result = handle:read("*a")
    handle:close()

    local connections = {}
    for line in result:gmatch("[^\r\n]+") do
        local parts = {}
        for part in line:gmatch("%S+") do
            table.insert(parts, part)
        end

        if #parts >= 3 then
            table.insert(connections, {
                src_ip = parts[1],
                dst_ip = parts[2],
                duration = parts[3]
            })
        end
    end

    return connections
end

-- 处理 /api/status/{interface} 请求
function get_interface_status()
    local method = http.getenv("REQUEST_METHOD")
    local path_info = http.getenv("PATH_INFO") or ""

    -- 从路径中提取接口名
    local interface = nil
    local pattern = "/api/status/([^/]+)$"
    if path_info then
        local match = path_info:match(pattern)
        if match then
            interface = match
        end
    end
    if http.cors() then
        return
    end

    if method == "GET" then
        if not interface then
            http.status(400, "Bad Request")
            http.write_json({
                success = false,
                error = "Interface parameter is missing"
            })
            return
        end

        local connections = get_status(interface)
        http.prepare_content("application/json")
        http.write_json({
            success = true,
            data = connections
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
