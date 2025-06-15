1. 不支持调用 luci.sys.sysinfo() 接口
2. 不支持调用 luci.sys.tool 接口
3. 禁止使用 Table 接口

# SSID代理系统架构文档

## 系统概述
SSID代理系统是一个基于OpenWrt的轻量级代理管理解决方案，采用前后端分离架构设计。系统允许用户根据网络接口配置不同的代理规则，提供状态监控、日志查看和高级监控功能。

## 架构设计

### 1. 整体架构
```
+-------------------+     +-------------------+     +-------------------+
|   前端界面        |     |   LuCI API        |     |   核心服务        |
| (HTML/CSS/JS)     |<--->| (Lua)             |<--->| (Shell脚本)       |
+-------------------+     +-------------------+     +-------------------+
       ↑                             ↑                         ↑
       |                             |                         |
+-------------------+         +-------------------+     +-------------------+
|   用户浏览器      |         |   UCI配置系统     |     |   iptables防火墙  |
+-------------------+         +-------------------+     +-------------------+
```

### 2. 前端架构
- **单页面应用(SPA)**：基于Hash路由
- **模块化设计**：
  - 全局资源(base.css, utils.js)
  - 页面专属资源(各页面的CSS/JS/HTML)
- **动态加载**：按需加载页面资源
- **全局监控**：底部固定状态栏
- **响应式设计**：适应不同屏幕尺寸

### 3. 后端架构
- **LuCI API**：提供RESTful接口
- **UCI配置管理**：处理持久化配置
- **核心服务**：`ssid-proxy`脚本实现代理功能
- **日志系统**：多级别日志记录

### 4. 核心组件
1. **配置管理**：规则增删改查
2. **服务控制**：启动/停止/重启
3. **状态监控**：实时系统状态
4. **日志系统**：日志查看和清理
5. **防火墙集成**：通过iptables实现代理规则

### 5. 数据流
1. 前端发起API请求
2. LuCI处理请求并操作UCI配置
3. 核心服务读取配置并应用防火墙规则
4. 服务监控连接状态并记录日志
5. 日志数据通过API返回前端

## 目录结构
```
ssid-proxy/
├── index.html              # 主入口文件
├── css/                    # 样式文件
│   ├── base.css            # 基础样式
│   ├── style.css           # 全局组件样式
│   └── pages/              # 页面专属样式
│       ├── config.css      # 配置页样式
│       ├── logs.css        # 日志页样式
│       ├── monitor.css     # 监控页样式
│       └── status.css      # 状态页样式
├── js/                     # JavaScript脚本
│   ├── utils.js            # 工具函数
│   ├── router.js           # 路由系统
│   ├── global.js           # 全局状态管理
│   └── pages/              # 页面专属逻辑
│       ├── config.js       # 配置页逻辑
│       ├── logs.js         # 日志页逻辑
│       ├── monitor.js      # 监控页逻辑
│       └── status.js       # 状态页逻辑
├── pages/                  # HTML页面片段
│   ├── config.html         # 配置页片段
│   ├── logs.html           # 日志页片段
│   ├── monitor.html        # 监控页片段
│   └── status.html         # 状态页片段
├── api/                    # 后端API
│   ├── config.lua          # 配置API
│   ├── logs.lua            # 日志API
│   ├── monitor.lua         # 监控API
│   └── status.lua          # 状态API
├── sbin/                   # 核心脚本
│   ├── ssid-proxy          # 主服务脚本
│   └── ssid-proxy-validate # 配置验证脚本
└── ssid-proxy.lua          # LuCI主控制器
```

## 工作流程
1. 用户访问前端界面
2. 路由系统加载对应页面
3. 页面初始化时请求API获取数据
4. 用户操作触发API调用
5. 后端处理请求并返回结果
6. 前端更新界面显示结果

## 部署方式
1. 通过`install.sh`脚本安装
2. 服务部署到`/usr/sbin/ssid-proxy`
3. Web资源部署到LuCI静态目录
4. API部署到LuCI控制器目录


# SSID代理系统API文档

## 1. 配置管理API

### 1.1 获取当前配置

**端点**: `GET /api/config`

**功能**: 获取系统当前配置

**响应格式**:
```json
{
  "success": true,
  "data": {
    "global": {
      "enabled": "1",
      "log_level": "info",
      "log_retention": "7"
    },
    "rules": [
      {
        "id": "cfg12345",
        "enabled": "1",
        "interface": "br-lan",
        "mode": "proxy",
        "proxy_server": "socks5://106.63.10.142:11005"
      }
    ],
    "interfaces": ["br-lan", "eth0", "wlan0"]
  }
}
```

### 1.2 保存配置

**端点**: `POST /api/config`

**功能**: 保存新配置并应用

**请求格式**:
```json
{
  "global": {
    "enabled": "1",
    "log_level": "debug",
    "log_retention": "14"
  },
  "rules": [
    {
      "enabled": "1",
      "interface": "eth0",
      "mode": "direct"
    },
    {
      "enabled": "1",
      "interface": "wlan0",
      "mode": "proxy",
      "proxy_server": "socks5://192.168.1.100:1080"
    }
  ]
}
```

**响应格式**:
```json
{
  "success": true
}
```

## 2. 状态监控API

### 2.1 获取系统状态

**端点**: `GET /api/status`

**功能**: 获取系统实时状态

**响应格式**:
```json
{
  "success": true,
  "data": {
    "service": "running",
    "active_rules": 3,
    "active_connections": 12,
    "cpu_usage": 42,
    "memory_usage": 65,
    "interfaces": [
      {
        "name": "br-lan",
        "status": "up",
        "clients": 5,
        "traffic": "24.3MB"
      }
    ]
  }
}
```

## 3. 日志管理API

### 3.1 获取日志

**端点**: `GET /api/logs`

**参数**:
- `level` (可选): 日志级别 (error, warning, info, debug)
- `lines` (可选): 返回行数 (默认: 100)
- `search` (可选): 搜索关键词

**响应格式**:
```json
{
  "success": true,
  "data": {
    "logs": [
      "2023-10-15 14:30:25 - [INFO] 服务启动成功",
      "2023-10-15 14:31:10 - [INFO] 为 192.168.1.101 应用代理规则"
    ],
    "stats": {
      "total_lines": 1245,
      "error_count": 3,
      "warning_count": 8,
      "file_size": "1.2MB"
    }
  }
}
```

### 3.2 清除日志

**端点**: `POST /api/logs/clear`

**功能**: 清除所有日志

**响应格式**:
```json
{
  "success": true
}
```

## 4. 服务管理API

### 4.1 启动服务

**端点**: `POST /api/service/start`

**功能**: 启动代理服务

**响应格式**:
```json
{
  "success": true,
  "message": "服务已启动"
}
```

### 4.2 停止服务

**端点**: `POST /api/service/stop`

**功能**: 停止代理服务

**响应格式**:
```json
{
  "success": true,
  "message": "服务已停止"
}
```

### 4.3 重启服务

**端点**: `POST /api/service/restart`

**功能**: 重启代理服务

**响应格式**:
```json
{
  "success": true,
  "message": "服务已重启"
}
```

## 5. 规则管理API

### 5.1 添加规则

**端点**: `POST /api/rules`

**请求格式**:
```json
{
  "interface": "eth1",
  "mode": "proxy",
  "proxy_server": "socks5://proxy.example.com:1080"
}
```

**响应格式**:
```json
{
  "success": true,
  "id": "cfg67890"
}
```

### 5.2 更新规则

**端点**: `PUT /api/rules/{id}`

**请求格式**:
```json
{
  "enabled": "0",
  "mode": "direct"
}
```

**响应格式**:
```json
{
  "success": true
}
```

### 5.3 删除规则

**端点**: `DELETE /api/rules/{id}`

**响应格式**:
```json
{
  "success": true
}
```

## 6. 高级监控API

### 6.1 获取监控数据

**端点**: `GET /api/monitor`

**功能**: 获取高级监控数据

**响应格式**:
```json
{
  "success": true,
  "data": {
    "connections": [
      {
        "src_ip": "192.168.1.101",
        "dst_ip": "104.18.25.35",
        "dst_port": 443,
        "protocol": "TCP",
        "interface": "br-lan",
        "duration": "2m15s",
        "traffic_in": "1.2MB",
        "traffic_out": "0.8MB"
      }
    ],
    "clients": [
      {
        "ip": "192.168.1.102",
        "name": "张三的手机",
        "traffic": "4.7GB",
        "interface": "wlan0"
      }
    ],
    "domains": [
      {
        "name": "youtube.com",
        "traffic": "8.4GB",
        "percentage": 35
      }
    ]
  }
}
```

## 错误响应格式

所有API在出错时返回以下格式:
```json
{
  "success": false,
  "error": "错误描述",
  "code": "错误代码"
}
```

**常见错误代码**:
- `400`: 无效请求
- `401`: 未授权
- `404`: 资源未找到
- `500`: 服务器内部错误

## utils.js - 实用工具函数库（已完全实现）

### 核心功能

1. **资源动态加载**
   - `loadCSS(url, page)`：动态加载CSS文件
   - `loadJS(url, page)`：动态加载JavaScript文件
   - `loadPageResources(page)`：加载页面所需的所有资源(HTML/CSS/JS)

2. **数据处理**
   - `escapeHTML(str)`：安全转义HTML内容（防止XSS攻击）
   - `formatBytes(bytes, decimals)`：格式化字节大小为易读格式
   - `formatTime(timestamp)`：格式化时间戳为易读格式

3. **UI工具**
   - `showLoading()`：显示加载状态
   - `showError(message, showRetry)`：显示错误消息
   - `updateGlobalMonitor(data)`：更新全局监控数据

4. **交互功能**
   - `debounce(func, wait)`：防抖函数
   - `copyToClipboard(text)`：复制文本到剪贴板
   - `toggleServiceStatus()`：切换服务状态

5. **API通信**
   - `apiRequest(endpoint, method, data)`：发起API请求

6. **初始化**
   - `initUtils()`：初始化工具函数（绑定全局错误处理）

### 使用示例
```javascript
// 加载页面资源
loadPageResources('config')
  .then(html => {
    $('#page-container').html(html);
    initConfigPage();
  })
  .catch(error => showError(error.message));

// 格式化数据
const size = formatBytes(1024 * 1024); // "1 MB"
const time = formatTime(Date.now()); // "2023-08-15 14:30:25"

// 发起API请求
apiRequest('config', 'GET')
  .then(config => {
    renderConfig(config);
  });
```
# router.js API文档（已完全实现）

## 概述
路由系统基于Hash实现单页面应用导航功能，提供页面加载、导航和刷新功能。系统包含以下核心功能：
- 基于Hash的路由机制
- 动态页面加载
- 资源按需加载
- 导航状态管理
- 错误处理

## 初始化

### `initRouter()`
初始化路由系统，绑定事件监听器

**调用方式：**
```javascript
initRouter();
```

**功能说明：**
1. 监听hashchange事件
2. 绑定导航链接点击事件
3. 加载初始页面

## 导航功能

### `navigateTo(page)`
导航到指定页面

**参数：**
| 参数名 | 类型   | 必填 | 说明         |
|--------|--------|------|--------------|
| page   | string | 是   | 目标页面名称 |

**调用示例：**
```javascript
// 导航到配置页面
navigateTo('config');
```

**功能说明：**
1. 更新URL hash
2. 加载并显示目标页面
3. 更新导航UI状态

## 页面刷新

### `refreshCurrentPage()`
刷新当前活动页面

**调用方式：**
```javascript
refreshCurrentPage();
```

**功能说明：**
1. 清除当前页面的已加载资源
2. 重新加载当前页面
3. 保持页面状态不变

## 公共方法

### `loadPageFromHash()`
从当前URL hash加载页面

**调用方式：**
```javascript
loadPageFromHash();
```

**使用场景：**
- 页面初始化时
- 手动处理路由变化时

### `handleHashChange()`
处理hash变化事件

**说明：**
- 自动由系统调用
- 开发者通常不需要直接调用

## 事件处理

### `window.onhashchange`
浏览器hash变化时自动触发

**处理流程：**
1. 检查是否正在导航
2. 从hash获取目标页面
3. 加载并显示目标页面

## 页面生命周期

1. **加载阶段**
   - 显示加载动画
   - 动态加载HTML/CSS/JS资源
   - 渲染页面内容

2. **初始化阶段**
   - 调用页面初始化函数（如 `initConfigPage()`）
   - 绑定页面事件处理程序

3. **激活阶段**
   - 页面完全交互状态
   - 可接收用户操作

4. **卸载阶段**
   - 页面切换时自动清理
   - 保留资源缓存以便快速返回

## 错误处理

### `showError(message, showRetry)`
显示错误消息

**参数：**
| 参数名    | 类型    | 必填 | 说明             |
|-----------|---------|------|------------------|
| message   | string  | 是   | 错误消息内容     |
| showRetry | boolean | 否   | 是否显示重试按钮 |

**调用示例：**
```javascript
showError('页面加载失败，请检查网络连接', true);
```

## 最佳实践

```javascript
// 初始化路由
$(document).ready(function() {
    initRouter();
});

// 自定义导航
$('#custom-nav-btn').click(function() {
    navigateTo('monitor');
});

// 添加页面刷新按钮
$('#refresh-page-btn').click(function() {
    refreshCurrentPage();
});
```
## base.css - 全局基础样式

### 布局结构

1. **整体布局**
   - `.app-container`：应用容器（flex列布局）
   - `.app-header`：顶部导航栏（高度70px）
   - `.app-content`：主内容区域（自适应高度）
   - `.global-monitor`：全局监控栏（高度60px）

2. **导航组件**
   - `.main-nav`：主导航容器
   - `.nav-link`：导航链接
   - `.nav-link.active`：活动导航链接
   - `.btn-icon`：图标按钮

3. **内容区域**
   - `#page-container`：页面内容容器
   - `.loading-container`：加载状态容器
   - `.loading-spinner`：加载动画

4. **全局监控**
   - `.monitor-stats`：监控统计容器
   - `.stat-item`：统计项
   - `.stat-label`：统计标签
   - `.stat-value`：统计值
   - `.btn-small`：监控栏按钮

5. **模态框**
   - `.modal`：模态框容器
   - `.modal-content`：模态框内容
   - `.modal-actions`：模态框操作区
   - `.btn-primary`：主按钮
   - `.btn-secondary`：次按钮

6. **图标系统**
   - `.icon`：图标基础类
   - `.icon-refresh`：刷新图标
   - `.icon-settings`：设置图标
   - `.icon-chart`：图表图标
   - `.icon-power`：电源图标

### 布局特点
- 固定高度顶部导航栏(70px)和底部监控栏(60px)
- 主内容区域自适应剩余高度
- 非响应式设计（min-width: 1200px）

## style.css - 全局组件样式

### 核心组件

1. **按钮样式**
   - `.btn`：基础按钮
   - `.btn-primary`：主按钮（蓝色）
   - `.btn-secondary`：次按钮（灰色）
   - `.btn-warning`：警告按钮（橙色）
   - `.btn-small`：小尺寸按钮
   - `.btn-icon`：图标按钮

2. **卡片组件**
   - `.card`：基础卡片
   - `.card-header`：卡片头部
   - `.card-body`：卡片主体
   - `.card-footer`：卡片底部

3. **表格样式**
   - `.table`：基础表格
   - `.table-striped`：斑马纹表格
   - `.table-hover`：悬停高亮表格
   - `.table-header`：表头样式

4. **表单组件**
   - `.form-group`：表单组
   - `.form-label`：表单标签
   - `.form-control`：表单控件
   - `.checkbox-group`：复选框组

5. **状态指示器**
   - `.status-indicator`：状态指示器基础
   - `.status-active`：活动状态（绿色）
   - `.status-inactive`：非活动状态（红色）
   - `.status-pending`：待定状态（黄色）

6. **标签样式**
   - `.tag`：基础标签
   - `.tag-primary`：主标签
   - `.tag-success`：成功标签
   - `.tag-warning`：警告标签
   - `.tag-danger`：危险标签

7. **模式标签**
   - `.mode-tag`：模式标签基础
   - `.mode-proxy`：代理模式标签（蓝色）
   - `.mode-direct`：直连模式标签（绿色）
   - `.mode-block`：阻止模式标签（红色）

8. **接口标签**
   - `.interface-tag`：接口标签基础
   - `.tag-wireless`：无线接口标签（紫色）
   - `.tag-ethernet`：有线接口标签（蓝色）
   - `.tag-bridge`：网桥接口标签（绿色）
   - `.tag-vlan`：VLAN接口标签（黄色）

### 动画效果
```css
@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

@keyframes pulse {
  0% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.4); }
  70% { box-shadow: 0 0 0 8px rgba(76, 175, 80, 0); }
  100% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0); }
}
```

### 使用示例
```html
<!-- 状态指示器 -->
<span class="status-indicator status-active"></span>

<!-- 模式标签 -->
<span class="mode-tag mode-proxy">代理模式</span>

<!-- 接口标签 -->
<span class="interface-tag tag-wireless">无线</span>

<!-- 卡片组件 -->
<div class="card">
  <div class="card-header">
    <h3>规则配置</h3>
  </div>
  <div class="card-body">
    <!-- 内容 -->
  </div>
</div>```
# global.js 调用文档（已全部实现）

## 概述
global.js 是 SSID 代理系统的全局状态管理模块，负责管理应用状态、监控数据和系统配置。它提供了状态管理、订阅机制、服务控制和配置管理等功能。

## 核心功能

### 1. 状态管理
管理应用的全局状态，包括：
- 服务状态（启用/禁用）
- 监控数据（CPU、内存、连接数等）
- 用户配置（刷新间隔、主题等）
- 当前页面状态

### 2. 订阅机制
允许组件订阅特定类别的状态变更：
```javascript
// 订阅监控数据变更
subscribe('monitor', (data) => {
  console.log('监控数据更新:', data);
});

// 订阅配置变更
subscribe('config', (config) => {
  console.log('配置更新:', config);
});

// 订阅服务状态变更
subscribe('service', (status) => {
  console.log('服务状态更新:', status);
});
```

### 3. 服务控制
管理 SSID 代理服务的状态：
```javascript
// 获取服务状态
fetchServiceStatus();

// 切换服务状态
toggleServiceStatus(true);  // 启用服务
toggleServiceStatus(false); // 禁用服务
```

### 4. 监控数据管理
获取和更新系统监控数据：
```javascript
// 手动获取监控数据
fetchGlobalMonitor();

// 自动更新监控数据（基于用户配置的间隔）
setupMonitorInterval();
```

### 5. 配置管理
管理用户配置：
```javascript
// 更新用户配置
updateUserConfig('theme', 'dark');
updateUserConfig('refreshInterval', 15);

// 保存配置到本地存储
saveUserConfig();

// 应用配置变更
applyUserConfig();
```

## API 参考

### `initGlobalState()`
初始化全局状态，应在应用启动时调用。

### `updateGlobalState(key, value)`
更新全局状态并通知订阅者。
- `key`: 状态键名（支持点符号访问嵌套属性）
- `value`: 新值

### `subscribe(category, callback)`
订阅状态变更通知。
- `category`: 订阅类别（'monitor', 'config', 'service'）
- `callback`: 状态变更时的回调函数

### `unsubscribe(category, callback)`
取消订阅状态变更通知。

### `fetchServiceStatus()`
获取当前服务状态（启用/禁用）。

### `toggleServiceStatus(enable)`
切换服务状态。
- `enable`: true 启用服务，false 禁用服务

### `fetchGlobalMonitor()`
获取系统监控数据（CPU、内存、连接数等）。

### `setupMonitorInterval()`
设置监控数据自动更新间隔（基于用户配置）。

### `updateUserConfig(key, value)`
更新用户配置。
- `key`: 配置键名
- `value`: 配置值

### `saveUserConfig()`
保存用户配置到本地存储。

### `applyUserConfig()`
应用用户配置变更（如主题切换、刷新间隔等）。

### `showToast(message, type)`
显示通知消息。
- `message`: 消息内容
- `type`: 消息类型（'success', 'error', 'warning'，默认为'success'）

### `formatBytes(bytes)`
格式化字节大小为易读格式。
- `bytes`: 字节大小
- 返回: 格式化后的字符串（如 '1.5 MB'）

## 使用示例

### 初始化全局状态
```javascript
$(document).ready(() => {
  initGlobalState();
  initGlobalMonitor();
});
```

### 订阅服务状态变更
```javascript
subscribe('service', (status) => {
  if (status.enabled) {
    console.log('服务已启用');
  } else {
    console.log('服务已禁用');
  }
});
```

### 更新用户主题配置
```javascript
// 切换为深色主题
updateUserConfig('theme', 'dark');

// 保存并应用配置
saveUserConfig();
applyUserConfig();
```

### 显示通知消息
```javascript
// 显示成功消息
showToast('配置保存成功');

// 显示错误消息
showToast('保存失败，请重试', 'error');
```
上面这个项目的文档，http 接口的文档是接下来要实现的功能，js和css文档是你需要调用的API，注意，如果你发现没有合适的API，请一定要告诉我！！！

# 非常重要的关键点
1. 路由器环境不支持调用 luci.sys.sys.info()
2. lua对于空对象和空数组没有区分开，客户端如果是要接收数组，需要判断一下服务端返回的是不是数组