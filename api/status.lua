-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/status.lua

module("luci.controller.ssid-proxy.api.status", package.seeall)

local M = {}

function M.api_status_interface(interface)
    local sys = require "luci.sys"
    local nixio = require "nixio"
    
    -- 获取指定接口的连接信息
    local connections = {}
    local cmd = string.format("ss -tunp | grep %s | awk '{print $5, $6, $7}'", interface)
    local output = sys.exec(cmd)
    
    for line in output:gmatch("[^\n]+") do
        local src_ip, dst_ip, duration = line:match("([^ ]+) ([^ ]+) ([^ ]+)")
        if src_ip and dst_ip and duration then
            table.insert(connections, {
                src_ip = src_ip,
                dst_ip = dst_ip,
                duration = duration
            })
        end
    end
    
    -- 准备响应数据
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true, data = connections})
end

return M