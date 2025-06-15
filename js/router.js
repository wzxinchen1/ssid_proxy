/**
 * SSID代理系统 - 路由系统
 * 基于Hash的路由机制，实现单页面应用导航
 */

// 当前页面状态
let currentPage = null;
let isNavigating = false;

// 页面路由配置
const routes = {
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
function initRouter() {
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
function loadPageFromHash() {
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
function navigateTo(page) {
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
async function loadPage(page) {
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
        const htmlContent = await loadPageResources(page);

        // 渲染页面内容
        renderPage(page, htmlContent);

        // 初始化页面脚本
        if (typeof window[`init${capitalize(page)}Page`] === 'function') {
            window[`init${capitalize(page)}Page`]();
        }
        hideLoading();
    } catch (error) {
        console.error(`加载页面失败: ${page}`, error);
        showError(`加载页面失败: ${page}<br>${error.message}`, true);
    } finally {
        isNavigating = false;
    }
}

/**
 * 渲染页面内容
 * @param {string} page - 页面名称
 * @param {string} htmlContent - HTML内容
 */
function renderPage(page, htmlContent) {
    // 使用模板引擎渲染页面
    const engine = new TemplateEngine();
    const compiled = engine.compile(htmlContent);
    const rendered = engine.render(compiled, { page });

    // 添加到DOM
    $('#page-container').html(rendered);
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
async function refreshCurrentPage() {
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

/**
 * 显示错误消息
 * @param {string} message - 错误消息
 * @param {boolean} showRetry - 是否显示重试按钮
 */
function showError(message, showRetry = true) {
    $('#error-message').html(message);
    $('#retry-btn').toggle(showRetry);
    $('#error-modal').show();
}

// 暴露公共方法
window.navigateTo = navigateTo;
window.refreshCurrentPage = refreshCurrentPage;
