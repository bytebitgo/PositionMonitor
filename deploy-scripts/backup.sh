#!/bin/bash
# MT5数据备份脚本

# 设置变量
MT5_DEPLOY_DIR="/opt/mt5"
BACKUP_DIR="/opt/mt5-backups"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=30  # 备份保留天数
OSS_BUCKET="your-oss-bucket"  # 替换为您的阿里云OSS存储桶名称
OSS_PATH="mt5-backups"

# 创建日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 创建备份目录
create_backup_dir() {
    log "创建备份目录"
    mkdir -p "$BACKUP_DIR"
}

# 备份MT5数据
backup_mt5_data() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$BACKUP_DIR/mt5-backup-$timestamp.tar.gz"
    
    log "开始备份MT5数据到 $backup_file"
    
    # 创建备份文件
    tar -czf "$backup_file" -C "$MT5_DEPLOY_DIR" .
    
    if [ $? -eq 0 ]; then
        log "备份成功: $backup_file"
        return 0
    else
        log "备份失败"
        return 1
    fi
}

# 上传备份到阿里云OSS
upload_to_oss() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    log "上传备份到阿里云OSS: $OSS_BUCKET/$OSS_PATH/$filename"
    
    # 使用阿里云OSS命令行工具上传
    ossutil cp "$backup_file" "oss://$OSS_BUCKET/$OSS_PATH/$filename"
    
    if [ $? -eq 0 ]; then
        log "上传成功: oss://$OSS_BUCKET/$OSS_PATH/$filename"
        return 0
    else
        log "上传失败"
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log "清理超过 $RETENTION_DAYS 天的旧备份"
    
    # 清理本地旧备份
    find "$BACKUP_DIR" -name "mt5-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    # 清理OSS上的旧备份
    local date_before=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
    ossutil rm "oss://$OSS_BUCKET/$OSS_PATH/" --recursive --if-modified-before "$date_before"
    
    log "旧备份清理完成"
}

# 主函数
main() {
    log "开始MT5数据备份流程"
    
    create_backup_dir
    
    if backup_mt5_data; then
        local latest_backup=$(find "$BACKUP_DIR" -name "mt5-backup-*.tar.gz" -type f -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [ -n "$latest_backup" ]; then
            upload_to_oss "$latest_backup"
        fi
    fi
    
    cleanup_old_backups
    
    log "MT5数据备份流程完成"
}

# 执行主函数
main 