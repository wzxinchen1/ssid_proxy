-- 文件路径: E:\桌面\ssid_proxy\api\status.lua
module("luci.controller.ssid-proxy.api.status", package.seeall)

local fs = require "nixio.fs"
local json = require "luci.jsonc"
local http = require "luci.http"
local sys = require "luci.sys"
local hiddenPorts = {53}

local get = {}
local post = {}
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
        local targetPort = tonumber(dport)
        if string.find(result, "ESTABLISHED") and src_ip and dst_ip and sport and not contains(hiddenPorts, targetPort) then
            table.insert(connections, {
                src_ip = src_ip,
                dst_ip = dst_ip,
                sport = tonumber(sport),
                dport = tonumber(dport),
                packets = packets,
                bytes = bytes
            })
        end
    end
    table.sort(connections, function(a, b)
        local c = a or b
        if c.dport > 6000 and c.dport < 7000 then
            return 1
        end
        return 0
    end)
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
get.ip = {
    function(ip)
        local connections = get_status(ip)
        return ({
            success = true,
            data = connections
        })
    end,
    path = "api/{controller}/{action}/{ip}"
}

function get.clients()
    local clients = {}
    local interfaces = {"br-game1", "br-game2", "br-game3"}

    for _, interface in ipairs(interfaces) do
        local interface_clients = get_clients(interface)
        table.insert(clients, {
            interface = interface,
            clients = interface_clients
        })
    end

    return ({
        success = true,
        data = clients
    })
end

return {
    get = get,
    post = post

}
