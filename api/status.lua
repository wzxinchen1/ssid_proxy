-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/status.lua

module("luci.controller.ssid-proxy.api.status", package.seeall)

function api_status()
    local sys = require "luci.sys"
    local nixio = require "nixio"
    
    -- 替代方法获取内存信息
    local mem_total = 0
    local mem_free = 0
    local mem_percent = 0
    
    -- 通过 /proc/meminfo 获取内存信息
    for line in io.lines("/proc/meminfo") do
        if line:match("MemTotal:") then
            mem_total = tonumber(line:match("%d+"))
        elseif line:match("MemAvailable:") then
            mem_free = tonumber(line:match("%d+"))
        end
    end
    
    if mem_total > 0 then
        mem_percent = math.floor(((mem_total - mem_free) / mem_total) * 100)
    end
    
    -- 获取CPU使用率
    local cpu_usage = sys.exec("top -bn1 | grep 'CPU:' | sed 's/.*, *\\\\([0-9.]*\\\\)%* id.*/\\\\1/' | awk '{print 100 - $1}'")
    cpu_usage = tonumber(cpu_usage) or 0
    
    -- 获取系统运行时间
    local uptime = sys.uptime()
    local days = math.floor(uptime / (24*60*60))
    local hours = math.floor((uptime % (24*60*60)) / (60*60))
    local minutes = math.floor((uptime % (60*60)) / 60)
    
    -- 获取服务状态
    local pid = sys.exec("pgrep -f '/usr/sbin/ssid-proxy'")
    local service_status = pid and #pid > 0 and "running" or "stopped"
    
    -- 获取网络接口信息
    local interfaces = {}
    for line in sys.exec("ip -o link show"):gmatch("[^\n]+") do
        local iface = line:match("^%d+: ([^:]+)")
        if iface and not iface:match("^lo") then
            local status = line:match("state (UP)") and "up" or "down"
            local mac = line:match("link/ether ([^ ]+)")
            table.insert(interfaces, {
                name = iface,
                status = status,
                mac = mac
            })
        end
    end
    
    -- 准备响应数据
    local data = {
        cpu = cpu_usage,
        memory = mem_percent,
        uptime = string.format("%d天 %d小时 %d分钟", days, hours, minutes),
        service = service_status,
        interfaces = interfaces,
        version = sys.exec("opkg list-installed | grep ssid-proxy | awk '{print $3}'") or "unknown"
    }
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true, data = data})
end
