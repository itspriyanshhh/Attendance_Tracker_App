package com.priyanshhh.attendify

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class AttendanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val percentageStr = widgetData.getString("attendance_percentage", "0.0")
                val percentage = percentageStr?.toDoubleOrNull() ?: 0.0
                setTextViewText(R.id.widget_percentage, "${percentage.toInt()}%")
                setProgressBar(R.id.widget_progress, 100, percentage.toInt(), false)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
