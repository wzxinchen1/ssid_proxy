async function initNodesPage() {
    // 加载节点数据
    await loadNodesData();

    // 绑定表单提交事件
    document.getElementById('add-node-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveNode();
    });

    // 绑定表格编辑事件
    document.getElementById('nodes-table-body').addEventListener('click', async (e) => {
        if (e.target.classList.contains('edit-cell')) {
            const cell = e.target;
            const row = cell.closest('tr');
            const nodeId = row.dataset.id;
            const field = cell.dataset.field;
            const newValue = cell.textContent.trim();

            if (newValue) {
                try {
                    await apiRequest(`nodes/${nodeId}`, 'PUT', { [field]: newValue });
                    showToast('节点更新成功');
                } catch (error) {
                    showError(error.message);
                    // 恢复原值
                    cell.textContent = cell.dataset.originalValue;
                }
            } else {
                // 恢复原值
                cell.textContent = cell.dataset.originalValue;
            }
        }
    });
}

async function loadNodesData() {
    try {
        const data = await apiRequest('nodes', 'GET');
        // 确保数据是数组
        const nodes = Array.isArray(data) ? data : [];
        renderNodesTable(nodes);
    } catch (error) {
        showError(error.message);
    }
}

function renderNodesTable(nodes) {
    const tableBody = document.getElementById('nodes-table-body');
    tableBody.innerHTML = '';

    if (!nodes || nodes.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = '<td colspan="6" style="text-align: center;">暂无节点数据</td>';
        tableBody.appendChild(row);
        return;
    }

    nodes.forEach(node => {
        const row = document.createElement('tr');
        row.dataset.id = node.id;
        row.innerHTML = `
            <td class="edit-cell" data-field="name" data-original-value="${escapeHTML(node.name)}" contenteditable="true">${escapeHTML(node.name)}</td>
            <td class="edit-cell" data-field="address" data-original-value="${escapeHTML(node.address)}" contenteditable="true">${escapeHTML(node.address)}</td>
            <td class="edit-cell" data-field="port" data-original-value="${node.port}" contenteditable="true">${node.port}</td>
            <td>${node.protocol.toUpperCase()}</td>
            <td><span class="status-indicator ${node.status === 'active' ? 'status-active' : 'status-inactive'}"></span></td>
            <td>
                <button class="btn btn-small btn-warning" data-id="${node.id}" onclick="deleteNode('${node.id}')">删除</button>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

// 移除editNode函数，改为直接在表格中编辑

async function deleteNode(nodeId) {
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

async function saveNode() {
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
        await loadNodesData();
        showToast(nodeId ? '节点更新成功' : '节点保存成功');
    } catch (error) {
        showError(error.message);
    }
}