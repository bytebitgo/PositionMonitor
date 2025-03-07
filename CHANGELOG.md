# Changelog

## [2.6.2] - 2024-03-xx

### 修复
- 修复MT5推送通知功能的实现方式
  - 使用正确的`TERMINAL_NOTIFICATIONS_ENABLED`常量
  - 确保推送通知功能在所有MT5版本上都能正常工作
  - 优化通知发送逻辑

## [2.6.1] - 2024-03-xx

### 修复
- 修复MT5推送通知功能的bug
  - 修正了`TERMINAL_PUSH_NOTIFICATIONS_ENABLED`常量名称错误
  - 更正为正确的`TERMINAL_NOTIFICATIONS_PUSH_ENABLED`常量
  - 确保MT5推送通知功能正常工作

## [2.6.0] - 2024-03-xx

### 新增
- 添加MT5内置通知功能
  - 新增`EnableMT5Notification`参数控制MT5内置通知
  - 新增`EnableMT5PushNotification`参数控制MT5推送通知
  - 在浮亏报警时支持同时发送MT5通知和钉钉通知

### 优化
- 优化通知发送逻辑，增加通知开关控制
- 通知内容格式优化，使其在移动设备上更易读

## [2.5.1] - 之前的版本

### 功能
- 支持监控多品种持仓报告并发送钉钉
- 支持监控最大浮亏报警
- 支持监控多品种持仓并发送钉钉报警
- 统计当天最大浮亏TOP50推送钉钉
- 支持钉钉的关键字认证 