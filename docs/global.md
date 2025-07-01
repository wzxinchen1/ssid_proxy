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