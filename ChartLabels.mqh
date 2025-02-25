//+------------------------------------------------------------------+
//|                                                     ChartLabels.mqh |
//|                                                            yingcai |
//|                                             https://www.yingcai.com |
//+------------------------------------------------------------------+
#property copyright "yingcai"
#property link      "https://www.yingcai.com"

// 标签名称常量
#define LABEL_BUILD_TIME    "CompilationTimeLabel"
#define LABEL_WARNING      "WarningLabel"

// 标签文本常量
#define TEXT_WARNING       "这张图表为监控其它图表交易报警数据使用，请不要关闭或移除EA，否则报警失效!"

//+------------------------------------------------------------------+
//| 创建并显示所有标签                                                    |
//+------------------------------------------------------------------+
void CreateAndShowLabels(string version="")
{
    // 删除可能存在的旧标签
    RemoveAllLabels();
    
    // 创建Build Time标签
    datetime compilation_date_time = __DATETIME__;
    string compilation_time_str = TimeToString(compilation_date_time, TIME_DATE | TIME_MINUTES);
    
    if(!ObjectCreate(0, LABEL_BUILD_TIME, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create build label. Error: ", GetLastError());
        return;
    }
    
    // 设置Build Time标签属性
    ObjectSetString(0, LABEL_BUILD_TIME, OBJPROP_TEXT, "Build Time: " + compilation_time_str + "  " + version);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_YDISTANCE, 80);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, LABEL_BUILD_TIME, OBJPROP_ZORDER, 100);
    
    // 创建警告标签
    if(!ObjectCreate(0, LABEL_WARNING, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create warning label. Error: ", GetLastError());
        return;
    }
    
    // 设置警告标签属性
    ObjectSetString(0, LABEL_WARNING, OBJPROP_TEXT, TEXT_WARNING);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_FONTSIZE, 14);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_XDISTANCE, (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_YDISTANCE, (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) / 2);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, LABEL_WARNING, OBJPROP_ZORDER, 100);
    
    // 强制刷新图表
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| 删除所有标签                                                        |
//+------------------------------------------------------------------+
void RemoveAllLabels()
{
    if(ObjectFind(0, LABEL_BUILD_TIME) != -1)
    {
        ObjectDelete(0, LABEL_BUILD_TIME);
    }
    
    if(ObjectFind(0, LABEL_WARNING) != -1)
    {
        ObjectDelete(0, LABEL_WARNING);
    }
}

//+------------------------------------------------------------------+
//| 更新Build Time标签                                                  |
//+------------------------------------------------------------------+
void UpdateBuildTimeLabel(string version)
{
    if(ObjectFind(0, LABEL_BUILD_TIME) != -1)
    {
        datetime compilation_date_time = __DATETIME__;
        string compilation_time_str = TimeToString(compilation_date_time, TIME_DATE | TIME_MINUTES);
        ObjectSetString(0, LABEL_BUILD_TIME, OBJPROP_TEXT, "Build Time: " + compilation_time_str + "  " + version);
        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| 更新警告标签文本                                                    |
//+------------------------------------------------------------------+
void UpdateWarningLabel(string warning_text)
{
    if(ObjectFind(0, LABEL_WARNING) != -1)
    {
        ObjectSetString(0, LABEL_WARNING, OBJPROP_TEXT, warning_text);
        ChartRedraw();
    }
} 