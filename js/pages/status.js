/**
 * SSID代理系统 - 状态页面逻辑 (SPA优化版)
 * 文件路径: /js/pages/status.js
 * 功能: 实现状态页面的数据加载、渲染和交互逻辑
 */

import { apiRequest, showError } from "../utils.js"

// 页面状态对象
export const viewData = {
}

let componentContext;

// 页面初始化函数 (SPA适配)
export const onInit = function (ctx) {
    componentContext = ctx;
    fetchConnections();
}

// 获取连接数据
async function fetchConnections() {
    const clients = await apiRequest('status/clients');
    const promiseList = clients.map(client => {
        if (!Array.isArray(client.clients)) {
            client.clients = [];
        }
        return client.clients.map(ip => {
            const promise = apiRequest('status/ip/' + ip);
            if (!promise) {
                return {
                    iface: client.interface,
                    ip,
                    connections: Promise.resolve([])
                }
            }
            return promise.then((connections) => {
                return {
                    iface: client.interface,
                    connections,
                    ip
                }
            });
        });
    });
    const promiseResults = await Promise.all(promiseList.flat())
    if (componentContext.running) {
        viewData.connectionsList = promiseResults;
        componentContext.render();
        setTimeout(() => {
            fetchConnections()
        }, 1000);
    }
}
