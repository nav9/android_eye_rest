import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ActivityProvider with ChangeNotifier {
  String _activityLog = '';
  double _counter = 0;
  Timer? _timer;

  String get activityLog => _activityLog;
  double get counter => _counter;

  ActivityProvider() {_startCounterTimer();}

  void logActivity(String status) {
    final dateTime = DateTime.now().toString();
    _activityLog += '$dateTime $status\n';
    notifyListeners();
  }

  void _startCounterTimer() {_timer = Timer.periodic(Duration(minutes: 1), (timer) {if (_counter < 20) {_counter++; notifyListeners();}});}
  void incrementCounter() {if (_counter < 20) {_counter++;notifyListeners();_checkForNotification();}}
  void decrementCounter() {if (_counter > 0) {_counter -= 1 / 20;notifyListeners();}}
  void _checkForNotification() {if (_counter >= 20) {_showNotification();}}

  Future<void> _showNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('activity_channel', 'Activity Notifications', importance: Importance.max, priority: Priority.high,);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, 'Time to Take a Rest!', 'You have reached 20 minutes of activity. Consider taking a break.', platformChannelSpecifics, payload: 'item x',);
  }

  void dispose() {_timer?.cancel();super.dispose();}
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => ActivityProvider(),
                                  child: MaterialApp(title: 'Activity Recorder', theme: ThemeData.dark(), home: HomeScreen(),),
                                 );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for system events for lock/unlock
    SystemChannels.lifecycle.setMessageHandler((msg) {
      if (msg == AppLifecycleState.paused.toString()) {
        Provider.of<ActivityProvider>(context, listen: false).logActivity('LOCKED');
        Provider.of<ActivityProvider>(context, listen: false).decrementCounter();
      } else if (msg == AppLifecycleState.resumed.toString()) {
        Provider.of<ActivityProvider>(context, listen: false).logActivity('UNLOCKED');
        Provider.of<ActivityProvider>(context, listen: false).incrementCounter();
      }
      return Future.value();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Activity Recorder')),
      body: Consumer<ActivityProvider>(
        builder: (context, activityProvider, child) {
          return SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(activityProvider.activityLog, style: TextStyle(fontSize: 16),), SizedBox(height: 20),
                  Text('Counter: ${activityProvider.counter.toStringAsFixed(2)}', style: TextStyle(fontSize: 20),),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}
