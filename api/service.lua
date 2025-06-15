-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/service.lua

module("luci.controller.ssid-proxy.api.service", package.seeall)

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
