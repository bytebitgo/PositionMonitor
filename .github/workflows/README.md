# MT5 CI/CD 工作流使用说明

本文档详细说明了如何使用GitHub Actions实现MT5项目的CI/CD流程，包括下载安装MT5、编译项目以及部署到阿里云EC2实例。

## 工作流程概述

工作流程 `mt5-cicd.yml` 包含以下主要步骤：

1. 检出代码
2. 下载并安装MT5
3. 编译MT5项目
4. 打包编译结果
5. 部署到阿里云EC2实例

## 前提条件

在使用此工作流之前，您需要在GitHub仓库中设置以下密钥（Secrets）：

- `ALIYUN_SSH_PRIVATE_KEY`: 用于连接阿里云EC2实例的SSH私钥
- `ALIYUN_HOST`: 阿里云EC2实例的主机地址（IP或域名）
- `ALIYUN_USERNAME`: 阿里云EC2实例的登录用户名
- `DEPLOY_PATH`: 阿里云EC2实例上的部署路径

## 如何设置GitHub Secrets

1. 在GitHub仓库页面，点击 "Settings"
2. 在左侧菜单中，点击 "Secrets and variables" -> "Actions"
3. 点击 "New repository secret" 按钮
4. 添加上述所需的密钥

## 触发工作流

工作流可以通过以下方式触发：

1. 推送代码到 `main` 分支
2. 创建针对 `main` 分支的Pull Request
3. 手动触发（通过GitHub Actions界面的 "workflow_dispatch" 选项）

## 工作流详细说明

### 1. 下载并安装MT5

工作流会自动下载MT5安装程序并进行静默安装。安装完成后，会验证安装是否成功。

### 2. 编译MT5项目

使用MetaEditor编译MT5项目，并将编译结果保存到 `build` 目录。编译过程会生成日志文件，以便于排查编译问题。

### 3. 部署到阿里云EC2

工作流会将编译后的文件打包并上传到阿里云EC2实例。在EC2实例上，会自动解压文件并完成部署。

## 自定义配置

如需自定义工作流程，可以修改 `.github/workflows/mt5-cicd.yml` 文件。常见的自定义需求包括：

- 修改触发条件
- 调整编译参数
- 更改部署方式

## 故障排除

如果工作流执行失败，可以通过以下方式排查问题：

1. 查看GitHub Actions执行日志
2. 检查编译日志 `compile_log.txt`
3. 验证GitHub Secrets是否正确设置

## 最佳实践

1. 定期更新MT5版本以获取最新功能和安全修复
2. 在本地测试通过后再推送代码
3. 使用语义化版本号管理发布
4. 为不同环境（开发、测试、生产）设置不同的部署配置 