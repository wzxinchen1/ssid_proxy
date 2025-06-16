/**
 * SSID代理系统 - 服务器节点页面
 * 负责管理服务器节点的配置界面逻辑
 */

import { showToast } from '../global.js';
import { apiRequest, showError } from '../utils.js';

/**
 * 初始化节点页面
 * @param {Object} componentContext - 组件上下文
 */
window.initNodesPage = async function (componentContext) {
    // 加载节点数据
    await loadNodesData(componentContext);

    // 绑定表单提交事件
    document.getElementById('add-node-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveNode(componentContext);
    });

    // 绑定表格编辑事件
    document.getElementById('nodes-table-body').addEventListener('click', async (e) => {
        if (e.target.classList.contains('edit-btn')) {
            const row = e.target.closest('tr');
            const nodeId = row.dataset.id;
            const nodeData = getNodeDataFromRow(row);

            // 填充弹窗表单
            document.getElementById('edit-node-id').value = nodeData.id;
            document.getElementById('edit-node-name').value = nodeData.name;
            document.getElementById('edit-node-address').value = nodeData.address;
            document.getElementById('edit-node-port').value = nodeData.port;
            document.getElementById('edit-node-protocol').value = nodeData.protocol;
            document.getElementById('edit-node-status').value = nodeData.status;

            // 显示弹窗
            document.getElementById('edit-node-modal').style.display = 'block';
        }
    });
}

/**
 * 加载节点数据
 * @param {Object} componentContext - 组件上下文
 */
async function loadNodesData(componentContext) {
    const data = await apiRequest('nodes', 'GET');
    // 确保数据是数组
    const nodes = Array.isArray(data) ? data : [];
    componentContext.render({ nodes });
}

/**
 * 从表格行获取节点数据
 * @param {HTMLElement} row - 表格行元素
 * @returns {Object} 节点数据
 */
function getNodeDataFromRow(row) {
    return {
        id: row.dataset.id,
        name: row.cells[0].textContent,
        address: row.cells[1].textContent,
        port: row.cells[2].textContent,
        protocol: row.cells[3].textContent.toLowerCase(),
        status: row.cells[4].querySelector('.status-indicator').classList.contains('status-active') ? 'active' : 'inactive'
    };
}

/**
 * 保存编辑的节点
 * @param {Object} componentContext - 组件上下文
 */
async function saveEditedNode(componentContext) {
    const nodeId = document.getElementById('edit-node-id').value;
    const name = document.getElementById('edit-node-name').value.trim();
    const address = document.getElementById('edit-node-address').value.trim();
    const port = document.getElementById('edit-node-port').value.trim();
    const protocol = document.getElementById('edit-node-protocol').value;
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
            status
        });

        document.getElementById('edit-node-modal').style.display = 'none';
        await loadNodesData(componentContext);
        showToast('节点更新成功');
    } catch (error) {
        showError(error.message);
    }
}

/**
 * 删除节点
 * @param {string} nodeId - 节点ID
 * @param {Object} componentContext - 组件上下文
 */
window.deleteNode = async function deleteNode(nodeId, componentContext) {
    if (confirm('确定要删除此节点吗？')) {
        try {
            await apiRequest(`nodes/${nodeId}`, 'DELETE');
            await loadNodesData(componentContext);
            showToast('节点删除成功');
        } catch (error) {
            showError(error.message);
        }
    }
}

/**
 * 保存节点
 * @param {Object} componentContext - 组件上下文
 */
async function saveNode(componentContext) {
    const nodeId = document.getElementById('node-id').value;
    const name = document.getElementById('node-name').value.trim();
    const address = document.getElementById('node-address').value.trim();
    const port = document.getElementById('node-port').value.trim();
    const protocol = document.getElementById('node-protocol').value;

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
            protocol
        });

        document.getElementById('add-node-form').reset();
        document.getElementById('node-id').value = '';
        await loadNodesData(componentContext);
        showToast(nodeId ? '节点更新成功' : '节点保存成功');
    } catch (error) {
        showError(error.message);
    }
}