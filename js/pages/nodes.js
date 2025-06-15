async function initNodesPage() {
    // 加载节点数据
    await loadNodesData();

    // 绑定表单提交事件
    document.getElementById('add-node-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveNode();
    });
}

async function loadNodesData() {
    try {
        const response = await apiRequest('nodes', 'GET');
        if (response.success && Array.isArray(response.data)) {
            renderNodesTable(response.data);
        }
    } catch (error) {
        showError(error.message);
    }
}

function renderNodesTable(nodes) {
    const tableBody = document.getElementById('nodes-table-body');
    tableBody.innerHTML = '';

    nodes.forEach(node => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${escapeHTML(node.name)}</td>
            <td>${escapeHTML(node.address)}</td>
            <td>${node.port}</td>
            <td>${node.protocol.toUpperCase()}</td>
            <td><span class="status-indicator ${node.status === 'active' ? 'status-active' : 'status-inactive'}"></span></td>
            <td>
                <button class="btn btn-small" data-id="${node.id}" onclick="editNode('${node.id}')">编辑</button>
                <button class="btn btn-small btn-warning" data-id="${node.id}" onclick="deleteNode('${node.id}')">删除</button>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

function editNode(nodeId) {
    // 实现编辑节点逻辑
    console.log('编辑节点:', nodeId);
}

function deleteNode(nodeId) {
    // 实现删除节点逻辑
    console.log('删除节点:', nodeId);
}

async function saveNode() {
    const name = document.getElementById('node-name').value.trim();
    const address = document.getElementById('node-address').value.trim();
    const port = document.getElementById('node-port').value.trim();
    const protocol = document.getElementById('node-protocol').value;

    if (!name || !address || !port) {
        showError('请填写所有必填字段');
        return;
    }

    try {
        const response = await apiRequest('nodes', 'POST', {
            name,
            address,
            port,
            protocol
        });

        if (response.success) {
            document.getElementById('add-node-form').reset();
            await loadNodesData();
            showToast('节点保存成功');
        } else {
            showError(response.error || '保存节点失败');
        }
    } catch (error) {
        showError(error.message);
    }
}