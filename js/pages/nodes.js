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

    const template = new TemplateEngine();
    const compiledTemplate = template.compile(`
        <tr data-id="@id">
            <td>@name</td>
            <td>@address</td>
            <td>@port</td>
            <td>@protocol.toUpperCase()</td>
            <td><span class="status-indicator @status === 'active' ? 'status-active' : 'status-inactive'"></span></td>
            <td>
                <button class="btn btn-small btn-primary edit-btn" data-id="@id">编辑</button>
                <button class="btn btn-small btn-warning" data-id="@id" onclick="deleteNode('@id')">删除</button>
            </td>
        </tr>
    `);

    nodes.forEach(node => {
        const renderedRow = template.render(compiledTemplate, node);
        tableBody.appendChild(renderedRow);
    });
}

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

async function saveEditedNode() {
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
        await loadNodesData();
        showToast('节点更新成功');
    } catch (error) {
        showError(error.message);
    }
}

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