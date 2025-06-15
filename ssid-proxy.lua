-- SSID代理系统 - 主控制器
-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/ssid-proxy.lua

module("luci.controller.ssid-proxy.ssid-proxy", package.seeall)

function index()
    -- 主菜单入口
    entry({"admin", "services", "ssid-proxy"}, call("serve_index"), _("接口代理"), 60)
    
    -- API路由
    entry({"api", "status"}, call("api_status"), nil, 10)
    entry({"api", "config"}, call("api_config"), nil, 20)
    entry({"api", "logs"}, call("api_logs"), nil, 30)
    entry({"api", "monitor"}, call("api_monitor"), nil, 40)
    entry({"api", "service", "restart"}, call("api_service_restart"), nil, 50)
    entry({"api", "service", "start"}, call("api_service_start"), nil, 60)
    entry({"api", "service", "stop"}, call("api_service_stop"), nil, 70)
    entry({"api", "service", "toggle"}, call("api_service_toggle"), nil, 80)
end

function serve_index()
    local http = require "luci.http"
    http.redirect("/luci-static/resources/ssid-proxy/index.html")
end
-- 状态API
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
    local cpu_usage = sys.exec("top -bn1 | grep 'CPU:' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'")
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


-- 配置API
function api_config()
    local uci = require "luci.model.uci".cursor()
    local http = require "luci.http"
    
    if http.getenv("REQUEST_METHOD") == "GET" then
        -- 获取配置
        local config = {
            global = uci:get_all("ssid-proxy", "global") or {},
            rules = {}
        }
        
        uci:foreach("ssid-proxy", "rule", function(s)
            table.insert(config.rules, {
                id = s[".name"],
                enabled = s.enabled or "1",
                interface = s.interface or "",
                mode = s.mode or "proxy",
                proxy_server = s.proxy_server or ""
            })
        end)
        
        -- 获取可用接口
        config.interfaces = {}
        local ifaces = luci.sys.exec("ip -o link show | awk -F': ' '!/lo|^ /{print $2}' | sort | uniq")
        for iface in ifaces:gmatch("[^\n]+") do
            table.insert(config.interfaces, iface)
        end
        
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = true, data = config})
    else
        -- 保存配置
        local data = http.content()
        local json = require "luci.jsonc"
        local config = json.parse(data)
        
        if not config then
            http.status(400, "Bad Request")
            http.write_json({error = "Invalid JSON data"})
            return
        end
        
        uci:begin("ssid-proxy")
        
        -- 更新全局配置
        if config.global then
            for key, value in pairs(config.global) do
                uci:set("ssid-proxy", "global", key, value)
            end
        end
        
        -- 更新规则
        uci:delete_all("ssid-proxy", "rule")
        for _, rule in ipairs(config.rules) do
            local sid = uci:section("ssid-proxy", "rule")
            uci:set("ssid-proxy", sid, "enabled", rule.enabled or "1")
            uci:set("ssid-proxy", sid, "interface", rule.interface or "")
            uci:set("ssid-proxy", sid, "mode", rule.mode or "proxy")
            
            if rule.mode == "proxy" and rule.proxy_server then
                uci:set("ssid-proxy", sid, "proxy_server", rule.proxy_server)
            end
        end
        
        if not pcall(uci.commit, "ssid-proxy") then
            uci:revert("ssid-proxy")
            http.status(500, "Internal Server Error")
            http.write_json({error = "Failed to save configuration"})
            return
        end
        
        -- 应用配置
        apply_configuration()
        
        http.write_json({success = true})
    end
end

-- 日志API
function api_logs()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local action = http.formvalue("action")
    local level = http.formvalue("level") or "all"
    local search = http.formvalue("search") or ""
    local lines = tonumber(http.formvalue("lines") or 100)
    
    -- 处理清除日志操作
    if action == "clear" then
        sys.call("echo '' > /var/log/ssid-proxy.log")
        sys.call("logger -t ssid-proxy '用户手动清除了代理日志'")
        http.redirect(luci.dispatcher.build_url("admin/services/ssid-proxy/logs"))
        return
    end
    
    -- 处理导出日志操作
    if action == "export" then
        local filename = "ssid-proxy-logs-" .. os.date("%Y%m%d-%H%M%S") .. ".log"
        http.header('Content-Disposition', 'attachment; filename="' .. filename .. '"')
        http.prepare_content("text/plain")
        http.write(sys.exec("cat /var/log/ssid-proxy.log"))
        return
    end
    
    -- 构建日志查看命令
    local cmd = "tail -n " .. lines .. " /var/log/ssid-proxy.log 2>/dev/null"
    
    -- 添加级别过滤
    if level ~= "all" then
        cmd = cmd .. " | grep -i '" .. level .. "'"
    end
    
    -- 添加关键词搜索
    if search ~= "" then
        cmd = cmd .. " | grep -i '" .. search .. "'"
    end
    
    -- 获取日志
    local logs = sys.exec(cmd)
    
    -- 日志统计
    local total_lines = tonumber(sys.exec("wc -l < /var/log/ssid-proxy.log")) or 0
    local error_count = sys.exec("grep -c -i 'ERROR' /var/log/ssid-proxy.log") or 0
    local warning_count = sys.exec("grep -c -i 'WARN' /var/log/ssid-proxy.log") or 0
    local log_size = sys.exec("du -h /var/log/ssid-proxy.log | awk '{print $1}'") or "0"
    
    -- 准备响应数据
    local data = {
        logs = logs,
        stats = {
            total_lines = total_lines,
            error_count = error_count,
            warning_count = warning_count,
            log_size = log_size
        }
    }
    
    http.prepare_content("application/json")
    http.write_json({success = true, data = data})
end

-- 监控API
function api_monitor()
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

-- 服务控制API
function api_service_restart()
    local http = require "luci.http"
    luci.sys.call("/etc/init.d/ssid-proxy restart >/dev/null")
    http.prepare_content("application/json")
    http.write_json({success = true})
end

function api_service_start()
    local http = require "luci.http"
    luci.sys.call("/etc/init.d/ssid-proxy start >/dev/null")
    http.prepare_content("application/json")
    http.write_json({success = true})
end

function api_service_stop()
    local http = require "luci.http"
    luci.sys.call("/etc/init.d/ssid-proxy stop >/dev/null")
    http.prepare_content("application/json")
    http.write_json({success = true})
end

function api_service_toggle()
    local http = require "luci.http"
    local uci = require "luci.model.uci".cursor()
    local current = uci:get("ssid-proxy", "global", "enabled") or "0"
    local new_value = current == "1" and "0" or "1"
    
    uci:set("ssid-proxy", "global", "enabled", new_value)
    uci:commit("ssid-proxy")
    
    if new_value == "1" then
        luci.sys.call("/etc/init.d/ssid-proxy start >/dev/null")
    else
        luci.sys.call("/etc/init.d/ssid-proxy stop >/dev/null")
    end
    
    http.prepare_content("application/json")
    http.write_json({success = true, enabled= new_value})
end

-- 应用配置
function apply_configuration()
    local uci = require "luci.model.uci".cursor()
    local sys = require "luci.sys"
    
    -- 检查服务是否启用
    local enabled = uci:get("ssid-proxy", "global", "enabled") or "0"
    
    if enabled == "1" then
        -- 创建启用标志文件
        sys.exec("touch /etc/ssid-proxy/enabled")
    else
        -- 删除启用标志文件
        sys.exec("rm -f /etc/ssid-proxy/enabled")
    end
    
    -- 更新日志级别
    local log_level = uci:get("ssid-proxy", "global", "log_level") or "info"
    sys.exec("sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=\"" .. log_level .. "\"/' /usr/sbin/ssid-proxy 2>/dev/null")
    
    -- 设置日志轮转
    local retention = uci:get("ssid-proxy", "global", "log_retention") or "7"
    sys.exec("sed -i 's/^rotate.*/rotate " .. retention .. "/' /etc/logrotate.d/ssid-proxy 2>/dev/null")
    
    -- 验证配置
    sys.exec("/usr/sbin/ssid-proxy-validate")
    
    -- 重启服务
    sys.exec("/etc/init.d/ssid-proxy restart >/dev/null 2>&1")
end
