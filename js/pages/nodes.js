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
            
            // 在点击的行下方插入编辑行
            const editRow = createEditRow(nodeData);
            row.after(editRow);
            
            // 将编辑按钮变为保存按钮
            e.target.textContent = '保存';
            e.target.classList.remove('edit-btn');
            e.target.classList.add('save-btn');
            
            // 添加取消按钮
            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'btn btn-small btn-secondary cancel-btn';
            cancelBtn.textContent = '取消';
            cancelBtn.onclick = () => {
                editRow.remove();
                e.target.textContent = '编辑';
                e.target.classList.remove('save-btn');
                e.target.classList.add('edit-btn');
            };
            
            // 将取消按钮插入操作列
            const actionsCell = row.cells[5];
            actionsCell.insertBefore(cancelBtn, e.target.nextSibling);
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
            <td>${escapeHTML(node.name)}</td>
            <td>${escapeHTML(node.address)}</td>
            <td>${node.port}</td>
            <td>${node.protocol.toUpperCase()}</td>
            <td><span class="status-indicator ${node.status === 'active' ? 'status-active' : 'status-inactive'}"></span></td>
            <td>
                <button class="btn btn-small btn-primary edit-btn" data-id="${node.id}">编辑</button>
                <button class="btn btn-small btn-warning" data-id="${node.id}" onclick="deleteNode('${node.id}')">删除</button>
            </td>
        `;
        tableBody.appendChild(row);
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

function createEditRow(nodeData) {
    const editRow = document.createElement('tr');
    editRow.className = 'edit-row';
    editRow.innerHTML = `
        <td><input type="text" name="name" value="${escapeHTML(nodeData.name)}" required></td>
        <td><input type="text" name="address" value="${escapeHTML(nodeData.address)}" required></td>
        <td><input type="number" name="port" value="${nodeData.port}" required></td>
        <td>
            <select name="protocol" required>
                <option value="socks5" ${nodeData.protocol === 'socks5' ? 'selected' : ''}>SOCKS5</option>
                <option value="http" ${nodeData.protocol === 'http' ? 'selected' : ''}>HTTP</option>
            </select>
        </td>
        <td>
            <select name="status" required>
                <option value="active" ${nodeData.status === 'active' ? 'selected' : ''}>启用</option>
                <option value="inactive" ${nodeData.status === 'inactive' ? 'selected' : ''}>禁用</option>
            </select>
        </td>
        <td>
            <button type="button" class="btn btn-secondary cancel-btn">取消</button>
            <button type="submit" class="btn btn-primary save-btn">保存</button>
        </td>
    `;
    return editRow;
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