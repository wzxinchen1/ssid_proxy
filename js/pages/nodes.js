/**
 * SSID代理系统 - 服务器节点页面
 * 负责管理服务器节点的配置界面逻辑
 */

import { showToast } from '../global.js';
import { apiRequest, showError } from '../utils.js';

let componentContext = null;
export const viewData = {
    editNodeData: {},
    nodes: [],
    showEditModal: false,
    activeTab: "tabByUrl"
};

/**
 * 初始化节点页面
 * @param {Object} ctx - 组件上下文
 */
export const onInit = async function (ctx) {
    componentContext = ctx;
    // 加载节点数据
    await loadNodesData();
}

window.addNodeByUrl = async () => {
    const url = $("#txtUrl").val();
    await apiRequest('node/add_by_url', 'POST', {
        url
    });
    await loadNodesData();
}
/**
 * 加载节点数据
 */
async function loadNodesData() {
    viewData.nodes = await apiRequest('nodes', 'GET');
    if (!Array.isArray(viewData.nodes)) {
        viewData.nodes = [];
    }
    componentContext.render();
}

window.handleToggleNode = async function (nodeId) {
    await apiRequest(`node/toggle/${nodeId}`, 'POST');
    showToast('配置状态已更新');
    await loadNodesData();
};

window.switchTab = function (tabId) {
    viewData.activeTab = tabId;
    componentContext.render();
};

window.switchNode = async (nodeId) => {
    const availableNodes = await apiRequest("node/available", "GET");
    console.log(availableNodes)
}
/**
 * 编辑节点
 * @param {string} nodeId - 节点ID
 */
window.editNode = function editNode(nodeId) {
    viewData.editNodeData = viewData.nodes.find(node => node.id === nodeId);
    viewData.showEditModal = true;
    componentContext.render();
};

window.cancelEditNode = () => {
    viewData.showEditModal = false;
    componentContext.render();
}

/**
 * 保存编辑的节点
 */
window.saveEditedNode = async () => {
    const nodeId = document.getElementById('edit-node-id').value;
    const name = document.getElementById('edit-node-name').value.trim();
    const address = document.getElementById('edit-node-address').value.trim();
    const port = document.getElementById('edit-node-port').value.trim();
    const protocol = document.getElementById('edit-node-protocol').value;
    const username = document.getElementById('edit-node-username').value.trim();
    const password = document.getElementById('edit-node-password').value.trim();
    const status = document.getElementById('edit-node-status').value;

    if (!name || !address || !port) {
        showError('请填写所有必填字段');
        return;
    }

    try {
        await apiRequest(`nodes/${nodeId}`, 'PUT', {
            name,
            address,
            port,
            protocol,
            username,
            password,
            status
        });
        viewData.showEditModal = false;
        await loadNodesData();

    } catch (error) {
        showError(error.message);
    }
}

/**
 * 删除节点
 * @param {string} nodeId - 节点ID
 */
window.deleteNode = async function deleteNode(nodeId) {
    if (confirm('确定要删除此节点吗？')) {
        try {
            await apiRequest(`nodes/${nodeId}`, 'DELETE');
            await loadNodesData();
            showToast('节点删除成功');
        } catch (error) {
            showError(error.message);
        }
    }
}

/**
 * 保存节点
 */
window.saveNode = async function () {
    const nodeId = document.getElementById('node-id').value;
    const name = document.getElementById('node-name').value.trim();
    const address = document.getElementById('node-address').value.trim();
    const port = document.getElementById('node-port').value.trim();
    const protocol = document.getElementById('node-protocol').value;
    const username = document.getElementById('node-username').value.trim();
    const password = document.getElementById('node-password').value.trim();

    if (!name || !address || !port) {
        showError('请填写所有必填字段');
        return;
    }

    try {
        const method = nodeId ? 'PUT' : 'POST';
        const endpoint = nodeId ? `nodes/${nodeId}` : 'nodes';
        await apiRequest(endpoint, method, {
            name,
            address,
            port,
            protocol,
            username,
            password
        });

        document.getElementById('node-id').value = '';
        document.getElementById('node-name').value = '';
        document.getElementById('node-address').value = '';
        document.getElementById('node-port').value = '';
        document.getElementById('node-protocol').value = '';
        document.getElementById('node-username').value = '';
        document.getElementById('node-password').value = '';
        await loadNodesData();
        showToast(nodeId ? '节点更新成功' : '节点保存成功');
    } catch (error) {
        showError(error.message);
    }
}

/**
 * 获取代理服务器列表
 * @returns {Promise<Array>} 代理服务器列表
 */
export const getProxyServers = async function () {
    const nodes = await apiRequest('nodes', 'GET');
    return nodes;
};