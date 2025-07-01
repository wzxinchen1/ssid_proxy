/**
 * SSID代理系统 - 规则配置页面
 * 基于模板引擎的实现
 */

import { apiRequest, showError } from '../utils.js';
import { getProxyServers } from './nodes.js';
// 全局状态管理
let currentConfig = {
    global: {
        enabled: '0',
        log_level: 'info',
        log_retention: '7',
        show_advanced: '0',
        rule_order: 'top',
        validate_rules: '0',
        default_enabled: '1'
    },
    rules: [],
    interfaces: []
};

export const viewData = {
    config: currentConfig.global,
    interfaces: [],
    proxyServers: []
};

// 页面初始化函数
export const onInit = async function (componentContext) {
    // 加载配置数据
    const config = await apiRequest('config');
    if (!config.interfaces) {
        config.interfaces = [];
    }
    // 合并配置
    viewData.config = currentConfig.global;
    viewData.interfaces = config.interfaces;

    // 动态加载代理服务器列表
    viewData.proxyServers = await getProxyServers();

    // 初始渲染
    componentContext.render();

    // 绑定事件
    bindConfigEvents();
};

// 辅助函数 - 获取接口标签类
window.getInterfaceTagClass = function (interfaceName) {
    if (interfaceName.startsWith('wlan')) return 'tag-wireless';
    if (interfaceName.startsWith('eth')) return 'tag-ethernet';
    if (interfaceName.startsWith('br-')) return 'tag-bridge';
    if (interfaceName.startsWith('vlan')) return 'tag-vlan';
    return '';
};

// 辅助函数 - 获取模式文本
window.getModeText = function (mode) {
    const modes = {
        proxy: '使用代理',
        direct: '直连',
        block: '阻止'
    };
    return modes[mode] || mode;
};

// 事件处理函数
window.handleRefreshRules = async function () {
    const config = await apiRequest('config');
    if (!config.interfaces) {
        config.interfaces = [];
    }
    // 合并配置
    viewData.config = currentConfig.global;
    viewData.interfaces = config.interfaces;

    // 初始渲染
    componentContext.render();
};

window.handleToggleRule = async function (ruleId) {
    try {
        const response = await apiRequest(`rules/${ruleId}/toggle`, 'POST');
        if (response.success) {
            showToast('规则状态已更新');
            await handleRefreshRules();
        }
    } catch (error) {
        showError('切换规则状态失败: ' + error.message);
    }
};

window.handleEditRule = function (ruleId) {
    // 实现编辑规则逻辑
    console.log('编辑规则:', ruleId);
};

window.handleDeleteRule = async function (ruleId) {
    if (confirm('确定要删除此规则吗？')) {
        try {
            const response = await apiRequest(`rules/${ruleId}`, 'DELETE');
            if (response.success) {
                showToast('规则已删除');
                await handleRefreshRules();
            }
        } catch (error) {
            showError('删除规则失败: ' + error.message);
        }
    }
};

window.handleModeChange = function (mode) {
    $('#proxy-server-group').toggle(mode === 'proxy');
};

window.handleAddRule = async function () {
    const newRule = {
        interface: $('#new-rule-interface').val(),
        mode: $('#new-rule-mode').val(),
        proxy_server: $('#new-rule-proxy').val(),
        enabled: $('#default-enabled').is(':checked') ? '1' : '0'
    };

    if (!newRule.interface) {
        showError('请选择网络接口');
        return;
    }

    if (newRule.mode === 'proxy' && !newRule.proxy_server) {
        showError('请选择代理服务器');
        return;
    }

    const response = await apiRequest('rules', 'POST', newRule);
    if (response.success) {
        showToast('规则添加成功');
        $('#new-rule-interface, #new-rule-proxy').val('');
        await handleRefreshRules();
    }
};

window.handleToggleAdvanced = function () {
    $('.adv-content').slideToggle();
};

window.handleReset = function () {
    if (confirm('确定要重置所有更改吗？未保存的更改将丢失。')) {
        handleRefreshRules();
    }
};

window.handleSave = async function () {
    const config = {
        global: {
            enabled: $('#global-enabled').is(':checked') ? '1' : '0',
            log_level: $('#log-level').val(),
            log_retention: $('#log-retention').val(),
            show_advanced: $('#show-advanced').is(':checked') ? '1' : '0',
            rule_order: $('#rule-order').val(),
            validate_rules: $('#validate-rules').is(':checked') ? '1' : '0',
            default_enabled: $('#default-enabled').is(':checked') ? '1' : '0'
        },
        rules: currentConfig.rules
    };

    try {
        const response = await apiRequest('config', 'POST', config);
        if (response.success) {
            showToast('配置保存成功');
        }
    } catch (error) {
        showError('保存配置失败: ' + error.message);
    }
};

// 绑定事件处理程序
function bindConfigEvents() {
    // 规则模式切换事件
    $('#new-rule-mode').on('change', function () {
        handleModeChange($(this).val());
    });

    // 初始化代理服务器显示状态
    handleModeChange($('#new-rule-mode').val());
}