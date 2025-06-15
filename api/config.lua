-- SSID代理系统 - 配置管理API
-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua

module("luci.controller.ssid-proxy.api.config", package.seeall)

local uci = require "luci.model.uci".cursor()
local http = require "luci.http"
local json = require "luci.jsonc"
local sys = require "luci.sys"

function index()
    entry({"api", "config"}, call("handle_config"), nil, 0)
end

-- 处理配置API请求
function handle_config()
    local method = http.getenv("REQUEST_METHOD")
    
    if method == "GET" then
        get_config()
    elseif method == "POST" then
        post_config()
    else
        http.status(405, "Method Not Allowed")
        http.write_json({error = "Unsupported method"})
    end
end

-- 获取当前配置
function get_config()
    local config = {
        global = {},
        rules = {}
    }
    
    -- 获取全局配置
    config.global = uci:get_all("ssid-proxy", "global") or {}
    
    -- 获取规则配置
    uci:foreach("ssid-proxy", "rule", function(section)
        table.insert(config.rules, {
            id = section[".name"],
            enabled = section.enabled or "1",
            interface = section.interface or "",
            mode = section.mode or "proxy",
            proxy_server = section.proxy_server or ""
        })
    end)
    
    -- 获取可用接口列表
    config.interfaces = get_available_interfaces()
    
    http.write_json({success = true, data = config})
end

-- 保存配置
function post_config()
    local data = http.content()
    local success, config = pcall(json.parse, data)
    
    if not success or type(config) ~= "table" then
        http.status(400, "Bad Request")
        http.write_json({error = "Invalid JSON data"})
        return
    end
    
    -- 开始UCI事务
    uci:begin("ssid-proxy")
    
    -- 保存全局配置
    if config.global then
        for key, value in pairs(config.global) do
            uci:set("ssid-proxy", "global", key, value)
        end
    end
    
    -- 保存规则配置
    if config.rules then
        -- 删除所有现有规则
        uci:delete_all("ssid-proxy", "rule")
        
        -- 添加新规则
        for _, rule in ipairs(config.rules) do
            local sid = uci:section("ssid-proxy", "rule")
            uci:set("ssid-proxy", sid, "enabled", rule.enabled or "1")
            uci:set("ssid-proxy", sid, "interface", rule.interface or "")
            uci:set("ssid-proxy", sid, "mode", rule.mode or "proxy")
            
            if rule.mode == "proxy" and rule.proxy_server then
                uci:set("ssid-proxy", sid, "proxy_server", rule.proxy_server)
            else
                uci:delete("ssid-proxy", sid, "proxy_server")
            end
        end
    end
    
    -- 提交UCI更改
    local success, err = pcall(uci.commit, "ssid-proxy")
    if not success then
        uci:revert("ssid-proxy")
        http.status(500, "Internal Server Error")
        http.write_json({error = "Failed to save configuration: " .. tostring(err)})
        return
    end
    
    -- 应用配置
    apply_configuration()
    
    http.write_json({success = true})
end

-- 获取可用网络接口列表
function get_available_interfaces()
    local interfaces = {}
    local output = sys.exec("ip -o link show | awk -F': ' '!/lo|^ /{print $2}' | sort | uniq")
    
    for iface in output:gmatch("[^\n]+") do
        table.insert(interfaces, iface)
    end
    
    return interfaces
end

-- 应用配置更改
function apply_configuration()
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
