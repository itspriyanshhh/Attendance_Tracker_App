import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _androidWidgetName = 'AttendanceWidgetProvider';

  static Future<void> updateWidget(double percentage) async {
    try {
      // Save data to the widget as String because SharedPreferences in Android doesn't support double
      await HomeWidget.saveWidgetData<String>(
        'attendance_percentage',
        percentage.toString(),
      );

      // Update the widget
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _androidWidgetName, // Placeholder for iOS
        qualifiedAndroidName:
            'com.priyanshhh.attendify.AttendanceWidgetProvider',
      );
      print('Widget updated with percentage: $percentage');
    } catch (e) {
      print('Error updating widget: $e');
    }
  }
}
