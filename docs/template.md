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