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
      totalEarnings: (json['totalEarnings'] is num) ? (json['totalEarnings'] as num).toDouble() : 0.0,
      availableBalance: (json['availableBalance'] is num) ? (json['availableBalance'] as num).toDouble() : 0.0,
      pendingWithdrawal: (json['pendingWithdrawal'] is num) ? (json['pendingWithdrawal'] as num).toDouble() : 0.0,
      totalWithdrawn: (json['totalWithdrawn'] is num) ? (json['totalWithdrawn'] as num).toDouble() : 0.0,
    );
  }
}

class WithdrawalRequestModel {
  final String id;
  final double amount;
  final String method;
  final Map<String, dynamic> accountDetails;
  final String status;
  final String? adminNote;
  final String? transactionRef;
  final String createdAt;

  WithdrawalRequestModel({
    required this.id,
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
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      method: json['method'] ?? 'BANK_TRANSFER',
      accountDetails: json['accountDetails'] ?? {},
      status: json['status'] ?? 'PENDING',
      adminNote: json['adminNote'],
      transactionRef: json['transactionRef'],
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
