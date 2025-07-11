/**
 * SSID代理系统 - 路由系统
 * 基于Hash的路由机制，实现单页面应用导航
 */

import { showError, showLoading, hideLoading, loadPageResources } from './utils.js';
import { Template } from './template.js';

// 当前页面状态
let currentPage = null;
let isNavigating = false;

// 页面路由配置
export const routes = {
    'status': {
        title: '状态监控',
        resources: ['status']
    },
    'config': {
        title: '规则配置',
        resources: ['config']
    },
    'logs': {
        title: '日志查看',
        resources: ['logs']
    },
    'monitor': {
        title: '高级监控',
        resources: ['monitor']
    },
    'nodes': {
        title: '服务器节点',
        resources: ['nodes']
    }
};

// 默认路由
const DEFAULT_ROUTE = 'status';

/**
 * 初始化路由系统
 */
export function initRouter() {
    // 监听hash变化
    $(window).on('hashchange', handleHashChange);

    // 绑定导航链接点击事件
    $('.nav-link').on('click', function (e) {
        e.preventDefault();
        const page = $(this).attr('href').substring(1);
        navigateTo(page);
    });

    // 初始加载页面
    loadPageFromHash();
}

/**
 * 处理hash变化事件
 */
function handleHashChange() {
    if (isNavigating) return;
    loadPageFromHash();
}

/**
 * 从当前hash加载页面
 */
export function loadPageFromHash() {
    const hash = window.location.hash.substring(1);
    const page = hash || DEFAULT_ROUTE;

    if (routes[page]) {
        loadPage(page);
    } else {
        // 无效路由，跳转到默认页面
        navigateTo(DEFAULT_ROUTE);
    }
}

/**
 * 导航到指定页面
 * @param {string} page - 目标页面名称
 */
export function navigateTo(page) {
    if (isNavigating || page === currentPage) return;

    // 更新URL hash
    window.location.hash = page;

    // 如果hash变化未触发页面加载，则手动加载
    if (window.location.hash.substring(1) === page) {
        loadPage(page);
    }
}

/**
 * 加载并显示指定页面
 * @param {string} page - 页面名称
 */
export async function loadPage(page) {
    if (currentPage == page) {
        return;
    }
    if (!routes[page]) {
        console.error(`未知页面: ${page}`);
        showError(`页面不存在: ${page}`);
        return;
    }

    // 设置导航状态
    isNavigating = true;
    currentPage = page;

    try {
        // 更新UI状态
        updateNavigationUI(page);
        document.title = `SSID代理系统 - ${routes[page].title}`;

        // 显示加载状态
        showLoading();

        // 加载页面资源
        const { htmlContent, module } = await loadPageResources(page);

        // 渲染页面内容
        renderPage(page, htmlContent, module);


        hideLoading();
    } finally {
        isNavigating = false;
    }
}

/**
 * 渲染页面内容
 * @param {string} page - 页面名称
 * @param {string} htmlContent - HTML内容
 */
function renderPage(page, htmlContent, module) {
    // 使用模板引擎渲染页面
    const engine = new Template(htmlContent, module);
    const rendered = engine.render();

    // 添加到DOM
    $('#page-container').html(rendered);

    // 初始化页面脚本
    if (typeof module[`onInit`] === 'function') {
        if (window.runningComponentContext) {
            window.runningComponentContext.running = false;
        }
        const componentContext = {
            running: true,
            render: (data) => {
                const rendered = engine.render();
                $('#page-container').html(rendered);
            }
        };
        module[`onInit`](componentContext);
        window.runningComponentContext = componentContext;
    }
}

/**
 * 更新导航UI状态
 * @param {string} activePage - 当前活动页面
 */
function updateNavigationUI(activePage) {
    // 更新导航链接状态
    $('.nav-link').removeClass('active');
    $(`.nav-link[href="#${activePage}"]`).addClass('active');

    // 更新页面标题
    $('.app-content h1').text(routes[activePage].title);
}

/**
 * 刷新当前页面
 */
export async function refreshCurrentPage() {
    if (!currentPage) return;

    try {
        // 清除已加载资源状态
        const pageResources = routes[currentPage].resources || [];
        pageResources.forEach(resource => {
            const cssPath = `css/pages/${resource}.css`;
            const jsPath = `js/pages/${resource}.js`;

            if (loadedResources.css[cssPath]) {
                delete loadedResources.css[cssPath];
                $(`link[href="${cssPath}"]`).remove();
            }

            if (loadedResources.js[jsPath]) {
                delete loadedResources.js[jsPath];
                $(`script[src="${jsPath}"]`).remove();
            }
        });

        // 重新加载页面
        await loadPage(currentPage);
    } catch (error) {
        console.error('刷新页面失败:', error);
        showError('刷新页面失败', true);
    }
}

/**
 * 首字母大写
 * @param {string} str - 输入字符串
 * @returns {string} 首字母大写的字符串
 */
function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

// 暴露公共方法
window.navigateTo = navigateTo;
window.refreshCurrentPage = refreshCurrentPage;