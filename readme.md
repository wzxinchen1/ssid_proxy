js和css文档是你需要调用的API，注意，如果你发现没有合适的API，请一定要告诉我！！！

# 非常重要的关键点
1. 路由器环境不支持调用 luci.sys.sys.info(),http.read_json()
2. lua对于空对象和空数组没有区分开，客户端如果是要接收数组，需要判断一下服务端返回的是不是数组
3. 严禁使用任何图标类，比如说 fong awesome，如果代码中有，就在改的时候一起去掉。
4. 任何修改请直接写到文件，不要发给我
5. 禁止使用 .then的链式调用，改用 await，如果已有代码存在这种情况，就改掉它
6. 基础样式、基础js逻辑写到base.css或utils.js或router.js中
7. apirequest 返回的是数据，不是原始响应，不要调用.success
8. 项目中引入了 jquery，请使用 jquery操作
9. 不要到处 try catch
10. 除了模板引擎和首页，其他地方禁止使用 addEventListener，应该使用模板引擎的功能来实现事件绑定。如果现有代码存在这个情况，就改掉。
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
  - 使用 es6 的 import 和export 来按需加载
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
│       └── nodes.css      # 服务器节点页样式
├── js/                     # JavaScript脚本
│   ├── utils.js            # 工具函数
│   ├── router.js           # 路由系统
│   ├── template.js         # 模板引擎
│   ├── global.js           # 全局状态管理
│   └── pages/              # 页面专属逻辑
│       ├── config.js       # 配置页逻辑
│       ├── logs.js         # 日志页逻辑
│       ├── monitor.js      # 监控页逻辑
│       └── status.js       # 状态页逻辑
│       └── nodes.js      # 服务器节点页逻辑
├── pages/                  # HTML页面片段
│   ├── config.html         # 配置页片段
│   ├── logs.html           # 日志页片段
│   ├── monitor.html        # 监控页片段
│   └── status.html         # 状态页片段
│   └── nodes.html          # 服务器节点页片段
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
# SSID代理系统HTTP接口文档

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

### 1.2 更新全局配置

**端点**: `POST /api/config/global`

**功能**: 更新全局配置并应用

**请求格式**:
```json
{
  "enabled": "1",
  "log_level": "debug",
  "log_retention": "14"
}
```

**响应格式**:
```json
{
  "success": true
}
```

### 1.3 添加新配置

**端点**: `POST /api/config/rules`

**功能**: 添加新规则配置

**请求格式**:
```json
{
  "enabled": "1",
  "interface": "eth0",
  "mode": "direct"
}
```

**响应格式**:
```json
{
  "success": true,
  "id": "cfg67890"
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

### 5.1 更新规则

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

### 5.2 删除规则

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

# **路由系统文档**

## **概述**
路由系统基于 Hash 实现单页面应用（SPA）的导航功能，支持动态页面加载、资源按需加载和状态管理。系统通过 `componentContext` 对象提供页面渲染回调，允许开发者手动控制页面渲染逻辑。

---

## **核心功能**
1. **基于 Hash 的路由**：通过 URL 的 Hash 部分（如 `#config`）实现页面导航。
2. **动态页面加载**：按需加载页面资源（HTML/CSS/JS）。
3. **组件上下文（`componentContext`）**：提供 `render` 回调，支持手动渲染页面。
4. **错误处理**：捕获并显示页面加载和渲染过程中的错误。
5. **生命周期管理**：支持页面初始化、激活和卸载阶段的逻辑。

---

## **API 文档**

### **1. 初始化路由**
#### **`initRouter()`**
初始化路由系统，绑定事件监听器（如 `hashchange` 和导航链接点击事件）。

**调用方式：**
```javascript
$(document).ready(() => {
  initRouter();
});
```

**功能说明：**
- 监听 `hashchange` 事件。
- 绑定导航链接的点击事件。
- 加载初始页面（根据当前 URL 的 Hash）。

---

### **2. 导航功能**
#### **`navigateTo(page)`**
导航到指定页面。

**参数：**
| 参数名 | 类型   | 必填 | 说明         |
|--------|--------|------|--------------|
| `page` | string | 是   | 目标页面名称 |

**调用示例：**
```javascript
// 导航到配置页面
navigateTo('config');
```

**功能说明：**
- 更新 URL 的 Hash 部分。
- 加载目标页面的资源（HTML/CSS/JS）。
- 调用目标页面的 `onInit` 方法，并传入 `componentContext`。

---

### **3. 页面刷新**
#### **`refreshCurrentPage()`**
刷新当前活动页面。

**调用方式：**
```javascript
refreshCurrentPage();
```

**功能说明：**
- 重新加载当前页面的资源。
- 保持页面状态不变。

---

### **4. 组件上下文（`componentContext`）**
`componentContext` 是一个对象，提供给页面的 `onInit` 方法，用于手动控制页面渲染逻辑。

#### **`componentContext.render()`**
动态渲染页面内容。

**参数：**
| 参数名 | 类型   | 必填 | 说明         |
|--------|--------|------|--------------|
| `data` | object | 是   | 渲染数据     |

**调用示例：**
```javascript
// 在页面的 init 方法中调用
function onInit(componentContext) {
  componentContext.render();
}
```

**功能说明：**
- 使用模板引擎渲染页面内容。
- 支持动态数据绑定。

---

### **5. 错误处理**
#### **`showError(message, showRetry)`**
显示错误消息。

**参数：**
| 参数名       | 类型    | 必填 | 说明             |
|--------------|---------|------|------------------|
| `message`    | string  | 是   | 错误消息内容     |
| `showRetry`  | boolean | 否   | 是否显示重试按钮 |

**调用示例：**
```javascript
showError("页面加载失败，请检查网络连接", true);
```

---

## **使用示例**

### **1. 基本导航**
```javascript
// 初始化路由
$(document).ready(() => {
  initRouter();
});

// 导航到监控页面
$("#monitor-btn").click(() => {
  navigateTo('monitor');
});
```

### **2. 动态渲染页面**
```javascript
// 在页面的 init 方法中使用 componentContext.render
function onInit(componentContext) {
  // 模拟异步数据加载
  setTimeout(() => {
    componentContext.render();
  }, 1000);
}
```

### **3. 错误处理**
```javascript
// 捕获页面加载错误
loadPageResources('config')
  .then(html => {
    $('#page-container').html(html);
    initConfigPage();
  })
  .catch(error => showError(error.message, true));
```

---

## **注意事项**
1. **页面资源命名规范**：
   - HTML 文件：`pages/[page-name].html`
   - CSS 文件：`css/pages/[page-name].css`
   - JS 文件：`js/pages/[page-name].js`

2. **`init` 方法必须接收 `componentContext`**：
   ```javascript
   function onInit(componentContext) {
     // 页面初始化逻辑
   }
   ```

4. **全局状态管理**：
   - 使用 `global.js` 管理共享状态（如用户配置、服务状态等）。


---

## **总结**
路由系统通过 `componentContext` 实现了灵活的页面渲染控制，支持动态数据绑定和错误处理。开发者只需关注页面逻辑，无需手动管理资源加载和渲染细节。
# 模板引擎调用文档

## 概述
该模板引擎是一个轻量级的前端模板解决方案，支持数据绑定、循环渲染和事件处理等功能。采用安全沙箱机制执行表达式，避免直接使用 `eval` 带来的安全风险。

## 核心功能

1. **数据绑定**：`{{表达式}}` 语法
2. **循环渲染**：`v-for="item in items"` 指令
3. **空状态处理**：`v-for-empty="无数据"` 指令
4. **表单值绑定**：`v-value` 属性（特别针对 select 元素）
5. **事件绑定**：原生事件属性如 `onclick`、`onchange` 等

## 基本用法

### 1. 初始化模板引擎

```javascript
const templateStr = `
  <div>
    <h1>{{title}}</h1>
    <ul>
      <li v-for="item in items" v-for-empty="暂无数据">
        {{item.name}} - {{item.price * item.count}}
      </li>
    </ul>
    <select v-value="{{selectedId}}">
      <option value="1">选项1</option>
      <option value="2">选项2</option>
    </select>
    <button onclick="handleClick">点击</button>
  </div>
`;

const engine = new Template(templateStr, {
  viewData: {
    title: "商品列表",
    items: [
      { name: "商品A", price: 10, count: 2 },
      { name: "商品B", price: 20, count: 1 }
    ],
    selectedId: 2
  }
});

// 渲染模板
const renderedDOM = engine.render();
document.body.appendChild(renderedDOM);

// 确保事件处理函数在全局可用
window.handleClick = function() {
  alert("按钮被点击");
};
```

### 2. 数据绑定语法

#### 简单属性访问
```html
<p>用户名: {{user.name}}</p>
```

#### 表达式计算
```html
<p>总价: {{item.price * item.quantity}}</p>
```

#### 三目运算符
```html
<span class="{{isActive ? 'active' : 'inactive'}}">状态</span>
```

### 3. 循环渲染

#### 基本循环
```html
<ul>
  <li v-for="item in items">{{item.name}}</li>
</ul>
```

#### 空状态处理
```html
<table>
  <tr v-for="user in users" v-for-empty="暂无用户数据">
    <td>{{user.id}}</td>
    <td>{{user.name}}</td>
    <td>{{user.age}}</td>
  </tr>
</table>
```

### 4. 表单绑定

#### Select 元素值绑定
```html
<select v-value="{{selectedOption}}">
  <option value="1">选项1</option>
  <option value="2">选项2</option>
</select>
```

### 5. 事件绑定

```html
<button onclick="handleSave({{item.id}})">保存</button>
```

```javascript
window.handleSave = function(id) {
  console.log("保存项目ID:", id);
};
```

## 高级功能

### 1. 嵌套数据访问

```html
<p>{{user.address.city}} {{user.address.street}}</p>
```

### 2. 方法调用

```html
<p>{{formatDate(user.createTime)}}</p>
```

```javascript
// 需要在数据对象中提供方法
const data = {
  user: {
    createTime: "2023-01-01",
    // ...
  },
  formatDate: function(dateStr) {
    return new Date(dateStr).toLocaleDateString();
  }
};
```

## 安全注意事项

1. **表达式限制**：
   - 只能访问传入数据对象的属性
   - 无法访问全局对象（如 `window`、`document`）

2. **错误处理**：
   - 表达式执行错误会被捕获并抛出详细错误信息
   - 建议在生产环境添加额外的错误处理

3. **性能考虑**：
   - 复杂表达式会影响渲染性能
   - 对于大型列表，建议预处理数据

## API 参考

### `new Template(templateString, module)`
- `templateString`: 模板字符串
- `module`: 包含 `viewData` 的对象，提供模板数据

### `render()`
渲染模板并返回 DOM 元素

# **开发者文档：SSID代理系统 - 实用工具函数库**

## **概述**
该工具库为 SSID 代理系统提供了一系列核心功能所需的实用函数，包括资源加载、HTML 转义、时间格式化、防抖处理等。基于 jQuery 实现，适用于前端开发。

---

## **函数列表**

### **1. 动态加载 CSS 文件**
- **函数名**: `loadCSS`
- **描述**: 动态加载 CSS 文件并跟踪加载状态。
- **参数**:
  - `url` (string): CSS 文件路径。
  - `page` (string): 页面名称（用于标识）。
- **返回值**: Promise，成功时解析为 `undefined`，失败时拒绝并返回错误信息。

### **2. 动态加载 JavaScript 文件**
- **函数名**: `loadJS`
- **描述**: 动态加载 JavaScript 文件并跟踪加载状态。
- **参数**:
  - `url` (string): JS 文件路径。
  - `page` (string): 页面名称（用于标识）。
- **返回值**: Promise，解析为导入的模块。

### **3. 加载页面资源**
- **函数名**: `loadPageResources`
- **描述**: 加载页面的 HTML、CSS 和 JS 资源。
- **参数**:
  - `page` (string): 页面名称。
- **返回值**: Promise，解析为包含 `htmlContent` 和 `module` 的对象。

### **4. HTML 转义**
- **函数名**: `escapeHTML`
- **描述**: 安全转义 HTML 内容，防止 XSS 攻击。
- **参数**:
  - `str` (string): 需要转义的字符串。
- **返回值**: 转义后的安全字符串。

### **5. 字节格式化**
- **函数名**: `formatBytes`
- **描述**: 将字节大小格式化为易读的字符串（如 "1.5 MB"）。
- **参数**:
  - `bytes` (number): 字节大小。
  - `decimals` (number): 保留小数位数（默认为 2）。
- **返回值**: 格式化后的字符串。

### **6. 时间格式化**
- **函数名**: `formatTime`
- **描述**: 将时间戳格式化为易读的时间字符串。
- **参数**:
  - `timestamp` (number|string): 时间戳。
- **返回值**: 格式化后的时间字符串。

### **7. 防抖函数**
- **函数名**: `debounce`
- **描述**: 防抖处理函数，防止频繁触发。
- **参数**:
  - `func` (Function): 需要防抖的函数。
  - `wait` (number): 等待时间（毫秒，默认为 300）。
- **返回值**: 防抖处理后的函数。

### **8. 复制文本到剪贴板**
- **函数名**: `copyToClipboard`
- **描述**: 将文本复制到剪贴板。
- **参数**:
  - `text` (string): 需要复制的文本。
- **返回值**: Promise，成功时解析为 `undefined`，失败时拒绝并返回错误信息。

### **9. 显示加载状态**
- **函数名**: `showLoading`
- **描述**: 在指定容器内显示加载状态。
- **参数**:
  - `selector` (string): 容器选择器（默认为 `#page-container`）。

### **10. 隐藏加载状态**
- **函数名**: `hideLoading`
- **描述**: 隐藏指定容器内的加载状态。
- **参数**:
  - `selector` (string): 容器选择器（默认为 `#page-container`）。

### **11. 显示错误消息**
- **函数名**: `showError`
- **描述**: 显示错误消息模态框。
- **参数**:
  - `message` (string): 错误消息。
  - `showRetry` (boolean): 是否显示重试按钮（默认为 `true`）。

### **12. 更新全局监控数据**
- **函数名**: `updateGlobalMonitor`
- **描述**: 更新全局监控数据的 UI 显示。
- **参数**:
  - `data` (Object): 监控数据（包含 `cpu`、`memory`、`activeConnections` 等字段）。

### **13. 切换服务状态**
- **函数名**: `toggleServiceStatus`
- **描述**: 切换服务的启动/停止状态，并更新 UI。

### **14. API 请求**
- **函数名**: `apiRequest`
- **描述**: 发起 API 请求。
- **参数**:
  - `endpoint` (string): API 端点。
  - `method` (string): HTTP 方法（默认为 `GET`）。
  - `data` (Object): 请求数据（默认为 `null`）。
- **返回值**: Promise，解析为 API 响应数据。响应数据已判断过 success 字段，不需要重复判断

### **15. 初始化工具函数**
- **函数名**: `initUtils`
- **描述**: 初始化工具函数，绑定全局错误处理。

---

## **全局变量**
- **`loadedResources`**: 跟踪已加载的资源（CSS 和 JS 文件）。

---

## **使用示例**
```javascript
// 动态加载 CSS 文件
loadCSS('css/pages/home.css', 'home')
    .then(() => console.log('CSS loaded'))
    .catch(err => console.error(err));

// 格式化时间戳
const formattedTime = formatTime(Date.now());
console.log(formattedTime); // 输出: "2023/10/01 14:30:00"

// 防抖处理输入事件
const debouncedSearch = debounce(() => {
    console.log('Search triggered');
}, 500);
$('#search-input').on('input', debouncedSearch);
```

---

## **注意事项**
1. **依赖项**: 该库依赖 jQuery 和全局状态管理模块 `global.js`。
2. **错误处理**: 全局错误处理已绑定到 `ajaxError` 事件。
3. **初始化**: 工具函数在文档加载完成后自动初始化。
