package mx.utm.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeScreenWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_screen_widget)

            val nextClassSubject = widgetData.getString("next_class_subject", null)
            val nextClassTime = widgetData.getString("next_class_time", null)
            val nextClassRoom = widgetData.getString("next_class_room", null)
            val todayTasksText = widgetData.getString("today_tasks_text", null)

            if (!nextClassSubject.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_next_class_title, nextClassSubject)
                views.setTextViewText(R.id.widget_next_class_time, nextClassTime ?: "")
                if (!nextClassRoom.isNullOrEmpty()) {
                    views.setTextViewText(R.id.widget_next_class_room, "Aula: $nextClassRoom")
                    views.setViewVisibility(R.id.widget_next_class_room, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_next_class_room, View.GONE)
                }
            } else {
                views.setTextViewText(R.id.widget_next_class_title, "Sin clases pendientes hoy")
                views.setTextViewText(R.id.widget_next_class_time, "")
                views.setViewVisibility(R.id.widget_next_class_room, View.GONE)
            }

            if (!todayTasksText.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_tasks_content, todayTasksText)
            } else {
                views.setTextViewText(R.id.widget_tasks_content, "No hay tareas pendientes para hoy")
            }

            // Al tocar el widget, abrir la app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
