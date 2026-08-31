class ProducerBalanceModel {
  final double totalEarnings;
  final double availableBalance;
  final double pendingWithdrawal;
  final double totalWithdrawn;

  ProducerBalanceModel({
    required this.totalEarnings,
    required this.availableBalance,
    required this.pendingWithdrawal,
    required this.totalWithdrawn,
  });

  factory ProducerBalanceModel.fromJson(Map<String, dynamic> json) {
    return ProducerBalanceModel(
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      pendingWithdrawal: (json['pendingWithdrawal'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (json['totalWithdrawn'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WithdrawalRequestModel {
  final String id;
  final String producerId;
  final double amount;
  final String method;
  final Map<String, dynamic> accountDetails;
  final String status;
  final String? adminNote;
  final String? transactionRef;
  final String createdAt;

  WithdrawalRequestModel({
    required this.id,
    required this.producerId,
    required this.amount,
    required this.method,
    required this.accountDetails,
    required this.status,
    this.adminNote,
    this.transactionRef,
    required this.createdAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      id: json['id'] ?? '',
      producerId: json['producerId'] ?? json['producer_id'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.parse(json['amount'].toString()),
      method: json['method'] ?? json['paymentMethod'] ?? 'BKASH',
      accountDetails: (json['accountDetails'] is Map) ? Map<String, dynamic>.from(json['accountDetails']) : {'accountNumber': json['accountNumber'] ?? ''},
      status: json['status'] ?? 'PENDING',
      adminNote: json['adminNote'] ?? json['admin_note'],
      transactionRef: json['transactionRef'] ?? json['transaction_ref'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}
