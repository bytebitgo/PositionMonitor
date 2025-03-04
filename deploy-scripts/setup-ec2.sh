#!/bin/bash
# 阿里云EC2实例上的MT5部署脚本

# 设置变量
MT5_DEPLOY_DIR="/opt/mt5"
MT5_DATA_DIR="$MT5_DEPLOY_DIR/MQL5"
WINE_VERSION="7.0"
LOG_FILE="$MT5_DEPLOY_DIR/deploy.log"

# 创建日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 创建部署目录
create_directories() {
    log "创建部署目录"
    mkdir -p "$MT5_DEPLOY_DIR"
    mkdir -p "$MT5_DATA_DIR"
    mkdir -p "$MT5_DATA_DIR/Experts"
    mkdir -p "$MT5_DATA_DIR/Include"
    mkdir -p "$MT5_DATA_DIR/Libraries"
    mkdir -p "$MT5_DATA_DIR/Scripts"
}

# 安装依赖
install_dependencies() {
    log "更新系统包"
    apt-get update -y
    
    log "安装必要的依赖"
    apt-get install -y wget unzip curl software-properties-common gnupg2
    
    log "安装Wine"
    dpkg --add-architecture i386
    wget -nc https://dl.winehq.org/wine-builds/winehq.key
    apt-key add winehq.key
    add-apt-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main"
    apt-get update -y
    apt-get install -y --install-recommends winehq-stable=$WINE_VERSION*
    
    log "安装Xvfb（虚拟显示服务器）"
    apt-get install -y xvfb
}

# 部署MT5文件
deploy_mt5_files() {
    log "部署MT5文件"
    
    # 检查是否有新的部署包
    if [ -f "mt5-build.zip" ]; then
        log "发现新的部署包，开始解压"
        unzip -o mt5-build.zip -d "$MT5_DEPLOY_DIR"
        
        # 复制EA文件到Experts目录
        if [ -f "$MT5_DEPLOY_DIR/PositionMonitor.ex5" ]; then
            log "复制EA文件到Experts目录"
            cp "$MT5_DEPLOY_DIR/PositionMonitor.ex5" "$MT5_DATA_DIR/Experts/"
        else
            log "警告：未找到PositionMonitor.ex5文件"
        fi
        
        # 复制其他必要文件
        log "复制其他必要文件"
        find "$MT5_DEPLOY_DIR" -name "*.mqh" -exec cp {} "$MT5_DATA_DIR/Include/" \;
        
        log "部署完成"
    else
        log "错误：未找到部署包 mt5-build.zip"
        exit 1
    fi
}

# 设置MT5自动启动
setup_autostart() {
    log "设置MT5自动启动"
    
    # 创建systemd服务文件
    cat > /etc/systemd/system/mt5.service << EOF
[Unit]
Description=MetaTrader 5 Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MT5_DEPLOY_DIR
ExecStart=/usr/bin/xvfb-run -a wine $MT5_DEPLOY_DIR/terminal64.exe /portable
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用并启动服务
    systemctl enable mt5.service
    systemctl start mt5.service
    
    log "MT5自动启动服务已设置"
}

# 主函数
main() {
    log "开始部署MT5到阿里云EC2实例"
    
    create_directories
    install_dependencies
    deploy_mt5_files
    setup_autostart
    
    log "MT5部署完成"
}

# 执行主函数
main 