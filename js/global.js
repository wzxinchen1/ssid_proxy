/**
 * SSID代理系统 - 全局状态管理
 * 负责管理应用全局状态、监控数据和系统配置
 */

import { apiRequest } from "./utils.js";

// 全局状态对象
export const globalState = {
    // 系统状态
    serviceEnabled: false,
    serviceRunning: false,

    // 监控数据
    monitorData: {
        cpu: 0,
        memory: 0,
        activeConnections: 0,
        dailyTraffic: 0,
        interfaces: []
    },

    // 用户配置
    userConfig: {
        refreshInterval: 10, // 默认10秒刷新
        theme: 'light',
        logLevel: 'info'
    },

    // 页面状态
    currentPage: 'status',
    lastUpdate: null,

    // 订阅者列表
    subscribers: {
        monitor: [],
        config: [],
        service: []
    },
    isLocal: location.href.includes("127.0.0.1")
};

// 监控更新定时器
let monitorInterval = null;

/**
 * 初始化全局状态
 */
export function initGlobalState() {
    // 从本地存储加载用户配置
    loadUserConfig();

    // 初始化监控数据
    fetchGlobalMonitor();

    // 设置监控更新定时器
    setupMonitorInterval();

    // 绑定全局事件
    bindGlobalEvents();
}

/**
 * 从本地存储加载用户配置
 */
function loadUserConfig() {
    const savedConfig = localStorage.getItem('ssidProxyConfig');
    if (savedConfig) {
        try {
            const config = JSON.parse(savedConfig);
            Object.assign(globalState.userConfig, config);
            applyUserConfig();
        } catch (e) {
            console.error('加载用户配置失败:', e);
        }
    }
}

/**
 * 保存用户配置到本地存储
 */
export function saveUserConfig() {
    localStorage.setItem('ssidProxyConfig', JSON.stringify(globalState.userConfig));
    applyUserConfig();
}

/**
 * 应用用户配置
 */
function applyUserConfig() {
    const { theme, refreshInterval } = globalState.userConfig;

    // 应用主题
    document.documentElement.setAttribute('data-theme', theme);

    // 更新监控间隔
    setupMonitorInterval();

    // 通知配置订阅者
    notifySubscribers('config');
}

/**
 * 设置监控更新定时器
 */
function setupMonitorInterval() {
    // 清除现有定时器
    if (monitorInterval) {
        clearInterval(monitorInterval);
    }

    // 设置新定时器
    const interval = globalState.userConfig.refreshInterval * 1000;
    if (interval > 0) {
        monitorInterval = setInterval(fetchGlobalMonitor, interval);
    }
}

/**
 * 获取全局监控数据
 */
export async function fetchGlobalMonitor() {
    const data = await apiRequest('monitor', 'GET');
    updateGlobalState('monitorData', data);
    globalState.lastUpdate = new Date();
}

/**
 * 获取服务状态
 */
export async function fetchServiceStatus() {
    const data = await apiRequest('status', 'GET');
    const serviceRunning = data.service === 'running';
    updateGlobalState('serviceRunning', serviceRunning);
    await fetchServiceEnabledStatus();
}

/**
 * 获取服务启用状态（从配置中）
 */
async function fetchServiceEnabledStatus() {
    const data = await apiRequest('config/get_global', 'GET');
    const enabled = data.enabled === '1';
    updateGlobalState('serviceEnabled', enabled);
}

/**
 * 切换服务状态
 * @param {boolean} enable - 是否启用服务
 */
export async function toggleServiceStatus(enable) {
    const endpoint = enable ? 'service/start' : 'service/stop';
    const data = await apiRequest(endpoint, 'POST');
    updateGlobalState('serviceEnabled', enable);
    updateGlobalState('serviceRunning', enable);
    showToast(`服务已${enable ? '启动' : '停止'}`);
}

/**
 * 更新全局状态
 * @param {string} key - 状态键名
 * @param {any} value - 新值
 */
export function updateGlobalState(key, value) {
    // 更新状态
    if (key.includes('.')) {
        // 处理嵌套属性 (如 'monitorData.cpu')
        const keys = key.split('.');
        let obj = globalState;
        for (let i = 0; i < keys.length - 1; i++) {
            obj = obj[keys[i]];
        }
        obj[keys[keys.length - 1]] = value;
    } else {
        globalState[key] = value;
    }

    // 通知订阅者
    const category = key.split('.')[0];
    if (globalState.subscribers[category]) {
        notifySubscribers(category);
    }
}

/**
 * 订阅状态变更
 * @param {string} category - 订阅类别 (monitor, config, service)
 * @param {Function} callback - 回调函数
 */
export function subscribe(category, callback) {
    if (!globalState.subscribers[category]) {
        globalState.subscribers[category] = [];
    }

    globalState.subscribers[category].push(callback);
}

/**
 * 取消订阅
 * @param {string} category - 订阅类别
 * @param {Function} callback - 回调函数
 */
export function unsubscribe(category, callback) {
    if (globalState.subscribers[category]) {
        const index = globalState.subscribers[category].indexOf(callback);
        if (index !== -1) {
            globalState.subscribers[category].splice(index, 1);
        }
    }
}

/**
 * 通知订阅者
 * @param {string} category - 订阅类别
 */
function notifySubscribers(category) {
    if (globalState.subscribers[category]) {
        const data = getStateSlice(category);
        globalState.subscribers[category].forEach(callback => {
            try {
                callback(data);
            } catch (e) {
                console.error('订阅回调执行失败:', e);
            }
        });
    }
}

/**
 * 获取状态片段
 * @param {string} category - 状态类别
 * @returns {Object} 状态片段
 */
function getStateSlice(category) {
    switch (category) {
        case 'monitor':
            return {
                ...globalState.monitorData,
                lastUpdate: globalState.lastUpdate
            };
        case 'config':
            return { ...globalState.userConfig };
        case 'service':
            return {
                enabled: globalState.serviceEnabled,
                running: globalState.serviceRunning
            };
        default:
            return {};
    }
}

/**
 * 绑定全局事件
 */
function bindGlobalEvents() {
    // 服务开关按钮
    $('#service-toggle').on('click', function () {
        toggleServiceStatus(!globalState.serviceEnabled);
    });

    // 刷新按钮
    $('#refresh-btn').on('click', function () {
        fetchGlobalMonitor();
        showToast('数据已刷新');
    });

    // 主题切换
    $(document).on('click', '[data-theme]', function () {
        const theme = $(this).data('theme');
        updateUserConfig('theme', theme);
    });

    // 刷新间隔设置
    $(document).on('change', '#refresh-interval', function () {
        const interval = parseInt($(this).val());
        if (!isNaN(interval) && interval >= 5) {
            updateUserConfig('refreshInterval', interval);
        }
    });
}

/**
 * 更新用户配置
 * @param {string} key - 配置键
 * @param {any} value - 配置值
 */
export function updateUserConfig(key, value) {
    globalState.userConfig[key] = value;
    saveUserConfig();
    showToast('配置已保存');
}

/**
 * 显示通知消息
 * @param {string} message - 消息内容
 * @param {string} type - 消息类型 (success, error, warning)
 */
export function showToast(message, type = 'success') {
    // 创建Toast元素
    const toast = $(`
        <div class="toast toast-${type}">
            <div class="toast-content">${message}</div>
        </div>
    `);

    // 添加到页面
    $('body').append(toast);

    // 显示动画
    toast.hide().fadeIn(300);

    // 3秒后移除
    setTimeout(() => {
        toast.fadeOut(300, () => toast.remove());
    }, 3000);
}

/**
 * 初始化全局监控
 */
export function initGlobalMonitor() {
    // 获取初始服务状态
    fetchServiceStatus();

    // 订阅监控更新
    subscribe('monitor', updateMonitorUI);

    // 订阅服务状态更新
    subscribe('service', updateServiceUI);
}

/**
 * 更新监控UI
 * @param {Object} data - 监控数据
 */
function updateMonitorUI(data) {
    // 更新监控栏
    if (data.cpu !== undefined) {
        $('#cpu-usage').text(`${data.cpu}%`);
        $('#cpu-usage').parent().toggleClass('warning', data.cpu > 80);
    }

    if (data.memory !== undefined) {
        $('#memory-usage').text(`${data.memory}%`);
        $('#memory-usage').parent().toggleClass('warning', data.memory > 80);
    }

    if (data.activeConnections !== undefined) {
        $('#active-connections').text(data.activeConnections);
    }

    if (data.dailyTraffic !== undefined) {
        $('#daily-traffic').text(formatBytes(data.dailyTraffic));
    }

    // 更新最后刷新时间
    if (data.lastUpdate) {
        const lastUpdate = new Date(data.lastUpdate);
        const formattedTime = lastUpdate.toLocaleTimeString('zh-CN');
        $('#last-update').text(`最后更新: ${formattedTime}`);
    }
}

/**
 * 更新服务状态UI
 * @param {Object} data - 服务状态数据
 */
function updateServiceUI(data) {
    const serviceBtn = $('#service-toggle');

    if (data.enabled && data.running) {
        serviceBtn.html('<i class="icon-power"></i> 停止服务');
        serviceBtn.removeClass('btn-secondary').addClass('btn-warning');
    } else {
        serviceBtn.html('<i class="icon-power"></i> 启动服务');
        serviceBtn.removeClass('btn-warning').addClass('btn-secondary');
    }
}

/**
 * 格式化字节大小
 * @param {number} bytes - 字节数
 * @returns {string} 格式化后的字符串
 */
export function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// 初始化全局状态
$(document).ready(() => {
    initGlobalState();
    initGlobalMonitor();
});