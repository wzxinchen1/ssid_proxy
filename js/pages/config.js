/**
 * SSID代理系统 - 规则配置页面
 * 基于模板引擎的实现
 */

import { showToast } from '../global.js';
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
  proxyServers: [],
  editConfigData: {},
  showEditModal: false
};
let componentContext;

// 页面初始化函数
export const onInit = async function (context) {
  componentContext = context;

  handleRefreshConfigs();

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
  if (!config.configs || !Array.isArray(config.configs)) {
    config.configs = [];
  }
  // 合并配置
  viewData.global = config.global;
  viewData.configs = config.configs;
  viewData.interfaces = config.interfaces;

  // 动态加载代理服务器列表
  viewData.proxyServers = await getProxyServers();
  // 初始渲染
  componentContext.render();
};

window.handleToggleConfig = async function (configId) {
  await apiRequest(`config/toggle/${configId}`, 'POST');
  showToast('配置状态已更新');
  await handleRefreshConfigs();
};

window.handleEditConfig = function (configId) {
  viewData.editConfigData = viewData.configs.find(config => config.id === configId);
  viewData.showEditModal = true;
  componentContext.render();
};

window.cancelEditConfig = () => {
  viewData.showEditModal = false;
  componentContext.render();
};

window.saveEditedConfig = async () => {
  const configId = document.getElementById('edit-config-id').value;
  const interfaceName = document.getElementById('edit-config-interface').value.trim();
  const mode = document.getElementById('edit-config-mode').value;
  const proxyServerId = document.getElementById('edit-config-proxy').value;
  const enabled = document.getElementById('edit-config-enabled').checked ? '1' : '0';

  if (!interfaceName) {
    showError('请选择网络接口');
    return;
  }

  if (mode === 'proxy' && !proxyServerId) {
    showError('请选择代理服务器');
    return;
  }

  await apiRequest(`config/update/${configId}`, 'PUT', {
    interface: interfaceName,
    mode,
    proxy_server_id: proxyServerId,
    enabled
  });
  viewData.showEditModal = false;
  await handleRefreshConfigs();
  showToast('配置更新成功');
};

window.handleDeleteConfig = async function (configId) {
  if (confirm('确定要删除此配置吗？')) {
    await apiRequest(`config/delete/${configId}`, 'DELETE');
    showToast('配置已删除');
    await handleRefreshConfigs();
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
    }
  };

  await apiRequest('config/update_global', 'POST', config);
  showToast('配置保存成功');
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