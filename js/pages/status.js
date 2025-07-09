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
