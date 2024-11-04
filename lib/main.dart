import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:is_lock_screen/is_lock_screen.dart';
//import 'package:is_lock_screen2/is_lock_screen2.dart';

// Define a ChangeNotifierProvider for the ActivityProvider
final activityProvider = ChangeNotifierProvider<ActivityProvider>((ref) {return ActivityProvider();});

class ActivityProvider extends ChangeNotifier {
  double _duration = 20; // Default value for the slider
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

  void setDuration(double duration) {
    _duration = duration;
    notifyListeners();
  }

  Future<String> exportLogsToFile() async {
    final logs = await _dbHelper.exportLogs();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/activity_logs.txt');
    String content = logs.map((log) => '${log['datetime']}: ${log['status']}').join('\n');
    await file.writeAsString(content);
    return directory.path; // Return the directory path
  }

  Future<void> _loadRecentLogs() async {
    final logs = await _dbHelper.getLastLogs();
    _recentLogs = logs.map((log) => '${log['datetime']}: ${log['log']}').toList(); // Change 'status' to 'log'
    notifyListeners();
  }


  void logActivity(String status) async {
    final formatter = DateFormat('dd MMM yyyy HH:mm:ss');
    final dateTime = formatter.format(DateTime.now());

    //print(dateTime);
    _activityLog += '$dateTime $status\n';
    await _dbHelper.insertLog(dateTime, status);
    await _loadRecentLogs();
    notifyListeners();
  }

  void _startCounterTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      //if (_counter < _duration) {incrementCounter();}
      incrementCounter();
    });
  }

  void incrementCounter() {
    // getLockScreenState().then((screenLocked) {if (screenLocked?? false) {
    //   logActivity('THE STATE IS NOW ${screenLocked}');
    // }});

    //if (_counter < _duration) {
      _counter++;
      notifyListeners();
      _checkForNotification();
    //}
  }

  // Future<bool?> getLockScreenState() async {
  //   return await isLockScreen();
  // }

  void decrementCounter() {
    if (_counter > 0) {_counter -= 1 / _duration; notifyListeners();}
  }

  void resetCounter() {
    _timer?.cancel(); // Cancel the timer
    _counter = 0; // Reset the counter
    notifyListeners(); // Notify listeners to update the UI
    _startCounterTimer(); // Optionally restart the timer if desired
  }

  void _checkForNotification() {
    if (_counter >= _duration) {_showNotification();}
  }

  Future<void> _showNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('activity_channel', 'Activity Notifications', importance: Importance.max, priority: Priority.high,);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, 'Time to Take a Rest!', 'You have reached ${_duration} minutes of activity. Consider taking a break.', platformChannelSpecifics, payload: 'item x',);
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
  double _duration = 20; // Default value for the slider
  @override
  void initState() {
    super.initState();
    // Listen for system events for lock/unlock
    SystemChannels.lifecycle.setMessageHandler((msg) {
      final activityNotifier = ref.read(activityProvider.notifier);
      //TODO: try https://stackoverflow.com/questions/73441348/how-to-check-phone-lock-screen-state
      if (msg == AppLifecycleState.paused.toString()) {//TODO: UNFORTUNATELY THIS MATCHES EVEN IF USER SWITCHES TO ANOTHER APP
        activityNotifier.logActivity('Paused');
        //activityNotifier.decrementCounter();
      }
      if (msg == AppLifecycleState.resumed.toString()) {
        activityNotifier.logActivity('Resumed');
        activityNotifier.incrementCounter();
      }
      if (msg == AppLifecycleState.detached.toString()) {activityNotifier.logActivity('detached');}
      if (msg == AppLifecycleState.inactive.toString()) {activityNotifier.logActivity('inactive');}
      if (msg == AppLifecycleState.hidden.toString()) {activityNotifier.logActivity('hidden');}

      return Future.value();
    });
  }

  void _resetCounter() {
    final activityNotifier = ref.read(activityProvider.notifier);
    activityNotifier.resetCounter();
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider); // Correctly use ref here
    return Scaffold(
      appBar: AppBar(
        title: Text('Eye rest & activity'),
        actions: [
          IconButton(icon: Icon(Icons.sd_storage_outlined),
                     onPressed: () async {String directoryPath = await activity.exportLogsToFile();
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logs exported to: $directoryPath'), duration: Duration(seconds: 10),));
                                         },
                    ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reminder interval: ${_duration.toStringAsFixed(0)} minutes', style: TextStyle(fontSize: 14, color: Colors.grey)),
              Slider(value: _duration, min: 5, max: 40, divisions: 35, label: _duration.round().toString(), activeColor: Colors.white38,
                     onChanged: (double value) {setState(() {_duration = value;});activity.setDuration(value);},
                    ),
              //SizedBox(height: 20),
              // Text('Minutes strained: ${activity.counter.toStringAsFixed(2)}', style: TextStyle(fontSize: 14)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Minutes strained: ${activity.counter.toStringAsFixed(2)}', style: TextStyle(fontSize: 14)),
                  IconButton(icon: Icon(Icons.refresh), onPressed: _resetCounter, tooltip: 'Reset',),
                ],
              ),
              SizedBox(height: 20),
              Text('Recent activity', style: TextStyle(fontSize: 14)),
              Text(activity.activityLog, style: TextStyle(fontSize: 12)),
              SizedBox(height: 20),
              Text('Old activity:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ...activity.recentLogs.map((log) => Text(log, style: TextStyle(fontSize: 12, color: Colors.grey))).toList(),
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

