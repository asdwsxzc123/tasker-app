class QianJiRecord {
  final int type; // 0=支出, 1=收入
  final double amount;
  final String category;
  final int scheduledDay; // 每月几号执行（1-31）

  const QianJiRecord({
    required this.type,
    required this.amount,
    required this.category,
    required this.scheduledDay,
  });  @override
  String toString() => 'Print------QianJiRecord(type: $type, amount: $amount)';

  // 生成钱迹URL Scheme
  Uri get schemeUri => Uri(
    scheme: 'qianji',
    host: 'publicapi',
    path: 'addbill',
    queryParameters: {
      'type': type.toString(),
      'money': amount.toStringAsFixed(2),
      'catename': category,
    },
  );

  // JSON序列化
  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'category': category,
    'scheduledDay': scheduledDay,
  };

  factory QianJiRecord.fromJson(Map<String, dynamic> json) => QianJiRecord(
    type: json['type'],
    amount: json['amount'],
    category: json['category'],
    scheduledDay: json['scheduledDay'],
  );
}