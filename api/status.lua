-- 文件路径: E:\桌面\ssid_proxy\api\status.lua
module("luci.controller.ssid-proxy.api.status", package.seeall)

local fs = require "nixio.fs"
local json = require "luci.jsonc"
local http = require "luci.http"
local sys = require "luci.sys"
local hiddenPorts = {53}

function contains(arr, item)
    for k, v in pairs(arr) do
        if item == v then
            return true
        end
    end
    return false
end

-- 获取指定接口的连接状态
function get_status(ip)
    local conntrack_cmd = "conntrack -L -s " .. ip
    local handle = io.popen(conntrack_cmd)
    local result = handle:read("*a")
    handle:close()

    local connections = {}
    for line in result:gmatch("[^\r\n]+") do
        local src_ip, dst_ip, sport, dport, packets, bytes = line:match(
            "src=([^%s]+) dst=([^%s]+) sport=([^%s]+) dport=([^%s]+) packets=([^%s]+) bytes=([^%s]+)")
        if string.find(result, "ESTABLISHED") and src_ip and dst_ip and sport and
            not contains(hiddenPorts, tonumber(dport)) then
                table.insert(connections, {
                    src_ip = src_ip,
                    dst_ip = dst_ip,
                    sport = sport,
                    dport = dport,
                    packets = packets,
                    bytes = bytes
                })
            end
        end
    end

    return connections
end

-- 获取指定接口的所有客户端IP
function get_clients(interface)
    local cmd = "cat /proc/net/arp | grep " .. interface .. " | grep 0x2 | awk '{print $1}' | grep -v 'Address'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    local clients = {}
    for ip in result:gmatch("[^\r\n]+") do
        table.insert(clients, ip)
    end

    return clients
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

-- 处理 /api/status/game_clients 请求
function get_game_clients()
    local method = http.getenv("REQUEST_METHOD")
    if http.cors() then
        return
    end

    if method == "GET" then
        local clients = {}
        local interfaces = {"br-game1", "br-game2", "br-game3"}

        for _, interface in ipairs(interfaces) do
            local interface_clients = get_clients(interface)
            table.insert(clients, {
                interface = interface,
                clients = interface_clients
            })
        end

        http.prepare_content("application/json")
        http.write_json({
            success = true,
            data = clients
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
