-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua

module("luci.controller.ssid-proxy.api.config", package.seeall)
local M = {}
function M.api_config()
    if http.getenv("REQUEST_METHOD") == "GET" then
        -- 获取配置
 
        luci.http.write_json({success = true})
    else
       
    end
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
    sys.exec("sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=\\\"" .. log_level .. "\\\"/' /usr/sbin/ssid-proxy 2>/dev/null")
    
    -- 设置日志轮转
    local retention = uci:get("ssid-proxy", "global", "log_retention") or "7"
    sys.exec("sed -i 's/^rotate.*/rotate " .. retention .. "/' /etc/logrotate.d/ssid-proxy 2>/dev/null")
    
    -- 验证配置
    sys.exec("/usr/sbin/ssid-proxy-validate")
    
    -- 重启服务
    sys.exec("/etc/init.d/ssid-proxy restart >/dev/null 2>&1")
end

return M