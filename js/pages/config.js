export const viewData = {
    config: currentConfig.global,
    interfaces: [],
    proxyServers: [
        { name: "代理服务器1", address: "socks5://106.63.10.142:11005" },
        { name: "代理服务器2", address: "socks5://192.168.1.100:1080" }
    ]
};

export const onInit = async function (componentContext) {
    // 加载配置数据
    const config = await apiRequest('config');
    if (!config.interfaces) {
        config.interfaces = [];
    }
    // 合并配置
    viewData.config = currentConfig.global;
    viewData.interfaces = config.interfaces;

    // 初始渲染
    componentContext.render();

    // 绑定事件
    bindConfigEvents();
};

window.handleAddRule = async function () {
    const newRule = {
        interface: $('#new-rule-interface').val(),
        mode: $('#new-rule-mode').val(),
        proxy_server: $('#new-rule-proxy').val(),
        enabled: $('#default-enabled').is(':checked') ? '1' : '0'
    };
    // ...
};