module("luci.controller.ssid-proxy.api.game", package.seeall)
local Get = {}

function Get.IP()
    local http = require "luci.http"
    local client_ip = http.getenv("REMOTE_ADDR")
    return client_ip
end

return {
    get=Get
}