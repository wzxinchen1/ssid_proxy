import { showToast } from '../global.js';
import { apiRequest, showError } from '../utils.js';

let componentContext = null;
export const viewData = {
    logs: []
};

/**
 * 初始化日志页面
 * @param {Object} ctx - 组件上下文
 */
export const onInit = async function (ctx) {
    componentContext = ctx;
    // 加载日志数据
    await loadLogsData();

    // 绑定搜索表单提交事件
    document.getElementById('search-logs-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await loadLogsData();
    });
};

/**
 * 加载日志数据
 */
async function loadLogsData() {
    const level = document.getElementById('log-level').value;
    const search = document.getElementById('log-search').value.trim();

    try {
        const params = {};
        if (level !== 'all') params.level = level;
        if (search) params.search = search;

        viewData.logs = await apiRequest('logs', 'GET', null, params);
        componentContext.render();
    } catch (error) {
        showError(error.message);
    }
}

/**
 * 清除日志
 */
window.clearLogs = async function clearLogs() {
    if (confirm('确定要清除所有日志吗？')) {
        try {
            await apiRequest('logs/clear', 'POST');
            await loadLogsData();
            showToast('日志已清除');
        } catch (error) {
            showError(error.message);
        }
    }
};