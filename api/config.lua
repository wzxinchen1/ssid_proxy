-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua

module("luci.controller.ssid-proxy.api.config", package.seeall)
local M = {}
function M.api_config()
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
    else if http.getenv("REQUEST_METHOD") == "POST" then
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