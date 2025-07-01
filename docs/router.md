
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