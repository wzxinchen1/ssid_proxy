/**
 * SSID代理系统 - 规则配置页面
 * 负责管理代理规则的配置界面逻辑
 */

// 页面初始化函数
async function initConfigPage() {
    // 绑定事件处理程序
    bindConfigEvents();

    // 加载配置数据
    await loadConfigData();

    // 订阅配置更新
    subscribe('config', handleConfigUpdate);
}

/**
 * 加载配置数据
 */
async function loadConfigData() {
    showLoading();

    try {
        const config = await apiRequest('config');
        // 确保接口列表被正确加载
        if (config.interfaces) {
            globalState.interfaces = config.interfaces.map(name => ({ name }));
        }
        renderConfig(config);
    } catch (error) {
        showError(`加载配置失败: ${error.message}`);
    }
    hideLoading();
}

/**
 * 渲染配置
 * @param {Object} config - 配置数据
 */
function renderConfig(config) {
    currentConfig = config;

    // 更新全局设置
    $('#global-enabled').prop('checked', config.global.enabled === '1');
    $('#log-level').val(config.global.log_level);
    $('#log-retention').val(config.global.log_retention);

    // 渲染规则列表
    renderRules(config.rules);
}

/**
 * 渲染规则列表
 * @param {Array} rules - 规则数组
 */
function renderRules(rules) {
    const rulesBody = $('#rules-list');
    rulesBody.empty();

    if (!Array.isArray(rules)) {
        rules = [];
    }
    if (!rules || rules.length === 0) {
        rulesBody.html(`
            <tr>
                <td colspan="5" class="no-rules">
                    <i class="icon icon-info"></i> 尚未配置任何规则
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
            <td class="rule-actions">
                <button class="action-btn delete btn-remove-rule" title="删除规则">
                    <i class="icon icon-trash"></i>
                </button>
                <button class="action-btn btn-move-up" title="上移" ${index === 0 ? 'disabled' : ''}>
                    <i class="icon icon-arrow-up"></i>
                </button>
                <button class="action-btn btn-move-down" title="下移" ${index === currentConfig.rules.length - 1 ? 'disabled' : ''}>
                    <i class="icon icon-arrow-down"></i>
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
    const interfaces = globalState.interfaces || [];
    let options = '<option value="" disabled selected>选择接口</option>';

    interfaces.forEach(iface => {
        const selected = iface.name === selectedInterface ? 'selected' : '';
        options += `<option value="${iface.name}" ${selected}>${iface.name}</option>`;
    });

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
    $(document).on('click', '#save-btn', saveConfig);
    $(document).on('click', '#reset-btn', resetConfig);

    // 高级选项切换
    $(document).on('click', '#adv-toggle', toggleAdvancedOptions);
}

/**
 * 添加新规则
 */
function addNewRule() {
    const newRule = {
        enabled: $('#default-enabled').is(':checked') ? '1' : '0',
        interface: $('#new-rule-interface').val(),
        mode: $('#new-rule-mode').val(),
        proxy_server: $('#new-rule-mode').val() === 'proxy' ? $('#new-rule-proxy').val() : ''
    };

    if (!newRule.interface) {
        showError('请选择网络接口');
        return;
    }

    if (newRule.mode === 'proxy' && !newRule.proxy_server) {
        showError('请填写代理服务器地址');
        return;
    }

    // 添加到当前配置
    if ($('#rule-order').val() === 'top') {
        currentConfig.rules.unshift(newRule);
    } else {
        currentConfig.rules.push(newRule);
    }

    // 重新渲染规则列表
    renderRules(currentConfig.rules);

    // 重置表单
    $('#new-rule-proxy').val('');
}

/**
 * 删除规则
 */
function removeRule() {
    const row = $(this).closest('tr');
    const index = row.data('index');

    if (confirm('确定要删除此规则吗？')) {
        currentConfig.rules.splice(index, 1);
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
    currentConfig.rules[index].enabled = isEnabled ? '1' : '0';
}

/**
 * 更新规则模式
 */
function updateRuleMode() {
    const row = $(this).closest('tr');
    const index = row.data('index');
    const mode = $(this).val();
    currentConfig.rules[index].mode = mode;

    const proxyInput = row.find('.rule-proxy');
    if (mode === 'proxy') {
        proxyInput.prop('disabled', false);
    } else {
        proxyInput.prop('disabled', true);
        currentConfig.rules[index].proxy_server = '';
    }
}

/**
 * 上移规则
 */
function moveRuleUp() {
    const row = $(this).closest('tr');
    const index = row.data('index');

    if (index > 0) {
        [currentConfig.rules[index], currentConfig.rules[index - 1]] =
            [currentConfig.rules[index - 1], currentConfig.rules[index]];
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
        [currentConfig.rules[index], currentConfig.rules[index + 1]] =
            [currentConfig.rules[index + 1], currentConfig.rules[index]];
        renderRules(currentConfig.rules);
    }
}

/**
 * 保存配置
 */
async function saveConfig() {
    collectFormData();

    showLoading();

    try {
        await apiRequest('config', 'POST', {
            config: currentConfig,
            apply: true
        });
        showToast('配置保存并应用成功');
    } catch (error) {
        showError(`保存配置失败: ${error.message}`);
    }
    hideLoading();
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
    currentConfig.global.enabled = $('#global-enabled').is(':checked') ? '1' : '0';
    currentConfig.global.log_level = $('#log-level').val();
    currentConfig.global.log_retention = $('#log-retention').val();

    $('#rules-list tr').each(function () {
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
 * 切换高级选项显示
 */
function toggleAdvancedOptions() {
    $(this).toggleClass('active');
    $('.adv-content').slideToggle();
}

/**
 * 处理配置更新
 */
function handleConfigUpdate(config) {
    if (config.theme) {
        document.documentElement.setAttribute('data-theme', config.theme);
    }
}

// 当前配置数据
let currentConfig = {};

// 页面初始化
$(document).ready(async () => {
    if ($('#page-container').length) {
        await initConfigPage();
    }
});