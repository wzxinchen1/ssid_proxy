-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua
module("luci.controller.ssid-proxy.api.config", package.seeall)
local M = {}

-- 获取配置
function M.get_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local config = {
        global = uci:get_all("ssid-proxy", "global") or {},
        configs = {}
    }

    uci:foreach("ssid-proxy", "config", function(s)
        table.insert(config.configs, {
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
    luci.http.write_json({
        success = true,
        data = config
    })
end

-- 获取全局配置
function M.get_global_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end

    local global_config = uci:get_all("ssid-proxy", "global") or {}

    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = true,
        data = global_config
    })
end

-- 更新全局配置
function M.update_global_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local data = http.content()
    local json = require "luci.jsonc"
    local config = json.parse(data)

    if not config then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Invalid JSON data"
        })
        return
    end

    -- 更新全局配置
    for key, value in pairs(config.global) do
        uci:set("ssid-proxy", "global", key, value)
    end

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    -- 应用配置
    apply_configuration()

    http.write_json({
        success = true
    })
end

-- 添加新配置
function M.add_config()
    local uci = require"luci.model.uci".cursor()
    local http = require "luci.http"

    if luci.http.cors() then
        return
    end
    local data = http.content()
    local json = require "luci.jsonc"
    local config = json.parse(data)

    if not config then
        http.status(400, "Bad Request")
        http.write_json({
            error = "Invalid JSON data"
        })
        return
    end

    -- 添加新配置
    local sid = uci:section("ssid-proxy", "config")
    uci:set("ssid-proxy", sid, "enabled", config.enabled or "1")
    uci:set("ssid-proxy", sid, "interface", config.interface or "")
    uci:set("ssid-proxy", sid, "mode", config.mode or "proxy")

    if config.mode == "proxy" and config.proxy_server then
        uci:set("ssid-proxy", sid, "proxy_server", config.proxy_server)
    end

    local success, err = pcall(function()
        uci:commit("ssid-proxy")
    end)
    if not success then
        http.status(500, "Internal Server Error")
        http.write_json({
            error = tostring(err)
        })
        return
    end

    -- 应用配置
    apply_configuration()

    http.write_json({
        success = true,
        id = sid
    })
end

-- 应用配置
function apply_configuration()
    local uci = require"luci.model.uci".cursor()
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