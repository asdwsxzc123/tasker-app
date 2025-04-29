import 'package:flutter/material.dart';
import 'package:tasker/models/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import 'record_list_page.dart';

void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'monthly_qianji_task') {
      final record = QianJiRecord.fromJson(inputData!);
      try {
        await launchUrl(record.schemeUri, mode: LaunchMode.externalApplication);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '钱迹定时记账',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: RecordListPage(),
    );
  }
}