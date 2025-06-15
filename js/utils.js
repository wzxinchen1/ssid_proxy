/**
 * SSID代理系统 - 实用工具函数库
 * 基于jQuery实现，提供项目核心功能所需的工具函数
 */

// 资源加载状态跟踪
const loadedResources = {
    css: {},
    js: {}
};

/**
 * 动态加载CSS文件
 * @param {string} url - CSS文件路径
 * @param {string} page - 页面名称（用于标识）
 */
function loadCSS(url, page) {
    return new Promise((resolve, reject) => {
        // 检查是否已加载
        if (loadedResources.css[url]) {
            resolve();
            return;
        }
        
        // 创建link元素
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = url;
        link.onload = () => {
            loadedResources.css[url] = true;
            resolve();
        };
        link.onerror = () => {
            console.error(`Failed to load CSS: ${url}`);
            reject(new Error(`CSS加载失败: ${url}`));
        };
        
        // 添加到文档头部
        document.head.appendChild(link);
    });
}

/**
 * 动态加载JavaScript文件
 * @param {string} url - JS文件路径
 * @param {string} page - 页面名称（用于标识）
 */
function loadJS(url, page) {
    return new Promise((resolve, reject) => {
        // 检查是否已加载
        if (loadedResources.js[url]) {
            resolve();
            return;
        }
        
        // 创建script元素
        const script = document.createElement('script');
        script.src = url;
        script.onload = () => {
            loadedResources.js[url] = true;
            resolve();
        };
        script.onerror = () => {
            console.error(`Failed to load JS: ${url}`);
            reject(new Error(`JavaScript加载失败: ${url}`));
        };
        
        // 添加到文档尾部
        document.body.appendChild(script);
    });
}

/**
 * 加载页面资源（HTML、CSS、JS）
 * @param {string} page - 页面名称
 */
function loadPageResources(page) {
    const basePath = `pages/${page}`;
    
    return new Promise((resolve, reject) => {
        // 1. 加载HTML内容
        $.get(`${basePath}.html`)
            .then(htmlContent => {
                // 2. 加载CSS
                return loadCSS(`css/pages/${page}.css`, page)
                    .then(() => htmlContent);
            })
            .then(htmlContent => {
                // 3. 加载JS
                return loadJS(`js/pages/${page}.js`, page)
                    .then(() => htmlContent);
            })
            .then(htmlContent => {
                resolve(htmlContent);
            })
            .catch(error => {
                console.error(`加载页面资源失败: ${page}`, error);
                reject(error);
            });
    });
}

/**
 * 安全转义HTML内容（防止XSS攻击）
 * @param {string} str - 需要转义的字符串
 * @returns {string} 转义后的安全字符串
 */
function escapeHTML(str) {
    if (!str) return '';
    return str.toString()
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

/**
 * 格式化字节大小为易读格式
 * @param {number} bytes - 字节大小
 * @param {number} decimals - 保留小数位数
 * @returns {string} 格式化后的字符串
 */
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

/**
 * 格式化时间戳为易读格式
 * @param {number|string} timestamp - 时间戳
 * @returns {string} 格式化后的时间字符串
 */
function formatTime(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

/**
 * 防抖函数
 * @param {Function} func - 需要防抖的函数
 * @param {number} wait - 等待时间(毫秒)
 * @returns {Function} 防抖处理后的函数
 */
function debounce(func, wait = 300) {
    let timeout;
    return function() {
        const context = this;
        const args = arguments;
        clearTimeout(timeout);
        timeout = setTimeout(() => {
            func.apply(context, args);
        }, wait);
    };
}

/**
 * 复制文本到剪贴板
 * @param {string} text - 需要复制的文本
 * @returns {Promise} 复制操作的结果
 */
function copyToClipboard(text) {
    return new Promise((resolve, reject) => {
        // 创建临时textarea元素
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'absolute';
        textarea.style.left = '-9999px';
        document.body.appendChild(textarea);
        
        // 选择并复制文本
        textarea.select();
        try {
            const successful = document.execCommand('copy');
            document.body.removeChild(textarea);
            successful ? resolve() : reject(new Error('复制失败'));
        } catch (err) {
            document.body.removeChild(textarea);
            reject(err);
        }
    });
}

/**
 * 显示加载状态
 * @param {string} selector - 可选，指定在哪个容器内显示加载状态
 */
function showLoading(selector = '#page-container') {
    // 创建或更新加载状态元素
    let loadingElement = $(selector).find('.loading-overlay');
    
    if (loadingElement.length === 0) {
        loadingElement = $(`
            <div class="loading-overlay">
                <div class="loading-spinner"></div>
                <p>正在加载数据...</p>
            </div>
        `);
        $(selector).append(loadingElement);
    }
    
    loadingElement.show();
}

/**
 * 隐藏加载状态
 * @param {string} selector - 可选，指定在哪个容器内隐藏加载状态
 */
function hideLoading(selector = '#page-container') {
    $(selector).find('.loading-overlay').hide();
}

/**
 * 显示错误消息
 * @param {string} message - 错误消息
 * @param {boolean} showRetry - 是否显示重试按钮
 */
function showError(message, showRetry = true) {
    $('#error-message').text(message);
    $('#retry-btn').toggle(showRetry);
    $('#error-modal').show();
}

/**
 * 更新全局监控数据
 * @param {Object} data - 监控数据
 */
function updateGlobalMonitor(data) {
    if (data.cpu) {
        $('#cpu-usage').text(`${data.cpu}%`);
    }
    if (data.memory) {
        $('#memory-usage').text(`${data.memory}%`);
    }
    if (data.activeConnections) {
        $('#active-connections').text(data.activeConnections);
    }
    if (data.dailyTraffic) {
        $('#daily-traffic').text(formatBytes(data.dailyTraffic));
    }
    
    // 更新服务状态按钮
    const serviceBtn = $('#service-toggle');
    if (data.serviceEnabled) {
        serviceBtn.html('<i class="icon-power"></i> 停止服务');
        serviceBtn.toggleClass('btn-warning', true);
    } else {
        serviceBtn.html('<i class="icon-power"></i> 启动服务');
        serviceBtn.toggleClass('btn-warning', false);
    }
}

/**
 * 切换服务状态
 */
function toggleServiceStatus() {
    const isEnabled = $('#service-toggle').hasClass('btn-warning');
    const action = isEnabled ? 'stop' : 'start';
    
    showLoading();
    
    $.post(`/api/service/${action}`)
        .then(response => {
            if (response.success) {
                // 更新UI状态
                updateGlobalMonitor({
                    serviceEnabled: !isEnabled
                });
            } else {
                showError(`服务${isEnabled ? '停止' : '启动'}失败: ${response.message}`);
            }
        })
        .catch(error => {
            console.error('服务状态切换失败:', error);
            showError(`服务${isEnabled ? '停止' : '启动'}失败: ${error.statusText}`);
        });
}

/**
 * 发起API请求
 * @param {string} endpoint - API端点
 * @param {string} method - HTTP方法 (GET, POST等)
 * @param {Object} data - 请求数据
 * @returns {Promise} API响应
 */
function apiRequest(endpoint, method = 'GET', data = null) {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: `/cgi-bin/luci/api/${endpoint}`,
            method: method,
            data: method === 'GET' ? data : JSON.stringify(data),
            contentType: 'application/json',
            dataType: 'json'
        })
        .done(response => {
            if (response.success) {
                resolve(response.data);
            } else {
                reject(new Error(response.message || 'API请求失败'));
            }
        })
        .fail((xhr, status, error) => {
            reject(new Error(`API请求错误: ${status} - ${error}`));
        });
    });
}

/**
 * 初始化工具函数
 */
function initUtils() {
    // 绑定全局错误处理
    $(document).ajaxError((event, jqxhr, settings, thrownError) => {
        if (settings.url.startsWith('/api/')) {
            showError(`API请求失败: ${thrownError || jqxhr.statusText}`);
        }
    });
}

// 初始化工具函数
$(document).ready(initUtils);
