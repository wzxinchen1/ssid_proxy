/**
 * SSID代理系统 - 状态页面逻辑 (SPA优化版)
 * 文件路径: /js/pages/status.js
 * 功能: 实现状态页面的数据加载、渲染和交互逻辑
 */

import { showToast, formatBytes } from '../global.js';
import { apiRequest, showError } from "../utils.js"

// 页面状态对象
export const viewData={

}

let componentContext;
// 页面初始化函数 (SPA适配)
export const onInit= function(ctx) {
    componentContext=ctx;
}

// 页面卸载函数 (SPA适配)
export function cleanupStatusPage() {
    console.log("清理状态页面资源");

    // 清除自动刷新定时器
    if (statusPageState.refreshInterval) {
        clearInterval(statusPageState.refreshInterval);
        statusPageState.refreshInterval = null;
    }
}

// 刷新状态数据
function refreshStatusData() {
    console.log("刷新状态数据");

    // 同时请求服务状态和监控数据
    Promise.all([
        fetchServiceStatus(),
        fetchMonitorData()
    ])
        .then(([statusData, monitorData]) => {
            // 更新服务状态
            updateServiceStatus(statusData);

            // 更新系统资源
            updateSystemResources(monitorData);

            // 更新接口状态
            updateInterfaces(monitorData.interfaces);

            // 更新活跃连接
            updateActiveConnections(monitorData.connections);
        })
        .catch(error => {
            console.error("加载状态数据失败:", error);
            showError("加载状态数据失败，请重试", true);
        })
}

// 获取服务状态
function fetchServiceStatus() {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: '/cgi-bin/luci/api/status',
            method: 'GET',
            dataType: 'json',
            success: function (response) {
                if (response.success) {
                    resolve(response.data);
                } else {
                    reject(new Error(response.error || "获取服务状态失败"));
                }
            },
            error: function (xhr, status, error) {
                reject(new Error("服务状态请求失败: " + error));
            }
        });
    });
}

// 获取监控数据
function fetchMonitorData() {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: '/cgi-bin/luci/api/monitor',
            method: 'GET',
            dataType: 'json',
            success: function (response) {
                if (response.success) {
                    resolve(response.data);
                } else {
                    reject(new Error(response.error || "获取监控数据失败"));
                }
            },
            error: function (xhr, status, error) {
                reject(new Error("监控数据请求失败: " + error));
            }
        });
    });
}

// 更新服务状态
function updateServiceStatus(data) {
    // 更新服务状态指示器
    const indicator = $('#service-indicator');
    indicator.removeClass('running stopped');

    if (data.service === 'running') {
        indicator.addClass('running').find('span').text('运行中');
    } else {
        indicator.addClass('stopped').find('span').text('已停止');
    }

    // 更新服务信息
    $('#service-status').text(data.service === 'running' ? '运行中' : '已停止');
    $('#service-uptime').text(data.uptime);
    $('#service-version').text(data.version);

    // 更新最后刷新时间
    const now = new Date();
    $('#last-update').text(`最后更新: ${now.toLocaleTimeString('zh-CN')}`);

    // 更新服务按钮
    const serviceBtn = $('#service-toggle');
    if (data.service === 'running') {
        serviceBtn.html('<i class="icon icon-power"></i> 停止服务');
        serviceBtn.removeClass('btn-secondary').addClass('btn-warning');
    } else {
        serviceBtn.html('<i class="icon icon-power"></i> 启动服务');
        serviceBtn.removeClass('btn-warning').addClass('btn-secondary');
    }
}

// 更新系统资源
function updateSystemResources(data) {
    // CPU使用率
    const cpuUsage = data.cpu || 0;
    $('#cpu-usage').text(`${cpuUsage}%`);
    $('#cpu-gauge').css('width', `${cpuUsage}%`);
    $('#cpu-gauge').toggleClass('warning', cpuUsage > 80);

    // 内存使用
    const memUsage = data.memory || 0;
    $('#memory-usage').text(`${memUsage}%`);
    $('#memory-gauge').css('width', `${memUsage}%`);
    $('#memory-gauge').toggleClass('warning', memUsage > 80);

    // 活跃连接
    const activeConnections = data.active_connections || 0;
    $('#active-connections').text(activeConnections);

    // 今日流量
    const dailyTraffic = data.daily_traffic || 0;
    $('#daily-traffic').text(formatBytes(dailyTraffic));
}

// 更新接口状态
function updateInterfaces(interfaces) {
    const tableBody = $('#interfaces-list');
    tableBody.empty();

    if (!interfaces || interfaces.length === 0) {
        tableBody.append(`
            <tr>
                <td colspan="6" class="empty-row">
                    <i class="icon icon-info"></i> 未找到网络接口
                </td>
            </tr>
        `);
        return;
    }

    interfaces.forEach(iface => {
        // 确定接口类型
        let typeClass = 'ethernet';
        let typeText = '有线';

        if (iface.type === 'wireless') {
            typeClass = 'wireless';
            typeText = '无线';
        } else if (iface.type === 'bridge') {
            typeClass = 'bridge';
            typeText = '网桥';
        } else if (iface.type === 'vlan') {
            typeClass = 'vlan';
            typeText = 'VLAN';
        }

        tableBody.append(`
            <tr>
                <td>${iface.name}</td>
                <td>
                    <span class="interface-status ${iface.status}">
                        ${iface.status === 'up' ? '在线' : '离线'}
                    </span>
                </td>
                <td>${iface.ip || 'N/A'}</td>
                <td>
                    <span class="interface-type ${typeClass}">
                        ${typeText}
                    </span>
                </td>
                <td>${iface.clients || 0}</td>
                <td>${formatBytes(iface.traffic || 0)}</td>
            </tr>
        `);
    });
}

// 更新活跃连接
function updateActiveConnections(connections) {
    // 保存当前连接数据用于过滤
    if (Array.isArray(connections)) {
        statusPageState.currentConnections = connections;
    }

    // 应用当前过滤器
    filterConnections(statusPageState.currentFilter);
}

// 设置自动刷新
function setupAutoRefresh() {
    // 清除现有定时器
    if (statusPageState.refreshInterval) {
        clearInterval(statusPageState.refreshInterval);
    }

    // 每30秒自动刷新一次
    statusPageState.refreshInterval = setInterval(() => {
        if ($('#auto-refresh').is(':checked')) {
            refreshStatusData();
        }
    }, 30000);
}

// 绑定事件监听器
function bindEventListeners() {
    // 刷新按钮
    $('#refresh-status').on('click', function () {
        refreshStatusData();
        showToast('状态数据已刷新');
    });

    // 服务开关按钮
    $('#service-toggle').on('click', function () {
        const isRunning = $('#service-indicator').hasClass('running');
        toggleServiceStatus(!isRunning);
    });

    // 接口折叠按钮
    $('#collapse-interfaces').on('click', function () {
        const $icon = $(this).find('.icon');
        const $table = $('.interfaces-table');

        if ($icon.hasClass('icon-arrow-up')) {
            $icon.removeClass('icon-arrow-up').addClass('icon-arrow-down');
            $table.hide();
        } else {
            $icon.removeClass('icon-arrow-down').addClass('icon-arrow-up');
            $table.show();
        }
    });

    // 连接过滤
    $('#connection-filter').on('input', function () {
        statusPageState.currentFilter = $(this).val().toLowerCase();
        filterConnections(statusPageState.currentFilter);
    });

    // 时间范围选择
    $('#traffic-period').on('change', function () {
        loadTrafficData($(this).val());
    });
}

// 过滤连接
function filterConnections(filter) {
    const tableBody = $('#connections-list');
    tableBody.empty();

    if (!statusPageState.currentConnections || statusPageState.currentConnections.length === 0) {
        tableBody.append(`
            <tr>
                <td colspan="8" class="empty-row">
                    <i class="icon icon-info"></i> 未找到活跃连接
                </td>
            </tr>
        `);
        return;
    }

    // 统计协议类型
    let tcpCount = 0;
    let udpCount = 0;
    let visibleCount = 0;

    statusPageState.currentConnections.forEach(conn => {
        // 应用过滤器
        const connText = `${conn.src}${conn.dst}${conn.dport}${conn.protocol}${conn.interface}`.toLowerCase();
        if (filter && !connText.includes(filter)) return;

        // 统计协议
        if (conn.protocol === 'TCP') tcpCount++;
        if (conn.protocol === 'UDP') udpCount++;
        visibleCount++;

        // 格式化持续时间
        const duration = formatDuration(conn.duration);

        // 格式化流量
        const trafficIn = formatBytes(conn.bytes_in || 0);
        const trafficOut = formatBytes(conn.bytes_out || 0);

        tableBody.append(`
            <tr>
                <td>${conn.src || 'N/A'}</td>
                <td>${conn.dst || 'N/A'}</td>
                <td>${conn.dport || 'N/A'}</td>
                <td>${conn.protocol || 'N/A'}</td>
                <td>${conn.interface || 'N/A'}</td>
                <td>${duration}</td>
                <td>${trafficIn}</td>
                <td>${trafficOut}</td>
            </tr>
        `);
    });

    if (visibleCount === 0) {
        tableBody.append(`
            <tr>
                <td colspan="8" class="empty-row">
                    <i class="icon icon-info"></i> 未找到匹配的连接
                </td>
            </tr>
        `);
    }

    // 更新协议统计
    $('#tcp-connections').text(tcpCount);
    $('#udp-connections').text(udpCount);
    $('#total-connections').text(statusPageState.currentConnections.length);
    $('#shown-connections').text(visibleCount);
}

// 格式化持续时间 (状态页面专用)
function formatDuration(seconds) {
    if (!seconds) return '0s';

    const days = Math.floor(seconds / (24 * 3600));
    seconds %= 24 * 3600;
    const hours = Math.floor(seconds / 3600);
    seconds %= 3600;
    const minutes = Math.floor(seconds / 60);
    seconds %= 60;

    const parts = [];
    if (days > 0) parts.push(`${days}d`);
    if (hours > 0) parts.push(`${hours}h`);
    if (minutes > 0) parts.push(`${minutes}m`);
    if (seconds > 0 || parts.length === 0) parts.push(`${seconds}s`);

    return parts.join(' ');
}