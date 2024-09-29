import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Define a ChangeNotifierProvider for the ActivityProvider
final activityProvider = ChangeNotifierProvider<ActivityProvider>((ref) {
  return ActivityProvider();
});

class ActivityProvider extends ChangeNotifier {
  String _activityLog = '';
  double _counter = 0;
  Timer? _timer;

  String get activityLog => _activityLog;
  double get counter => _counter;

  ActivityProvider() {
    _startCounterTimer();
  }

  void logActivity(String status) {
    final dateTime = DateTime.now().toString();
    _activityLog += '$dateTime $status\n';
    notifyListeners();
  }

  void _startCounterTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (_counter < 20) {
        _counter++;
        notifyListeners();
      }
    });
  }

  void incrementCounter() {
    if (_counter < 20) {
      _counter++;
      notifyListeners();
      _checkForNotification();
    }
  }

  void decrementCounter() {
    if (_counter > 0) {
      _counter -= 1 / 20;
      notifyListeners();
    }
  }

  void _checkForNotification() {
    if (_counter >= 20) {
      _showNotification();
    }
  }

  Future<void> _showNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'activity_channel',
      'Activity Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Time to Take a Rest!',
      'You have reached 20 minutes of activity. Consider taking a break.',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Activity Recorder',
        theme: ThemeData.dark(),
        home: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for system events for lock/unlock
    SystemChannels.lifecycle.setMessageHandler((msg) {
      final activityNotifier = ref.read(activityProvider.notifier);
      if (msg == AppLifecycleState.paused.toString()) {
        activityNotifier.logActivity('LOCKED');
        activityNotifier.decrementCounter();
      } else if (msg == AppLifecycleState.resumed.toString()) {
        activityNotifier.logActivity('UNLOCKED');
        activityNotifier.incrementCounter();
      }
      return Future.value();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider); // Correctly use ref here
    return Scaffold(
      appBar: AppBar(title: Text('Activity Recorder')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.activityLog, style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              Text('Counter: ${activity.counter.toStringAsFixed(2)}', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

