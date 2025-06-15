/**
 * SSID代理系统 - 规则配置页面
 * 负责管理代理规则的配置界面逻辑
 */

// 页面初始化函数
function initConfigPage() {
    // 加载配置数据
    loadConfigData();
    
    // 绑定事件处理程序
    bindConfigEvents();
    
    // 订阅配置更新
    subscribe('config', handleConfigUpdate);
}

/**
 * 加载配置数据
 */
function loadConfigData() {
    showLoading();
    
    apiRequest('config')
        .then(config => {
            renderConfigPage(config);
        })
        .catch(error => {
            showError(`加载配置失败: ${error.message}`);
        });
}

/**
 * 渲染配置页面
 * @param {Object} config - 配置数据
 */
function renderConfigPage(config) {
    const html = `
        <div class="config-container">
            <div class="config-section">
                <h2><i class="icon-globe"></i> 全局设置</h2>
                <div class="form-group">
                    <label>
                        <input type="checkbox" id="global-enabled" 
                               ${config.global.enabled === '1' ? 'checked' : ''}>
                        启用接口代理
                    </label>
                    <p class="form-hint">启用后，所有配置的代理规则将生效</p>
                </div>
                
                <div class="form-group">
                    <label>日志级别</label>
                    <select id="log-level">
                        <option value="error" ${config.global.log_level === 'error' ? 'selected' : ''}>错误</option>
                        <option value="warning" ${config.global.log_level === 'warning' ? 'selected' : ''}>警告</option>
                        <option value="info" ${config.global.log_level === 'info' ? 'selected' : ''}>信息</option>
                        <option value="debug" ${config.global.log_level === 'debug' ? 'selected' : ''}>调试</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>日志保留时间</label>
                    <select id="log-retention">
                        <option value="3" ${config.global.log_retention === '3' ? 'selected' : ''}>3天</option>
                        <option value="7" ${config.global.log_retention === '7' ? 'selected' : ''}>7天</option>
                        <option value="14" ${config.global.log_retention === '14' ? 'selected' : ''}>14天</option>
                        <option value="30" ${config.global.log_retention === '30' ? 'selected' : ''}>30天</option>
                    </select>
                </div>
            </div>
            
            <div class="config-section">
                <div class="section-header">
                    <h2><i class="icon-list"></i> 代理规则</h2>
                    <button id="add-rule-btn" class="btn-primary">
                        <i class="icon-plus"></i> 添加规则
                    </button>
                </div>
                
                <div class="rules-container">
                    <table class="rules-table">
                        <thead>
                            <tr>
                                <th width="5%">状态</th>
                                <th width="25%">网络接口</th>
                                <th width="15%">操作模式</th>
                                <th width="40%">代理服务器</th>
                                <th width="15%">操作</th>
                            </tr>
                        </thead>
                        <tbody id="rules-body">
                            <!-- 规则将通过JS动态添加 -->
                        </tbody>
                    </table>
                </div>
            </div>
            
            <div class="form-actions">
                <button id="save-config-btn" class="btn-primary">
                    <i class="icon-save"></i> 保存配置
                </button>
                <button id="apply-config-btn" class="btn-success">
                    <i class="icon-check"></i> 保存并应用
                </button>
                <button id="reset-config-btn" class="btn-secondary">
                    <i class="icon-undo"></i> 重置
                </button>
            </div>
        </div>
    `;
    
    $('#page-container').html(html);
    renderRules(config.rules);
}

/**
 * 渲染规则列表
 * @param {Array} rules - 规则数组
 */
function renderRules(rules) {
    const rulesBody = $('#rules-body');
    rulesBody.empty();
    
    if (!rules || rules.length === 0) {
        rulesBody.html(`
            <tr>
                <td colspan="5" class="no-rules">
                    <i class="icon-info"></i> 尚未配置任何规则
                </td>
            </tr>
        `);
        return;
    }
    
    rules.forEach((rule, index) => {
        const row = createRuleRow(rule, index);
        rulesBody.append(row);
    });
}

/**
 * 创建规则行HTML
 * @param {Object} rule - 规则对象
 * @param {number} index - 规则索引
 * @returns {string} 规则行HTML
 */
function createRuleRow(rule, index) {
    const isEnabled = rule.enabled === '1';
    const isProxyMode = rule.mode === 'proxy';
    
    return `
        <tr data-index="${index}">
            <td>
                <label class="switch">
                    <input type="checkbox" class="rule-enabled" ${isEnabled ? 'checked' : ''}>
                    <span class="slider"></span>
                </label>
            </td>
            <td>
                <select class="rule-interface">
                    ${getInterfaceOptions(rule.interface)}
                </select>
            </td>
            <td>
                <select class="rule-mode">
                    <option value="direct" ${rule.mode === 'direct' ? 'selected' : ''}>直连</option>
                    <option value="proxy" ${rule.mode === 'proxy' ? 'selected' : ''}>代理</option>
                    <option value="block" ${rule.mode === 'block' ? 'selected' : ''}>阻止</option>
                </select>
            </td>
            <td>
                <input type="text" class="rule-proxy" 
                       placeholder="socks5://ip:port" 
                       value="${isProxyMode ? escapeHTML(rule.proxy_server || '') : ''}"
                       ${isProxyMode ? '' : 'disabled'}>
            </td>
            <td>
                <button class="btn-icon btn-remove-rule" title="删除规则">
                    <i class="icon-trash"></i>
                </button>
                <button class="btn-icon btn-move-up" title="上移" ${index === 0 ? 'disabled' : ''}>
                    <i class="icon-arrow-up"></i>
                </button>
                <button class="btn-icon btn-move-down" title="下移" ${index === currentConfig.rules.length - 1 ? 'disabled' : ''}>
                    <i class="icon-arrow-down"></i>
                </button>
            </td>
        </tr>
    `;
}

/**
 * 获取接口选项HTML
 * @param {string} selectedInterface - 当前选中的接口
 * @returns {string} 选项HTML
 */
function getInterfaceOptions(selectedInterface) {
    // 从全局状态获取接口列表
    const interfaces = globalState.monitorData.interfaces || [];
    
    let options = '';
    interfaces.forEach(iface => {
        const selected = iface.name === selectedInterface ? 'selected' : '';
        options += `<option value="${iface.name}" ${selected}>${iface.name}</option>`;
    });
    
    // 添加默认选项
    if (!selectedInterface || !interfaces.some(i => i.name === selectedInterface)) {
        options += `<option value="${selectedInterface}" selected>${selectedInterface}</option>`;
    }
    
    return options;
}

/**
 * 绑定配置页面事件
 */
function bindConfigEvents() {
    // 添加规则按钮
    $(document).on('click', '#add-rule-btn', addNewRule);
    
    // 删除规则按钮
    $(document).on('click', '.btn-remove-rule', removeRule);
    
    // 规则启用开关
    $(document).on('change', '.rule-enabled', toggleRuleStatus);
    
    // 规则模式切换
    $(document).on('change', '.rule-mode', updateRuleMode);
    
    // 规则移动按钮
    $(document).on('click', '.btn-move-up', moveRuleUp);
    $(document).on('click', '.btn-move-down', moveRuleDown);
    
    // 保存按钮
    $(document).on('click', '#save-config-btn', saveConfig);
    $(document).on('click', '#apply-config-btn', applyConfig);
    $(document).on('click', '#reset-config-btn', resetConfig);
}

/**
 * 添加新规则
 */
function addNewRule() {
    // 创建新规则对象
    const newRule = {
        enabled: '1',
        interface: 'br-lan',
        mode: 'proxy',
        proxy_server: 'socks5://127.0.0.1:1080'
    };
    
    // 添加到当前配置
    currentConfig.rules.push(newRule);
    
    // 重新渲染规则列表
    renderRules(currentConfig.rules);
    
    // 滚动到新规则
    const lastRow = $('#rules-body tr:last');
    $('html, body').animate({
        scrollTop: lastRow.offset().top - 100
    }, 300);
}

/**
 * 删除规则
 */
function removeRule() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    
    if (confirm('确定要删除此规则吗？')) {
        // 从规则数组中移除
        currentConfig.rules.splice(index, 1);
        
        // 重新渲染规则列表
        renderRules(currentConfig.rules);
    }
}

/**
 * 切换规则状态
 */
function toggleRuleStatus() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    const isEnabled = $(this).is(':checked');
    
    // 更新规则状态
    currentConfig.rules[index].enabled = isEnabled ? '1' : '0';
}

/**
 * 更新规则模式
 */
function updateRuleMode() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    const mode = $(this).val();
    
    // 更新规则模式
    currentConfig.rules[index].mode = mode;
    
    // 更新代理服务器输入框状态
    const proxyInput = row.find('.rule-proxy');
    if (mode === 'proxy') {
        proxyInput.prop('disabled', false);
    } else {
        proxyInput.prop('disabled', true);
    }
}

/**
 * 上移规则
 */
function moveRuleUp() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    
    if (index > 0) {
        // 交换规则位置
        [currentConfig.rules[index], currentConfig.rules[index - 1]] = 
        [currentConfig.rules[index - 1], currentConfig.rules[index]];
        
        // 重新渲染规则列表
        renderRules(currentConfig.rules);
    }
}

/**
 * 下移规则
 */
function moveRuleDown() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    
    if (index < currentConfig.rules.length - 1) {
        // 交换规则位置
        [currentConfig.rules[index], currentConfig.rules[index + 1]] = 
        [currentConfig.rules[index + 1], currentConfig.rules[index]];
        
        // 重新渲染规则列表
        renderRules(currentConfig.rules);
    }
}

/**
 * 保存配置
 */
function saveConfig() {
    // 收集表单数据
    collectFormData();
    
    // 发送保存请求
    saveConfigToBackend(false);
}

/**
 * 保存并应用配置
 */
function applyConfig() {
    // 收集表单数据
    collectFormData();
    
    // 发送保存请求
    saveConfigToBackend(true);
}

/**
 * 重置配置
 */
function resetConfig() {
    if (confirm('确定要放弃所有更改并重置配置吗？')) {
        loadConfigData();
    }
}

/**
 * 收集表单数据
 */
function collectFormData() {
    // 全局设置
    currentConfig.global.enabled = $('#global-enabled').is(':checked') ? '1' : '0';
    currentConfig.global.log_level = $('#log-level').val();
    currentConfig.global.log_retention = $('#log-retention').val();
    
    // 收集规则数据
    $('#rules-body tr').each(function() {
        const index = $(this).data('index');
        const rule = currentConfig.rules[index];
        
        rule.interface = $(this).find('.rule-interface').val();
        rule.mode = $(this).find('.rule-mode').val();
        
        if (rule.mode === 'proxy') {
            rule.proxy_server = $(this).find('.rule-proxy').val();
        } else {
            rule.proxy_server = '';
        }
    });
}

/**
 * 保存配置到后端
 * @param {boolean} apply - 是否应用配置
 */
function saveConfigToBackend(apply) {
    showLoading();
    
    const data = {
        config: currentConfig,
        apply: apply
    };
    
    apiRequest('config', 'POST', data)
        .then(response => {
            showToast('配置保存成功');
            
            if (apply) {
                showToast('配置已应用');
            }
        })
        .catch(error => {
            showError(`保存配置失败: ${error.message}`, 'error');
        });
}

/**
 * 处理配置更新
 * @param {Object} config - 新的配置数据
 */
function handleConfigUpdate(config) {
    // 更新主题
    if (config.theme) {
        document.documentElement.setAttribute('data-theme', config.theme);
    }
    
    // 更新刷新间隔
    if (config.refreshInterval) {
        // 如果当前页面是配置页，更新UI
        if ($('#refresh-interval').length) {
            $('#refresh-interval').val(config.refreshInterval);
        }
    }
}

// 当前配置数据
let currentConfig = {};

// 页面初始化
$(document).ready(() => {
    // 确保在配置页面才初始化
    if ($('#page-container').length) {
        initConfigPage();
    }
});
