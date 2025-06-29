-- 文件路径: /usr/lib/lua/luci/controller/ssid-proxy/api/config.lua

module("luci.controller.ssid-proxy.api.config", package.seeall)
local M = {}
function M.api_config()
    if luci.http.getenv("REQUEST_METHOD") == "GET" then
        -- 获取配置
 
        luci.http.write_json({success = true})
    else
       
    end
end

return M