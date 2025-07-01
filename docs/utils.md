
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
- **返回值**: Promise，解析为 API 响应数据。

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
