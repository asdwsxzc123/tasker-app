import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:tasker/models/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import 'record_list_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// 全局通知插件实例
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<bool> requestExactAlarmPermission() async {
  try {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) { // Android 12+ (API 31)
        // Android 13+ (API 33) 需要使用新权限
        if (androidInfo.version.sdkInt >= 33) {
          return await Permission.scheduleExactAlarm.request().isGranted;
        } else {
          // Android 12 使用 SCHEDULE_EXACT_ALARM（不需要动态请求，但需要检查）
          final status = await Permission.scheduleExactAlarm.status;
          if (!status.isGranted) {
            // 引导用户手动开启设置
            openAppSettings(); // 来自 permission_handler
            return false;
          }
          return true;
        }
      }
    }
    return true; // 低于 Android 12 无需处理
  } on PlatformException catch (e) {
    print("权限请求异常: $e");
    return false;
  }
}

// 常规===
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((taskName, inputData) async {
//     print("init tasker dispatcher");
//     try {
//       if (taskName == 'monthly_qianji_task') {
//         final record = QianJiRecord.fromJson(inputData!);
//         print(record);
//         print(record.schemeUri);
//         // 执行跳转
//         await launchUrl(
//           record.schemeUri,
//           mode: LaunchMode.externalApplication,
//         );
//         return Future.value(true); // 明确成功
//       }
//       return Future.value(false); // 非目标任务的默认返回
//     } catch (e) {
//       print("任务异常: $e");
//       return Future.value(false); // 异常时明确失败
//     }
//   });
// }

// 通知回调===
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == 'monthly_qianji_task') {
//       final record = QianJiRecord.fromJson(inputData!);

//       // 发送通知
//       const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//         'qianji_channel', // 频道ID
//         '钱迹记账',        // 频道名称
//         importance: Importance.high,
//         priority: Priority.high,
//         enableVibration: true,
//       );

//       await flutterLocalNotificationsPlugin.show(
//         0, // 通知ID
//         '记账提醒',
//         '点击记录：${record.category} ${record.amount}元',
//         NotificationDetails(android: androidDetails),
//         payload: record.schemeUri.toString(), // 携带跳转URL
//       );
//     }
//     return true;
//   });
// }

@pragma('vm:entry-point')
Map<String, dynamic>? _cachedInputData; // 静态变量存储
// ========== 后台任务入口 ==========
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print( 'taskName: ${taskName}');
    _cachedInputData = inputData; // 先存储
    // 启动前台服务
    await FlutterForegroundTask.startService(
      notificationTitle: '钱迹记账同步中',
      notificationText: '正在处理您的记账数据',
      callback: _startForegroundTask,
    );
    return true;
  });
}


// ========== 前台任务处理器 ==========
@pragma('vm:entry-point')
void _startForegroundTask() {
  final inputData = _cachedInputData; // 读取缓存s
  FlutterForegroundTask.setTaskHandler(QianJiTaskHandler(inputData));
}

class QianJiTaskHandler extends TaskHandler {
  final Map<String, dynamic>? _taskData;

  QianJiTaskHandler(this._taskData);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    // 1. Parse accounting data
    final record = QianJiRecord.fromJson(_taskData!);

    // 2. Show progress notification
    FlutterForegroundTask.updateService(
      notificationText: 'Preparing to record: ${record.category}',
    );

    // 3. Perform accounting jump (with retry mechanism)
    bool success = false;
    for (int i = 0; i < 3 && !success; i++) {
      try {
        if (await canLaunchUrl(record.schemeUri)) {
          await launchUrl(
            record.schemeUri,
            mode: LaunchMode.externalApplication,
          );
          success = true;
        }
      } catch (e) {
        await Future.delayed(Duration(seconds: 2));
      }
    }

    // 4. Update task result
    FlutterForegroundTask.updateService(
      notificationText: success
          ? 'Accounting successful'
          : 'Accounting failed, please perform manually',
    );

    // 5. Automatically stop the service (delay 3 seconds for user visibility)
    await Future.delayed(Duration(seconds: 3));
    FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) {
    // TODO: implement onDestroy
    throw UnimplementedError();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}
// ========== 任务注册接口 ==========
Future<void> registerQianJiTask(QianJiRecord record) async {
  // 检查前台服务权限
  await FlutterForegroundTask.requestIgnoreBatteryOptimization();

  // 注册Workmanager任务
  await Workmanager().registerOneOffTask(
    'qianji_${DateTime.now().millisecondsSinceEpoch}',
    'qianji_foreground_task',
    inputData: record.toJson(),
    initialDelay: Duration(seconds: 10), // 测试用10秒延迟
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

// 通知点击处理
void _onNotificationTap(NotificationResponse response) {
  if (response.payload?.isNotEmpty ?? false) {
    launchUrl(Uri.parse(response.payload!), mode: LaunchMode.externalApplication);
  }
}
// 初始化通知设置
Future<void> _initNotifications() async {
  // Android 初始化配置
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon'); // 对应res/mipmap下的资源名

  // 创建初始化设置（iOS/macOS配置可省略）
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // 初始化插件
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationTap, // 点击回调
  );

  // Android 13+ 动态请求通知权限
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}


void  main()async {
  WidgetsFlutterBinding.ensureInitialized();
  // Workmanager().initialize(callbackDispatcher,isInDebugMode: true
  // );
  // 1. 初始化通知插件
  // await _initNotifications();


  // 初始化Workmanager
  Workmanager().initialize(
    _callbackDispatcher, // 后台任务入口
    isInDebugMode: true,
  );

  // 初始化前台任务插件
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'notification_channel_id',
      channelName: '记账任务',
      channelDescription: '正在执行自动记账',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,

    ),
    iosNotificationOptions: const IOSNotificationOptions(
    ),
  foregroundTaskOptions:  ForegroundTaskOptions(
  eventAction: ForegroundTaskEventAction.nothing(),
  ),
  );

// 请求精确闹钟权限（Android 12+）
  if (Platform.isAndroid) {
    await requestExactAlarmPermission();
  }
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