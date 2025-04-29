import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/record.dart';

class RecordListPage extends StatefulWidget {
  @override
  _RecordListPageState createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  final List<QianJiRecord> _records = [
    QianJiRecord(
      type: 0,
      amount: 26.5,
      category: '咖啡',
      scheduledDay: 29, // 每月15号执行
    ),
    QianJiRecord(
      type: 0,
      amount: 38.0,
      category: '午餐',
      scheduledDay: 29, // 每月20号执行
    ),
  ];
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text:1.0.toString());
  final _categoryController = TextEditingController( text:'午餐');
  final _dayController = TextEditingController(text: '1');
  int _type = 0;

   // 将 ScaffoldMessenger 相关操作移到 build 方法之后
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    print("init");
    // 只做初始化工作，不涉及 context
    _records.forEach((record) {
      print(record);
      _scheduleMonthlyRecord(record, showSnackbar: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialSnackbar();
      });
      _initialized = true;
    }
  }

  void _showInitialSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已初始化2条默认记账任务，将在10分钟后执行')),
    );
  }
 void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  // 发送单个记录
  Future<void> _sendRecord(QianJiRecord record) async {
    print(record.schemeUri);
    try {
      await launchUrl(record.schemeUri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已发送: ${record.category} ${record.amount}元')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: ${e.toString()}')),
      );
    }
  }

  // 计算下次执行时间
  Duration _calculateInitialDelay(int scheduledDay) {
    final now = DateTime.now();
    final today = now.day;

    if (today < scheduledDay) {
      // 本月执行
      return DateTime(now.year, now.month, scheduledDay).difference(now);
    } else {
      // 下个月执行
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      return DateTime(nextYear, nextMonth, scheduledDay).difference(now);
    }
  }

  // 设置每月定时任务
  void _scheduleMonthlyRecord(QianJiRecord record, {bool showSnackbar = true}) {
  // 测试用：设置为当前时间+10分钟
  final initialDelay = Duration(seconds: 10);

  // 正式用：计算实际每月执行时间（保留但暂时不使用）
  // final initialDelay = _calculateInitialDelay(record.scheduledDay);

  Workmanager().registerOneOffTask(
    'qianji_foreground_task',
    // 'qianji_${record.hashCode}', // 唯一任务ID
    'monthly_qianji_task',
    initialDelay: initialDelay, // 使用测试延迟时间
    inputData: record.toJson(),
    // constraints: Constraints(
    //   networkType: NetworkType.not_required,
    //   requiresBatteryNotLow: false,
    //   requiresCharging: false,
    //   requiresDeviceIdle: false,
    // ),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: Duration(minutes: 30),
  );

   if (showSnackbar) {
      _showSnackbar('已设置每月${record.scheduledDay}日自动记账\n(测试模式: 1分钟后执行)');
    }
}

  // 添加新记录
  void _addRecord() {
    if (!_formKey.currentState!.validate()) return;

    final record = QianJiRecord(
      type: _type,
      amount: double.parse(_amountController.text),
      category: _categoryController.text,
      scheduledDay: int.parse(_dayController.text).clamp(1, 28), // 限制最大28日
    );

    setState(() {
      _records.add(record);
      _amountController.clear();
      _categoryController.clear();
    });
    print(record);
    _scheduleMonthlyRecord(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('钱迹定时记账')),
      body: Column(
        children: [
          // 添加记录表单
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _type,
                    items: [
                      DropdownMenuItem(value: 0, child: Text('支出')),
                      DropdownMenuItem(value: 1, child: Text('收入')),
                    ],
                    onChanged: (value) => setState(() => _type = value!),
                    decoration: InputDecoration(labelText: '类型'),
                  ),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '金额'),
                    validator: (value) {
                      if (value == null || value.isEmpty || double.tryParse(value) == null) {
                        return '请输入有效金额';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(labelText: '分类'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入分类名称';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _dayController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '每月几号执行（1-28）'),
                    validator: (value) {
                      final day = int.tryParse(value ?? '');
                      if (day == null || day < 1 || day > 28) return '请输入1-28之间的数字';
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addRecord,
                    child: Text('添加定时记录'),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1),
          // 记录列表
          Expanded(
            child: ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(record.category),
                    subtitle: Text('${record.type == 0 ? '支出' : '收入'}: ${record.amount.toStringAsFixed(2)}元'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('每月${record.scheduledDay}日'),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () => _sendRecord(record),
                          tooltip: '立即发送',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}