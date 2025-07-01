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