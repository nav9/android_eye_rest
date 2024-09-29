import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Define a ChangeNotifierProvider for the ActivityProvider
final activityProvider = ChangeNotifierProvider<ActivityProvider>((ref) {return ActivityProvider();});

class ActivityProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _activityLog = '';
  double _counter = 0;
  Timer? _timer;
  List<String> _recentLogs = [];
  List<String> get recentLogs => _recentLogs;
  String get activityLog => _activityLog;
  double get counter => _counter;

  ActivityProvider() {
    _startCounterTimer();
    _loadRecentLogs();
  }

  Future<void> exportLogsToFile() async {
    final logs = await _dbHelper.exportLogs();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/activity_logs.txt');

    String content = logs.map((log) => '${log['datetime']}: ${log['log']}').join('\n');

    await file.writeAsString(content);
  }

  Future<void> _loadRecentLogs() async {
    final logs = await _dbHelper.getLastLogs();
    _recentLogs = logs.map((log) => '${log['datetime']}: ${log['log']}').toList();
    notifyListeners();
  }

  void logActivity(String status) async {
    final dateTime = DateTime.now().toString();
    _activityLog += '$dateTime $status\n';
    await _dbHelper.insertLog('[$dateTime] $status');
    await _loadRecentLogs();
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
    if (_counter > 0) {_counter -= 1 / 20;notifyListeners();}
  }

  void _checkForNotification() {
    if (_counter >= 20) {_showNotification();}
  }

  Future<void> _showNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('activity_channel', 'Activity Notifications', importance: Importance.max, priority: Priority.high,);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, 'Time to Take a Rest!', 'You have reached 20 minutes of activity. Consider taking a break.', platformChannelSpecifics, payload: 'item x',);
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
    return ProviderScope(child: MaterialApp(title: 'Activity Recorder', theme: ThemeData.dark(), home: HomeScreen(),),);
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
      appBar: AppBar(
        title: Text('Activity Recorder'),
        actions: [
          IconButton(
            icon: Icon(Icons.sd_storage_outlined),
            onPressed: () async {
              await activity.exportLogsToFile();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logs exported!')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.activityLog, style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              Text('Counter: ${activity.counter.toStringAsFixed(2)}', style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),
              Text('Recent Logs:', style: TextStyle(fontSize: 18)),
              ...activity.recentLogs.map((log) => Text(log)).toList(),
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

