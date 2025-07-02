-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/logs.lua

module("luci.controller.ssid-proxy.api.logs", package.seeall)

local M={}
function M.api_logs()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local action = http.formvalue("action")
    local level = http.formvalue("level") or "all"
    local search = http.formvalue("search") or ""
    local lines = tonumber(http.formvalue("lines")) or 100
    
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
    
    -- 获取日志并按行拆分为数组
    local logs_str = sys.exec(cmd)
    local logs = {}
    for line in logs_str:gmatch("[^\r\n]+") do
        table.insert(logs, line)
    end
    
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

return M