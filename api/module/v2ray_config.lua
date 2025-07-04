local uci = require("luci.model.uci").cursor()
local json = require("luci.jsonc")
local fs = require("nixio.fs")

local M = {}

-- 配置文件路径
M.config_path = "/mnt/usb/v2ray.config.json"

-- 读取配置文件
function M.read_config()
    local content = fs.readfile(M.config_path)
    if not content then
        return nil, "Failed to read config file"
    end
    return json.parse(content)
end

-- 写入配置文件
function M.write_config(config)
    local ok, json_str = pcall(json.stringify, config, { pretty = true })
    if not ok then
        return false, "Failed to serialize config: " .. json_str
    end
    return fs.writefile(M.config_path, json_str)
end

-- 检查tag是否已存在
local function tag_exists(config, tag, section)
    for _, item in ipairs(config[section] or {}) do
        if item.tag == tag then
            return true
        end
    end
    return false
end

-- INBOUNDS 操作
function M.get_inbounds()
    local config, err = M.read_config()
    if not config then return nil, err end
    return config.inbounds or {}
end

function M.get_inbound_by_tag(tag)
    local inbounds, err = M.get_inbounds()
    if not inbounds then return nil, err end
    for _, inbound in ipairs(inbounds) do
        if inbound.tag == tag then
            return inbound
        end
    end
    return nil, "Inbound not found"
end

function M.add_inbound(new_inbound)
    if not new_inbound.tag then
        return false, "Tag is required for inbound"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查tag是否已存在
    if tag_exists(config, new_inbound.tag, "inbounds") then
        return false, "Inbound with tag '" .. new_inbound.tag .. "' already exists"
    end

    config.inbounds = config.inbounds or {}
    table.insert(config.inbounds, new_inbound)
    return M.write_config(config)
end

function M.update_inbound(tag, updated_inbound)
    if not updated_inbound.tag then
        return false, "Tag is required for inbound"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查目标tag是否存在
    local found = false
    for i, inbound in ipairs(config.inbounds or {}) do
        if inbound.tag == tag then
            found = true
            -- 如果tag被修改，检查新tag是否已存在
            if tag ~= updated_inbound.tag and tag_exists(config, updated_inbound.tag, "inbounds") then
                return false, "Inbound with tag '" .. updated_inbound.tag .. "' already exists"
            end
            config.inbounds[i] = updated_inbound
            break
        end
    end

    if not found then
        return false, "Inbound not found"
    end

    return M.write_config(config)
end

function M.delete_inbound(tag)
    local config, err = M.read_config()
    if not config then return false, err end

    for i, inbound in ipairs(config.inbounds or {}) do
        if inbound.tag == tag then
            table.remove(config.inbounds, i)
            return M.write_config(config)
        end
    end
    return false, "Inbound not found"
end

-- OUTBOUNDS 操作
function M.get_outbounds()
    local config, err = M.read_config()
    if not config then return nil, err end
    return config.outbounds or {}
end

function M.get_outbound_by_tag(tag)
    local outbounds, err = M.get_outbounds()
    if not outbounds then return nil, err end
    for _, outbound in ipairs(outbounds) do
        if outbound.tag == tag then
            return outbound
        end
    end
    return nil, "Outbound not found"
end

function M.add_outbound(new_outbound)
    if not new_outbound.tag then
        return false, "Tag is required for outbound"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查tag是否已存在
    if tag_exists(config, new_outbound.tag, "outbounds") then
        return false, "Outbound with tag '" .. new_outbound.tag .. "' already exists"
    end

    config.outbounds = config.outbounds or {}
    table.insert(config.outbounds, new_outbound)
    return M.write_config(config)
end

function M.update_outbound(tag, updated_outbound)
    if not updated_outbound.tag then
        return false, "Tag is required for outbound"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查目标tag是否存在
    local found = false
    for i, outbound in ipairs(config.outbounds or {}) do
        if outbound.tag == tag then
            found = true
            -- 如果tag被修改，检查新tag是否已存在
            if tag ~= updated_outbound.tag and tag_exists(config, updated_outbound.tag, "outbounds") then
                return false, "Outbound with tag '" .. updated_outbound.tag .. "' already exists"
            end
            config.outbounds[i] = updated_outbound
            break
        end
    end

    if not found then
        return false, "Outbound not found"
    end

    return M.write_config(config)
end

function M.delete_outbound(tag)
    local config, err = M.read_config()
    if not config then return false, err end

    for i, outbound in ipairs(config.outbounds or {}) do
        if outbound.tag == tag then
            table.remove(config.outbounds, i)
            return M.write_config(config)
        end
    end
    return false, "Outbound not found"
end

-- ROUTING 操作
function M.get_routing()
    local config, err = M.read_config()
    if not config then return nil, err end
    return config.routing or { rules = {} }
end

function M.get_rule_by_inbound_tag(inbound_tag)
    local routing, err = M.get_routing()
    if not routing then return nil, err end

    for _, rule in ipairs(routing.rules or {}) do
        if rule.inboundTag then
            if type(rule.inboundTag) == "table" then
                for _, tag in ipairs(rule.inboundTag) do
                    if tag == inbound_tag then
                        return rule
                    end
                end
            elseif rule.inboundTag == inbound_tag then
                return rule
            end
        end
    end
    return nil, "Rule not found"
end

function M.add_rule(new_rule)
    if not new_rule.inboundTag then
        return false, "inboundTag is required for rule"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查inboundTag是否已存在
    local inboundTags = type(new_rule.inboundTag) == "table" and new_rule.inboundTag or { new_rule.inboundTag }
    for _, tag in ipairs(inboundTags) do
        local rule, _ = M.get_rule_by_inbound_tag(tag)
        if rule then
            return false, "Rule for inboundTag '" .. tag .. "' already exists"
        end
    end

    config.routing = config.routing or { rules = {} }
    table.insert(config.routing.rules, new_rule)
    return M.write_config(config)
end

function M.update_rule_by_inbound_tag(inbound_tag, updated_rule)
    if not updated_rule.inboundTag then
        return false, "inboundTag is required for rule"
    end

    local config, err = M.read_config()
    if not config then return false, err end

    -- 检查目标rule是否存在
    local found = false
    for i, rule in ipairs(config.routing.rules or {}) do
        if rule.inboundTag then
            local ruleTags = type(rule.inboundTag) == "table" and rule.inboundTag or { rule.inboundTag }
            for _, tag in ipairs(ruleTags) do
                if tag == inbound_tag then
                    found = true
                    -- 检查新inboundTag是否已存在
                    local newTags = type(updated_rule.inboundTag) == "table" and updated_rule.inboundTag or { updated_rule.inboundTag }
                    for _, newTag in ipairs(newTags) do
                        if newTag ~= inbound_tag then
                            local existingRule, _ = M.get_rule_by_inbound_tag(newTag)
                            if existingRule then
                                return false, "Rule for inboundTag '" .. newTag .. "' already exists"
                            end
                        end
                    end
                    config.routing.rules[i] = updated_rule
                    break
                end
            end
        end
    end

    if not found then
        return false, "Rule not found"
    end

    return M.write_config(config)
end

function M.delete_rule_by_inbound_tag(inbound_tag)
    local config, err = M.read_config()
    if not config then return false, err end

    for i, rule in ipairs(config.routing.rules or {}) do
        if rule.inboundTag then
            if type(rule.inboundTag) == "table" then
                for j, tag in ipairs(rule.inboundTag) do
                    if tag == inbound_tag then
                        table.remove(rule.inboundTag, j)
                        if #rule.inboundTag == 0 then
                            table.remove(config.routing.rules, i)
                        end
                        return M.write_config(config)
                    end
                end
            elseif rule.inboundTag == inbound_tag then
                table.remove(config.routing.rules, i)
                return M.write_config(config)
            end
        end
    end
    return false, "Rule not found"
end

return M
