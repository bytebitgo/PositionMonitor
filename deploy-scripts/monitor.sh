#!/bin/bash
# MT5监控脚本

# 设置变量
MT5_DEPLOY_DIR="/opt/mt5"
LOG_FILE="$MT5_DEPLOY_DIR/monitor.log"
ALERT_EMAIL="your-email@example.com"  # 替换为您的邮箱
CHECK_INTERVAL=300  # 检查间隔（秒）

# 创建日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 发送警报邮件
send_alert() {
    local subject="$1"
    local message="$2"
    
    log "发送警报邮件: $subject"
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
}

# 检查MT5进程
check_mt5_process() {
    if pgrep -f "wine.*terminal64.exe" > /dev/null; then
        log "MT5进程正在运行"
        return 0
    else
        log "警告：MT5进程未运行"
        return 1
    fi
}

# 检查MT5服务
check_mt5_service() {
    if systemctl is-active --quiet mt5.service; then
        log "MT5服务正在运行"
        return 0
    else
        log "警告：MT5服务未运行"
        return 1
    fi
}

# 重启MT5服务
restart_mt5_service() {
    log "尝试重启MT5服务"
    systemctl restart mt5.service
    
    # 等待服务启动
    sleep 10
    
    if systemctl is-active --quiet mt5.service; then
        log "MT5服务已成功重启"
        return 0
    else
        log "错误：MT5服务重启失败"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    # 检查CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    log "CPU使用率: $cpu_usage%"
    
    # 检查内存使用率
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    log "内存使用率: $mem_usage%"
    
    # 检查磁盘使用率
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    log "磁盘使用率: $disk_usage%"
    
    # 如果资源使用率过高，发送警报
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        send_alert "警告：CPU使用率过高" "CPU使用率: $cpu_usage%"
    fi
    
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        send_alert "警告：内存使用率过高" "内存使用率: $mem_usage%"
    fi
    
    if (( disk_usage > 90 )); then
        send_alert "警告：磁盘使用率过高" "磁盘使用率: $disk_usage%"
    fi
}

# 主循环
main() {
    log "启动MT5监控脚本"
    
    while true; do
        # 检查MT5服务和进程
        if ! check_mt5_service || ! check_mt5_process; then
            log "检测到MT5异常，尝试重启服务"
            
            if restart_mt5_service; then
                send_alert "MT5服务已重启" "MT5服务已成功重启"
            else
                send_alert "MT5服务重启失败" "MT5服务重启失败，请手动检查"
            fi
        fi
        
        # 检查系统资源
        check_system_resources
        
        # 等待下一次检查
        log "等待 $CHECK_INTERVAL 秒后进行下一次检查"
        sleep $CHECK_INTERVAL
    done
}

# 执行主函数
main 