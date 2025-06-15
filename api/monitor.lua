-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/monitor.lua

module("luci.controller.ssid-proxy.api.monitor", package.seeall)
local M = {}
function M.api_monitor()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    -- 获取监控数据
    local data = {
        connections = {},
        traffic = {},
        clients = {},
        interfaces = {}
    }
    
    -- 获取活跃接口
    local interfaces = sys.exec("ip -o link show | awk -F': ' '!/lo|^ /{print $2}' | sort | uniq")
    for iface in interfaces:gmatch("[^\n]+") do
        -- 获取接口状态
        local status = sys.exec("ip link show " .. iface .. " | grep -c 'state UP'") == "1" and "up" or "down"
        
        -- 获取接口类型
        local iface_type = "ethernet"
        if sys.exec("ls /sys/class/net/" .. iface .. "/wireless 2>/dev/null") ~= "" then
            iface_type = "wireless"
        elseif sys.exec("ls /sys/class/net/" .. iface .. "/bridge 2>/dev/null") ~= "" then
            iface_type = "bridge"
        elseif sys.exec("cat /proc/net/vlan/" .. iface .. " 2>/dev/null") ~= "" then
            iface_type = "vlan"
        end
        
        -- 获取接口IP
        local ip = sys.exec("ip -o -4 addr show " .. iface .. " | awk '{print $4}' | cut -d'/' -f1")
        
        -- 获取接口上的客户端数量
        local client_count = sys.exec("ip neigh show dev " .. iface .. " | grep -c 'REACHABLE'")
        
        table.insert(data.interfaces, {
            name = iface,
            type = iface_type,
            status = status,
            ip = ip,
            clients = client_count
        })
    end
    
    -- 获取活跃连接
    local conns = sys.exec("conntrack -L -p tcp 2>/dev/null | grep 'INTERFACE-PROXY'")
    for line in conns:gmatch("[^\n]+") do
        local conn = {
            src = line:match("src=(%S+)") or "N/A",
            dst = line:match("dst=(%S+)") or "N/A",
            sport = line:match("sport=(%S+)") or "N/A",
            dport = line:match("dport=(%S+)") or "N/A",
            state = line:match("state=(%S+)") or "N/A",
            interface = line:match("label=INTERFACE%-PROXY:([^%s]+)") or "unknown",
            bytes_in = 0,
            bytes_out = 0
        }
        
        -- 获取流量信息
        local bytes = line:match("bytes=(%d+)")
        if bytes then
            conn.bytes_in, conn.bytes_out = bytes:match("(%d+)%D+(%d+)")
        end
        
        table.insert(data.connections, conn)
    end
    
    -- 获取流量统计
    data.traffic = {
        today = sys.exec("vnstat --oneline | awk -F';' '{print $8,$9}'") or "N/A",
        month = sys.exec("vnstat --oneline | awk -F';' '{print $11,$12}'") or "N/A"
    }
    
    -- 获取客户端信息
    uci:foreach("dhcp", "dnsmasq", function(s)
        if s.leasefile then
            local leases = sys.exec("cat " .. s.leasefile .. " 2>/dev/null")
            for line in leases:gmatch("[^\n]+") do
                local timestamp, mac, ip, name = line:match("(%d+) (%S+) (%S+) (%S+)")
                if mac and ip then
                    -- 获取客户端接口
                    local iface = sys.exec("ip neigh | grep " .. ip .. " | awk '{print $3}'")
                    
                    table.insert(data.clients, {
                        ip = ip,
                        mac = mac,
                        name = name ~= "*" and name or "未知设备",
                        interface = iface:gsub("%s+", "") or "unknown",
                        online = sys.exec("ping -c1 -W1 " .. ip .. " >/dev/null 2>&1 && echo 1 || echo 0") == "1"
                    })
                end
            end
        end
    end)
    
    http.prepare_content("application/json")
    http.write_json({success = true, data = data})
end

return M