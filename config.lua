
m = Map("ssid-proxy", translate("接口代理配置"), 
    translate("基于网络接口配置代理规则。默认不启用任何代理，需在此页面显式启用和配置规则。"))

-- 全局设置部分
s_global = m:section(TypedSection, "global", translate("全局设置"))
s_global.anonymous = true

-- 启用/禁用开关
enable = s_global:option(Flag, "enabled", translate("启用接口代理"), 
    translate("勾选此选项以启用基于网络接口的代理功能。禁用时所有代理规则将失效。"))
enable.default = false
enable.rmempty = false

-- 高级选项开关
adv = s_global:option(Flag, "advanced", translate("显示高级选项"))
adv.default = false

-- 日志级别
log_level = s_global:option(ListValue, "log_level", translate("日志级别"))
log_level:value("error", "错误")
log_level:value("warning", "警告")
log_level:value("info", "信息")
log_level:value("debug", "调试")
log_level.default = "info"
log_level:depends("advanced", "1")
log_level.description = translate("设置日志详细程度，调试级别会记录更多细节")

-- 日志保留时间
log_retention = s_global:option(ListValue, "log_retention", translate("日志保留时间"))
log_retention:value("3", "3 天")
log_retention:value("7", "7 天 (推荐)")
log_retention:value("14", "14 天")
log_retention:value("30", "30 天")
log_retention.default = "7"
log_retention:depends("advanced", "1")
log_retention.description = translate("自动删除超过此天数的旧日志")

-- 规则部分
s_rules = m:section(TypedSection, "rule", translate("代理规则"), 
    translate("为特定网络接口配置代理规则。规则按列表顺序应用，可拖动排序。"))
s_rules.template = "cbi/tblsection"
s_rules.sortable = true
s_rules.anonymous = false
s_rules.addremove = true
s_rules.rowcolors = true

-- 规则启用开关
enabled = s_rules:option(Flag, "enabled", translate("启用"))
enabled.default = true
enabled.rmempty = false

-- 接口选择 - 下拉选择框
interface = s_rules:option(ListValue, "interface", translate("网络接口"))
interface.rmempty = false

-- 动态获取可用接口
local interfaces = luci.sys.exec("ip -o link show | awk -F': ' '!/lo|^ /{print $2}' | sort | uniq")
for iface in interfaces:gmatch("[^\n]+") do
    interface:value(iface, iface)
end

-- 代理模式选择
mode = s_rules:option(ListValue, "mode", translate("代理行为"))
mode:value("direct", translate("直连 (不经过代理)"))
mode:value("proxy", translate("使用代理"))
mode:value("block", translate("阻止互联网访问"))
mode.default = "proxy"
mode.rmempty = false

-- 代理服务器设置
proxy = s_rules:option(Value, "proxy_server", translate("代理服务器"))
proxy:depends("mode", "proxy")
proxy.datatype = "string"
proxy.placeholder = "socks5://[hbb12:h12]106.63.10.142:11005"
proxy.rmempty = true

-- 代理服务器格式验证
function proxy.validate(self, value, section)
    if mode:formvalue(section) == "proxy" then
        if value == nil or value:match("^%s*$") then
            return nil, translate("代理模式必须填写代理服务器地址！")
        end
    end
    return value
end

-- 操作按钮
actions = s_rules:option(DummyValue, "_actions", translate("操作"))
actions.template = "ssid-proxy/rule_actions"

local add_section = m:section(SimpleSection)
add_section.template = "ssid-proxy/add_rule_section"

-- 配置提交后的处理
function m.on_after_commit(self)
    local enabled = m:formvalue("cbid.ssid-proxy.global.enabled")
    if enabled == "1" then
        os.execute("touch /etc/ssid-proxy/enabled")
    else
        os.execute("rm -f /etc/ssid-proxy/enabled")
    end
    
    -- 更新日志级别
    local log_level = m:formvalue("cbid.ssid-proxy.global.log_level") or "info"
    os.execute("sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=\"" .. log_level .. "\"/' /usr/sbin/ssid-proxy 2>/dev/null")
    
    -- 设置日志轮转
    local retention = m:formvalue("cbid.ssid-proxy.global.log_retention") or "7"
    os.execute("sed -i 's/^rotate.*/rotate " .. retention .. "/' /etc/logrotate.d/ssid-proxy 2>/dev/null")
    
    -- 验证配置
    local valid = os.execute("/usr/sbin/ssid-proxy-validate")
    if valid ~= 0 then
        os.execute("logger -t ssid-proxy '配置验证失败'")
    end
    
    -- 重启服务
    os.execute("/etc/init.d/ssid-proxy restart >/dev/null 2>&1")
end

-- 修复：添加新规则时的空值处理
function s_rules.parse(self, ...)
    -- 获取添加按钮的值
    local add = luci.http.formvalue("cbi.rts." .. self.config .. ".add")
    
    if add then
        -- 获取用户输入的接口名称
        local iface = luci.http.formvalue("cbid." .. self.config .. ".new_interface") or ""
        
        -- 验证接口是否为空
        if iface:match("^%s*$") then
            -- 显示错误提示
            m.message = translate("接口名称不能为空！")
            return
        end
        
        -- 创建新规则
        local sid = m.uci:section("ssid-proxy", "rule")
        m.uci:set("ssid-proxy", sid, "interface", iface)
        m.uci:set("ssid-proxy", sid, "enabled", "1")
        m.uci:set("ssid-proxy", sid, "mode", "proxy")
        
        -- 保存配置
        m.uci:save("ssid-proxy")
        
        -- 重定向到当前页面，避免重复提交
        luci.http.redirect(luci.dispatcher.build_url("admin/services/ssid-proxy/config"))
        return
    end
    
    -- 调用原始解析函数
    TypedSection.parse(self, ...)
end

return m
