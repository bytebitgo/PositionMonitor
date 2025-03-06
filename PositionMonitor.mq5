#property copyright "yingcai bytebit@foxmail.com"
#property link      "https://www.yingcai.com"
#property version   "1.00"
#property strict
#property description "持仓监控EA \n 1.用于监控多品种持仓报告并发送钉钉 \n 2.用于监控多最大浮亏报警 \n 3.用于监控多品种持仓并发送钉钉报警 \n 4.统计当天最大浮亏TOP50推送钉钉 \n 5.注意一下目前支持钉钉的关键字认证，其它不支持 \n 6.后续规划 上报飞书多维表，以方便做出统计报表 \n"
#property icon "mylogo.ico"
// 包含自定义库
#include "ChartLabels.mqh"

// 版本信息
#define EA_VERSION "Version:2.6.2"

// 输入参数
input double MaxFloatingLoss = -1000.0;  // 最大浮亏阀值
input string DingDingWebhook = "https://oapi.dingtalk.com/robot/send?access_token=ca2dcd33ee30c6c6085d69bc07019c83dafd08ff449ebac38cae41c74066e64d";  // 钉钉Webhook地址
input string DingDingAuthTag = "EA001";  // 钉钉认证标签
input string Symbols = "XAUUSDm";        // 监控品种(用逗号分隔)
input int AlertIntervalSeconds = 60;      // 报警时间间隔(秒)
input int TimerIntervalSeconds = 10;      // 定时器间隔(秒)
input int StatsReportIntervalSeconds = 10800;  // 统计报表发送间隔(秒)
input int StatsSaveIntervalMinutes = 10;    // 统计数据保存间隔(分钟)
input bool EnableMT5Notification = false;    // 启用MT5内置通知
input bool EnableMT5PushNotification = false;  // 启用MT5推送通知

// 全局变量
datetime lastAlertTime = 0;
string symbolArray[];  // 存储分割后的品种数组
int symbolCount = 0;   // 品种数量
datetime lastDataCleanTime = 0;  // 上次数据清理时间
datetime lastStatsSaveTime = 0;  // 上次保存统计数据的时间
datetime lastStatsReportTime = 0; // 上次发送统计报表的时间
string statsFileName = "profit_stats.csv";  // 统计文件名

// 统计相关结构体
struct ProfitRecord {
    datetime time;         // 记录时间
    double totalProfit;    // 总盈亏
    double totalVolume;    // 总手数
    string details;        // 详细信息
};

struct PositionStats {
    string symbol;     // 品种名称
    int longCount;
    int shortCount;
    int pendingCount;
    double longVolume;
    double shortVolume;
    double pendingVolume;
    double longProfit;
    double shortProfit;
    double totalProfit;
    double totalVolume;
};

// 全局数组
ProfitRecord profitHistory[];    // 存储盈亏历史记录

// 初始化函数
int OnInit()
{
    // 初始化数据清理时间
    lastDataCleanTime = TimeCurrent();
    
    // 分割品种字符串
    string symbolStr = Symbols;
    StringTrimRight(symbolStr);
    StringTrimLeft(symbolStr);
    
    // 分割字符串并存储到数组
    symbolCount = StringSplit(symbolStr, ',', symbolArray);
    
    // 检查是否有效
    if(symbolCount == 0) {
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // 移除品种名称中的空格
    for(int i = 0; i < symbolCount; i++) {
        StringTrimRight(symbolArray[i]);
        StringTrimLeft(symbolArray[i]);
    }
    
    // 加载历史统计数据
    LoadStatsFromCSV();
    
    // 启动定时器
    if(!EventSetTimer(TimerIntervalSeconds)) {
        return(INIT_FAILED);
    }
    
    // 创建并显示标签
    CreateAndShowLabels(EA_VERSION);
    
    return(INIT_SUCCEEDED);
}

// 清理函数
void OnDeinit(const int reason)
{
    EventKillTimer();  // 停止定时器
    RemoveAllLabels(); // 删除所有标签
}

// 图表事件处理函数
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // 处理图表大小改变事件
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        CreateAndShowLabels(EA_VERSION);
    }
}

// 定时器处理函数
void OnTimer() {
    datetime currentTime = TimeCurrent();
    
    // 检查并清理历史数据
    CheckAndCleanHistoryData();
    
    double totalProfitAllSymbols = 0;
    double totalVolumeAllSymbols = 0;
    string detailsAllSymbols = "";
    
    // 遍历每个品种
    for(int i = 0; i < symbolCount; i++) {
        PositionStats stats;
        ZeroMemory(stats);  // 先清零
        stats.symbol = symbolArray[i];  // 设置品种名称
        
        GetPositionStats(stats);
        
        totalProfitAllSymbols += stats.totalProfit;
        totalVolumeAllSymbols += stats.totalVolume;
        detailsAllSymbols += stats.symbol + "(" + 
                            DoubleToString(stats.totalProfit, 2) + "," +
                            DoubleToString(stats.totalVolume, 2) + "手) ";
        
        // 检查是否触发报警条件
        if(stats.totalProfit < MaxFloatingLoss) {
            // 检查是否超过设定的时间间隔
            if(currentTime - lastAlertTime >= AlertIntervalSeconds) {
                SendDingDingAlert(stats);
                lastAlertTime = currentTime;
            }
        }
    }
    
    // 更新统计记录
    UpdateProfitStats(totalProfitAllSymbols, totalVolumeAllSymbols, detailsAllSymbols);
    
    // 发送统计报表
    SendStatsReport();
}

// 获取持仓统计信息
void GetPositionStats(PositionStats &stats) {
    bool hasPositions = false;
    int totalPositions = PositionsTotal(); // 获取所有持仓数量
    
    // 遍历所有持仓
    for(int i = totalPositions - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        // 获取持仓品种
        string posSymbol = PositionGetString(POSITION_SYMBOL);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double profit = PositionGetDouble(POSITION_PROFIT);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // 检查是否是目标品种（不区分大小写）
        bool isTargetSymbol = (StringCompare(posSymbol, stats.symbol, false) == 0);
        if(!isTargetSymbol) continue;
        
        hasPositions = true;
        
        if(type == POSITION_TYPE_BUY) {
            stats.longCount++;
            stats.longVolume += volume;
            stats.longProfit += profit;
        }
        else if(type == POSITION_TYPE_SELL) {
            stats.shortCount++;
            stats.shortVolume += volume;
            stats.shortProfit += profit;
        }
    }
    
    // 遍历所有挂单
    bool hasPendingOrders = false;
    int totalOrders = OrdersTotal();
    
    // 遍历所有挂单
    for(int i = totalOrders - 1; i >= 0; i--) {
        // 选择挂单
        if(!OrderSelect(OrderGetTicket(i))) continue;
        
        string orderSymbol = OrderGetString(ORDER_SYMBOL);
        
        // 检查是否是目标品种（不区分大小写）
        if(StringCompare(orderSymbol, stats.symbol, false) != 0) continue;
        
        hasPendingOrders = true;
        double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
        
        stats.pendingCount++;
        stats.pendingVolume += volume;
    }
    
    // 计算总计
    stats.totalVolume = stats.longVolume + stats.shortVolume;
    stats.totalProfit = stats.longProfit + stats.shortProfit;
}

// 发送钉钉报警
void SendDingDingAlert(const PositionStats &stats) {
    datetime now = TimeCurrent();
    string currentTime = TimeToString(now, TIME_DATE|TIME_MINUTES);
    
    // 检查MT5内置消息推送是否启用（同时检查系统设置和用户设置）
    bool isNotificationsEnabled = EnableMT5Notification && (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED);
    bool isPushEnabled = EnableMT5PushNotification && (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED);  // 使用推送通知
    
    // 构建消息内容
    string alertMessage = stats.symbol + " 浮亏警报\n" +
                         "总持仓: " + DoubleToString(stats.totalVolume, 2) + "手\n" +
                         "总盈亏: " + DoubleToString(stats.totalProfit, 2) + "\n" +
                         "多单: " + IntegerToString(stats.longCount) + "笔, " + 
                         DoubleToString(stats.longVolume, 2) + "手, " + 
                         DoubleToString(stats.longProfit, 2) + "\n" +
                         "空单: " + IntegerToString(stats.shortCount) + "笔, " + 
                         DoubleToString(stats.shortVolume, 2) + "手, " + 
                         DoubleToString(stats.shortProfit, 2);
    
    // 如果MT5内置消息推送已启用，发送内置通知
    if(isNotificationsEnabled) {
        SendNotification(alertMessage);  // 发送到移动终端
    }
    
    // 如果MT5推送通知已启用，发送推送通知
    if(isPushEnabled) {
        string pushMessage = DingDingAuthTag + ": " + alertMessage;
        SendNotification(pushMessage);  // 发送推送通知
    }
    
    // 构建markdown内容
    string title = "[" + DingDingAuthTag + "] " + stats.symbol + "持仓监控报警";
    string text = "#### [" + DingDingAuthTag + "] " + stats.symbol + "持仓监控报警 \n\n";
    
    // 添加总体概况
    text += "> **总持仓:** " + DoubleToString(stats.totalVolume, 2) + "手, ";
    text += "**总盈亏:** " + DoubleToString(stats.totalProfit, 2) + "\n\n";
    
    // 多空持仓详情
    text += "##### ea持仓详情\n";
    text += "| 订单号 | 货币对 | 类型 | 手数 | 开仓价 | 当前价 | 止损 | 止盈 | 盈亏 | Magic | 开仓时间 |\n";
    text += "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n";

    // 遍历所有持仓
    int totalPositions = PositionsTotal();
    for(int i = totalPositions - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;

        string posSymbol = PositionGetString(POSITION_SYMBOL);
        // 检查是否是目标品种
        if(StringCompare(posSymbol, stats.symbol, false) != 0) continue;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);  // 获取止损价
        double tp = PositionGetDouble(POSITION_TP);  // 获取止盈价
        double profit = PositionGetDouble(POSITION_PROFIT);
        long magic = PositionGetInteger(POSITION_MAGIC);  // 获取魔术编号
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

        // 添加持仓信息到表格
        text += "| " + IntegerToString(ticket) + 
                " | " + posSymbol + 
                " | " + (type == POSITION_TYPE_BUY ? "买入" : "卖出") + 
                " | " + DoubleToString(volume, 2) + 
                " | " + DoubleToString(openPrice, 5) + 
                " | " + DoubleToString(currentPrice, 5) + 
                " | " + (sl > 0 ? DoubleToString(sl, 5) : "-") +  // 如果有止损则显示，否则显示"-"
                " | " + (tp > 0 ? DoubleToString(tp, 5) : "-") +  // 如果有止盈则显示，否则显示"-"
                " | " + DoubleToString(profit, 2) + 
                " | " + IntegerToString(magic) +  // 添加魔术编号
                " | " + TimeToString(openTime, TIME_DATE|TIME_MINUTES) + " |\n";
    }

    // 添加汇总信息
    text += "\n##### 持仓汇总\n";
    text += "| 方向 | 订单数量 | 总手数 | 总盈亏 |\n";
    text += "| --- | --- | --- | --- |\n";
    text += "| 多单 | " + IntegerToString(stats.longCount) + " | " + 
            DoubleToString(stats.longVolume, 2) + " | " + 
            DoubleToString(stats.longProfit, 2) + " |\n";
    text += "| 空单 | " + IntegerToString(stats.shortCount) + " | " + 
            DoubleToString(stats.shortVolume, 2) + " | " + 
            DoubleToString(stats.shortProfit, 2) + " |\n";
    text += "| 合计 | " + IntegerToString(stats.longCount + stats.shortCount) + " | " + 
            DoubleToString(stats.totalVolume, 2) + " | " + 
            DoubleToString(stats.totalProfit, 2) + " |\n";
    
    // 挂单信息
    if(stats.pendingCount > 0) {
        text += "\n##### 挂单详情\n";
        text += "| 订单号 | 货币对 | 类型 | 手数 | 挂单价格 | 当前价 | 开仓时间 |\n";
        text += "| --- | --- | --- | --- | --- | --- | --- |\n";
        
        // 遍历所有挂单
        int totalOrders = OrdersTotal();
        for(int i = totalOrders - 1; i >= 0; i--) {
            if(!OrderSelect(OrderGetTicket(i))) continue;
            
            string orderSymbol = OrderGetString(ORDER_SYMBOL);
            if(StringCompare(orderSymbol, stats.symbol, false) != 0) continue;

            ulong ticket = OrderGetInteger(ORDER_TICKET);
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            datetime openTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            double currentPrice = SymbolInfoDouble(orderSymbol, SYMBOL_BID);

            string typeStr = "";
            switch(orderType) {
                case ORDER_TYPE_BUY_LIMIT: typeStr = "买入限价"; break;
                case ORDER_TYPE_SELL_LIMIT: typeStr = "卖出限价"; break;
                case ORDER_TYPE_BUY_STOP: typeStr = "买入停损"; break;
                case ORDER_TYPE_SELL_STOP: typeStr = "卖出停损"; break;
                default: typeStr = EnumToString(orderType);
            }

            text += "| " + IntegerToString(ticket) + 
                    " | " + orderSymbol + 
                    " | " + typeStr + 
                    " | " + DoubleToString(volume, 2) + 
                    " | " + DoubleToString(price, 5) + 
                    " | " + DoubleToString(currentPrice, 5) + 
                    " | " + TimeToString(openTime, TIME_DATE|TIME_MINUTES) + " |\n";
        }
    }

    // 添加报警信息
    text += "\n##### 报警信息\n";
    text += "> 当前浮亏(" + DoubleToString(stats.totalProfit, 2) + 
            ") 已超过预警线(" + DoubleToString(MaxFloatingLoss, 2) + ")\n";
    
    // 添加时间戳
    text += "\n###### " + currentTime + " 发布 [详情](https://www.mql5.com)\n";
    
    // 构建钉钉消息
    string jsonBody = "{\"msgtype\": \"markdown\"," +
                     "\"markdown\": {" +
                     "\"title\": \"" + title + "\"," +
                     "\"text\": \"" + text + "\"" +
                     "}}";
    
    // 设置请求头和准备数据
    string request_headers = "Content-Type: application/json; charset=utf-8\r\n";
    char data[];
    StringToCharArray(jsonBody, data, 0, -1, CP_UTF8);  // 使用正确的参数格式
    char result[];
    string response_headers;
    
    int res = WebRequest("POST", DingDingWebhook, request_headers, 5000, data, result, response_headers);
    
    if(res >= 200 && res < 300) {
        // 处理成功
    } else {
        // 处理失败
    }
}

// 保存统计数据到CSV文件
void SaveStatsToCSV() {
    int fileHandle = FileOpen(statsFileName, FILE_WRITE|FILE_CSV|FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        // 写入表头
        FileWrite(fileHandle, "Time", "Total Profit", "Total Volume", "Details");
        
        // 写入数据
        for(int i = 0; i < ArraySize(profitHistory); i++) {
            FileWrite(fileHandle, 
                TimeToString(profitHistory[i].time, TIME_DATE|TIME_MINUTES),
                DoubleToString(profitHistory[i].totalProfit, 2),
                DoubleToString(profitHistory[i].totalVolume, 2),
                profitHistory[i].details
            );
        }
        
        FileClose(fileHandle);
    } else {
        // 处理无法创建文件的情况
    }
}

// 从CSV文件加载统计数据
void LoadStatsFromCSV() {
    if(!FileIsExist(statsFileName)) {
        return;
    }
    
    int fileHandle = FileOpen(statsFileName, FILE_READ|FILE_CSV|FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        // 跳过表头
        FileReadString(fileHandle);
        FileReadString(fileHandle);
        FileReadString(fileHandle);
        FileReadString(fileHandle);
        
        // 临时数组用于存储数据
        ProfitRecord tempRecords[];
        
        // 读取所有记录
        while(!FileIsEnding(fileHandle)) {
            string timeStr = FileReadString(fileHandle);
            string profitStr = FileReadString(fileHandle);
            string volumeStr = FileReadString(fileHandle);
            string details = FileReadString(fileHandle);
            
            if(timeStr == "" || profitStr == "" || volumeStr == "") continue;
            
            double profit = StringToDouble(profitStr);
            // 只加载浮亏记录
            if(profit >= 0) continue;
            
            int size = ArraySize(tempRecords);
            ArrayResize(tempRecords, size + 1);
            tempRecords[size].time = StringToTime(timeStr);
            tempRecords[size].totalProfit = profit;
            tempRecords[size].totalVolume = StringToDouble(volumeStr);
            tempRecords[size].details = details;
        }
        
        FileClose(fileHandle);
        
        // 按浮亏金额降序排序（因为是负数，所以实际是从小到大排序）
        for(int i = 0; i < ArraySize(tempRecords) - 1; i++) {
            for(int j = 0; j < ArraySize(tempRecords) - i - 1; j++) {
                if(tempRecords[j].totalProfit > tempRecords[j + 1].totalProfit) {
                    ProfitRecord temp = tempRecords[j];
                    tempRecords[j] = tempRecords[j + 1];
                    tempRecords[j + 1] = temp;
                }
            }
        }
        
        // 只保留浮亏最大的前50条记录
        int recordsToKeep = MathMin(50, ArraySize(tempRecords));
        ArrayResize(profitHistory, recordsToKeep);
        
        // 复制数据到主数组
        for(int i = 0; i < recordsToKeep; i++) {
            profitHistory[i] = tempRecords[i];
        }
    } else {
        // 处理无法打开统计文件的情况
    }
}

// 更新盈亏统计记录
void UpdateProfitStats(double currentTotalProfit, double currentTotalVolume, string details) {
    datetime currentTime = TimeCurrent();
    
    // 只记录浮亏
    if(currentTotalProfit >= 0) return;  // 如果是盈利，不记录
    
    // 添加新记录
    int size = ArraySize(profitHistory);
    ArrayResize(profitHistory, size + 1);
    profitHistory[size].time = currentTime;
    profitHistory[size].totalProfit = currentTotalProfit;
    profitHistory[size].totalVolume = currentTotalVolume;
    profitHistory[size].details = details;
    
    // 按浮亏金额降序排序（因为是负数，所以实际是从小到大排序）
    for(int i = 0; i < ArraySize(profitHistory) - 1; i++) {
        for(int j = 0; j < ArraySize(profitHistory) - i - 1; j++) {
            if(profitHistory[j].totalProfit > profitHistory[j + 1].totalProfit) {  // 改为 > 因为是负数
                // 交换位置
                ProfitRecord temp = profitHistory[j];
                profitHistory[j] = profitHistory[j + 1];
                profitHistory[j + 1] = temp;
            }
        }
    }
    
    // 只保留浮亏最大的前50条记录
    if(ArraySize(profitHistory) > 50) {
        ArrayResize(profitHistory, 50);
    }
    
    // 每隔指定时间保存一次文件
    if(currentTime - lastStatsSaveTime >= StatsSaveIntervalMinutes * 60) {
        SaveStatsToCSV();
        lastStatsSaveTime = currentTime;
    }
}

// 发送统计报表到钉钉
void SendStatsReport() {
    datetime currentTime = TimeCurrent();
    
    // 检查是否到达发送时间（使用输入的时间间隔）
    if(currentTime - lastStatsReportTime < StatsReportIntervalSeconds) return;
    
    string title = "[" + DingDingAuthTag + "] TOP50浮亏统计报表";
    string text = "#### [" + DingDingAuthTag + "] TOP50浮亏统计报表 \n\n";
    
    // 添加表格头
    text += "| 序号 | 时间 | 浮亏金额 | 手数 | 详情 |\n";
    text += "| --- | --- | --- | --- | --- |\n";
    
    // 添加数据行
    for(int i = 0; i < ArraySize(profitHistory); i++) {
        text += "| " + IntegerToString(i + 1) + 
                " | " + TimeToString(profitHistory[i].time, TIME_DATE|TIME_MINUTES) +
                " | " + DoubleToString(profitHistory[i].totalProfit, 2) +
                " | " + DoubleToString(profitHistory[i].totalVolume, 2) +
                " | " + profitHistory[i].details + " |\n";
    }
    
    // 构建钉钉消息
    string jsonBody = "{\"msgtype\": \"markdown\"," +
                     "\"markdown\": {" +
                     "\"title\": \"" + title + "\"," +
                     "\"text\": \"" + text + "\"" +
                     "}}";
    
    // 发送请求
    char data[];
    StringToCharArray(jsonBody, data, 0, -1, CP_UTF8);
    char result[];
    string response_headers;
    
    int res = WebRequest("POST", DingDingWebhook, 
                        "Content-Type: application/json; charset=utf-8\r\n",
                        5000, data, result, response_headers);
                        
    if(res >= 200 && res < 300) {
        lastStatsReportTime = currentTime;
    } else {
        // 处理发送失败的情况
    }
}

//+------------------------------------------------------------------+
//| 检查并清理历史数据                                                   |
//+------------------------------------------------------------------+
void CheckAndCleanHistoryData() {
    datetime currentTime = TimeCurrent();
    MqlDateTime mqlTime;
    TimeToStruct(currentTime, mqlTime);
    
    // 检查是否是新的一天的GMT 0点
    if(mqlTime.hour == 0 && currentTime - lastDataCleanTime > 23*60*60) {
        // 1. 先发送前一天的所有数据到钉钉
        string title = "[" + DingDingAuthTag + "] 前日交易数据汇总";
        string text = "#### [" + DingDingAuthTag + "] 前日交易数据汇总 \n\n";
        
        // 添加表格头
        text += "| 序号 | 时间 | 浮亏金额 | 手数 | 详情 |\n";
        text += "| --- | --- | --- | --- | --- |\n";
        
        // 添加所有数据行
        for(int i = 0; i < ArraySize(profitHistory); i++) {
            text += "| " + IntegerToString(i + 1) + 
                    " | " + TimeToString(profitHistory[i].time, TIME_DATE|TIME_MINUTES) +
                    " | " + DoubleToString(profitHistory[i].totalProfit, 2) +
                    " | " + DoubleToString(profitHistory[i].totalVolume, 2) +
                    " | " + profitHistory[i].details + " |\n";
        }
        
        // 发送到钉钉
        string jsonBody = "{\"msgtype\": \"markdown\"," +
                         "\"markdown\": {" +
                         "\"title\": \"" + title + "\"," +
                         "\"text\": \"" + text + "\"" +
                         "}}";
        
        char data[];
        StringToCharArray(jsonBody, data, 0, -1, CP_UTF8);
        char result[];
        string response_headers;
        
        int res = WebRequest("POST", DingDingWebhook, 
                            "Content-Type: application/json; charset=utf-8\r\n",
                            5000, data, result, response_headers);
                            
        if(res >= 200 && res < 300) {
            // 处理成功
        } else {
            // 处理发送失败的情况
        }
        
        // 2. 清空所有历史数据
        ArrayFree(profitHistory);
        ArrayResize(profitHistory, 0);
        
        // 3. 保存空数据到文件
        SaveStatsToCSV();
        
        // 4. 更新清理时间
        lastDataCleanTime = currentTime;
    }
} 