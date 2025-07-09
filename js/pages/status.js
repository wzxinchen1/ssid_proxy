/**
 * SSID代理系统 - 状态页面逻辑 (SPA优化版)
 * 文件路径: /js/pages/status.js
 * 功能: 实现状态页面的数据加载、渲染和交互逻辑
 */

import { showToast, formatBytes } from '../global.js';
import { apiRequest, showError } from "../utils.js"

// 页面状态对象
export const viewData = {
    connections: []
}

let componentContext;

// 页面初始化函数 (SPA适配)
export const onInit = function (ctx) {
    componentContext = ctx;
    fetchConnections();
}

// 获取连接数据
async function fetchConnections() {
    const clients=await apiRequest('status/clients');
    clients.forEach(async client => {
        if (client.interface=="br-game1"){
    viewData.connections1 = await apiRequest('status/'+client.clients[0]);
    componentContext.render();
        }else if(client.interface=="br-game2"){
    viewData.connections2 = await apiRequest('status/'+client.clients[0]);
    componentContext.render();
        }else if(client.interface=="br-game3"){
    viewData.connections3 = await apiRequest('status/'+client.clients[0]);
    componentContext.render();
        }
    });
}
