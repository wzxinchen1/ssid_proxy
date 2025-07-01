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
        config_order: 'top',
        validate_configs: '0',
        default_enabled: '1'
    },
    configs: [],
    interfaces: []
};

export const viewData = {
    global: currentConfig.global,
    interfaces: [],
    proxyServers: []
};

// 页面初始化函数
export const onInit = async function (componentContext) {
    // 加载配置数据
    const config = await apiRequest('config/get');
    if (!config.interfaces) {
        config.interfaces = [];
    }
    // 合并配置
    viewData.global = currentConfig.global;
    viewData.configs = config.configs;
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
window.handleRefreshConfigs = async function () {
    const config = await apiRequest('config/get');
    if (!config.interfaces) {
        config.interfaces = [];
    }
    // 合并配置
    viewData.global = currentConfig.global;
    viewData.configs = config.configs;
    viewData.interfaces = config.interfaces;

    // 初始渲染
    componentContext.render();
};

window.handleToggleConfig = async function (configId) {
    try {
        const response = await apiRequest(`config/${configId}/toggle`, 'POST');
        if (response.success) {
            showToast('配置状态已更新');
            await handleRefreshConfigs();
        }
    } catch (error) {
        showError('切换配置状态失败: ' + error.message);
    }
};

window.handleEditConfig = function (configId) {
    // 实现编辑配置逻辑
    console.log('编辑配置:', configId);
};

window.handleDeleteConfig = async function (configId) {
    if (confirm('确定要删除此配置吗？')) {
        try {
            const response = await apiRequest(`config/${configId}`, 'DELETE');
            if (response.success) {
                showToast('配置已删除');
                await handleRefreshConfigs();
            }
        } catch (error) {
            showError('删除配置失败: ' + error.message);
        }
    }
};

window.handleModeChange = function (mode) {
    $('#proxy-server-group').toggle(mode === 'proxy');
};

window.handleAddConfig = async function () {
    const newConfig = {
        interface: $('#new-config-interface').val(),
        mode: $('#new-config-mode').val(),
        proxy_server_id: $('#new-config-proxy').val(), // 保存代理服务器 ID
        enabled: $('#default-enabled').is(':checked') ? '1' : '0'
    };

    if (!newConfig.interface) {
        showError('请选择网络接口');
        return;
    }

    if (newConfig.mode === 'proxy' && !newConfig.proxy_server_id) {
        showError('请选择代理服务器');
        return;
    }

    await apiRequest('config/add', 'POST', newConfig);
    showToast('配置添加成功');
    $('#new-config-interface, #new-config-proxy').val('');
    await handleRefreshConfigs();
};

window.handleToggleAdvanced = function () {
    $('.adv-content').slideToggle();
};

window.handleReset = function () {
    if (confirm('确定要重置所有更改吗？未保存的更改将丢失。')) {
        handleRefreshConfigs();
    }
};

window.handleSave = async function () {
    const config = {
        global: {
            enabled: $('#global-enabled').is(':checked') ? '1' : '0',
            log_level: $('#log-level').val(),
            log_retention: $('#log-retention').val(),
            show_advanced: $('#show-advanced').is(':checked') ? '1' : '0',
            config_order: $('#config-order').val(),
            validate_configs: $('#validate-configs').is(':checked') ? '1' : '0',
            default_enabled: $('#default-enabled').is(':checked') ? '1' : '0'
        },
        configs: currentConfig.configs
    };

    try {
        const response = await apiRequest('config/update_global', 'POST', config);
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
    $('#new-config-mode').on('change', function () {
        handleModeChange($(this).val());
    });

    // 初始化代理服务器显示状态
    handleModeChange($('#new-config-mode').val());
}