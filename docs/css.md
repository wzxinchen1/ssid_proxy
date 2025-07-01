
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
