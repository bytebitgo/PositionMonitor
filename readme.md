# MT5持仓监控EA

Version: 2.6.2

## 功能特点

1. 监控多品种持仓并发送报警
2. 支持最大浮亏监控和报警
3. 支持多种通知方式：
   - 钉钉通知（支持关键字认证）
   - MT5内置通知（可选）
   - MT5推送通知（可选）
4. 统计分析功能：
   - 统计当天最大浮亏TOP50
   - 自动保存统计数据
   - 定时发送统计报表

## 参数说明

### 基础参数
- `MaxFloatingLoss`: 最大浮亏阀值，默认-1000.0
- `Symbols`: 监控品种，用逗号分隔，如"XAUUSDm"
- `AlertIntervalSeconds`: 报警时间间隔（秒）
- `TimerIntervalSeconds`: 定时器间隔（秒）

### 通知相关
- `DingDingWebhook`: 钉钉机器人Webhook地址
- `DingDingAuthTag`: 钉钉认证标签
- `EnableMT5Notification`: 是否启用MT5内置通知（新增）
- `EnableMT5PushNotification`: 是否启用MT5推送通知（新增）

### 统计相关
- `StatsReportIntervalSeconds`: 统计报表发送间隔（秒）
- `StatsSaveIntervalMinutes`: 统计数据保存间隔（分钟）

## 使用说明

1. **安装配置**
   - 将EA复制到MT5的Experts目录
   - 配置必要的参数（钉钉Webhook等）
   - 选择需要的通知方式（钉钉/MT5通知）

2. **通知设置**
   - 钉钉通知：配置Webhook地址和认证标签
   - MT5内置通知：
     1. 在EA参数中启用`EnableMT5Notification`
     2. 确保MT5终端已开启通知功能
   - MT5推送通知：
     1. 在EA参数中启用`EnableMT5PushNotification`
     2. 确保MT5终端已开启推送通知功能

3. **监控内容**
   - 持仓信息：订单号、品种、类型、手数等
   - 盈亏状况：开仓价、当前价、止损止盈等
   - 统计数据：浮亏TOP50等

## 更新历史

详见 [CHANGELOG.md](CHANGELOG.md)

## 注意事项

1. MT5通知功能需要终端支持并正确配置
2. 推送通知需要MT5终端配置相应的推送服务
3. 确保网络连接稳定，以保证通知正常发送
4. 建议根据实际需求调整报警间隔和统计间隔

## 支持与反馈

- 邮箱：bytebit@foxmail.com
- 网站：https://www.yingcai.com

# MT5 Position Monitor CI/CD

使用GitHub Actions v4实现MT5项目的CI/CD流程，包括下载安装MT5、编译项目以及部署到阿里云EC2实例。

## 项目概述

本项目是一个MT5交易策略，使用GitHub Actions实现自动化的CI/CD流程，将编译后的EA部署到阿里云EC2实例上运行。

## 目录结构

```
.
├── .github/
│   └── workflows/
│       ├── mt5-cicd.yml      # GitHub Actions工作流配置
│       └── README.md         # 工作流使用说明
├── deploy-scripts/
│   ├── setup-ec2.sh          # EC2实例设置脚本
│   ├── monitor.sh            # MT5监控脚本
│   └── backup.sh             # MT5数据备份脚本
├── PositionMonitor.mq5       # MT5 EA源代码
├── ChartLabels.mqh           # MT5辅助函数
└── README.md                 # 项目说明文档
```

## CI/CD流程

整个CI/CD流程包括以下步骤：

1. **代码提交**：开发人员将代码提交到GitHub仓库
2. **自动触发**：GitHub Actions自动触发CI/CD流程
3. **下载安装MT5**：在Windows环境中下载并安装MT5
4. **编译项目**：使用MetaEditor编译MT5项目
5. **打包构建产物**：将编译后的文件打包
6. **部署到阿里云EC2**：将构建产物部署到阿里云EC2实例
7. **监控和备份**：在EC2实例上设置监控和备份机制

## 前提条件

在使用此CI/CD流程之前，您需要：

1. 一个GitHub账号和仓库
2. 一个阿里云账号和EC2实例
3. 在GitHub仓库中设置以下密钥（Secrets）：
   - `ALIYUN_SSH_PRIVATE_KEY`: 用于连接阿里云EC2实例的SSH私钥
   - `ALIYUN_HOST`: 阿里云EC2实例的主机地址（IP或域名）
   - `ALIYUN_USERNAME`: 阿里云EC2实例的登录用户名
   - `DEPLOY_PATH`: 阿里云EC2实例上的部署路径

## 使用方法

### 1. 设置GitHub仓库

1. 将本项目代码克隆到您的GitHub仓库
2. 在GitHub仓库中设置必要的密钥（Secrets）

### 2. 配置阿里云EC2实例

1. 创建一个阿里云EC2实例（推荐使用Ubuntu系统）
2. 确保实例具有足够的资源（至少2核4GB内存）
3. 配置安全组，开放必要的端口
4. 将`deploy-scripts`目录中的脚本上传到EC2实例

### 3. 初始化EC2实例

在EC2实例上执行以下命令：

```bash
chmod +x setup-ec2.sh
sudo ./setup-ec2.sh
```

### 4. 设置监控和备份

在EC2实例上设置定时任务：

```bash
# 编辑crontab
crontab -e

# 添加以下内容
# 每5分钟执行一次监控脚本
*/5 * * * * /opt/mt5/monitor.sh
# 每天凌晨2点执行备份脚本
0 2 * * * /opt/mt5/backup.sh
```

## 工作流触发方式

工作流可以通过以下方式触发：

1. 推送代码到`main`分支
2. 创建针对`main`分支的Pull Request
3. 手动触发（通过GitHub Actions界面的"workflow_dispatch"选项）

## 最佳实践

1. **分支管理**：使用`feature`分支进行开发，通过Pull Request合并到`main`分支
2. **代码审查**：在合并Pull Request之前进行代码审查
3. **测试**：在本地测试通过后再推送代码
4. **监控**：定期检查监控日志，确保MT5正常运行
5. **备份**：定期验证备份是否可用
6. **安全**：定期更新EC2实例的系统和软件包
7. **文档**：保持文档的更新，记录任何配置更改

## 故障排除

如果CI/CD流程执行失败，可以通过以下方式排查问题：

1. 查看GitHub Actions执行日志
2. 检查编译日志`compile_log.txt`
3. 在EC2实例上查看部署日志
4. 验证GitHub Secrets是否正确设置

## 贡献指南

欢迎贡献代码和改进建议！请遵循以下步骤：

1. Fork本仓库
2. 创建您的特性分支：`git checkout -b feature/amazing-feature`
3. 提交您的更改：`git commit -m 'Add some amazing feature'`
4. 推送到分支：`git push origin feature/amazing-feature`
5. 创建Pull Request
6. PR

## 许可证

本项目采用MIT许可证 - 详情请参阅[LICENSE](LICENSE)文件  

