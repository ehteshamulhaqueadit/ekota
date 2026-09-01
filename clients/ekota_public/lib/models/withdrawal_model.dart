class WithdrawalBalanceModel {
  final double totalEarnings;
  final double availableBalance;
  final double pendingWithdrawal;
  final double totalWithdrawn;

  WithdrawalBalanceModel({
    required this.totalEarnings,
    required this.availableBalance,
    required this.pendingWithdrawal,
    required this.totalWithdrawn,
  });

  factory WithdrawalBalanceModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalBalanceModel(
      totalEarnings: (double.tryParse(json['totalEarnings']?.toString() ?? '0') ?? 0.0),
      availableBalance: (double.tryParse(json['availableBalance']?.toString() ?? '0') ?? 0.0),
      pendingWithdrawal: (double.tryParse(json['pendingWithdrawal']?.toString() ?? '0') ?? 0.0),
      totalWithdrawn: (double.tryParse(json['totalWithdrawn']?.toString() ?? '0') ?? 0.0),
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
  final DateTime createdAt;

  WithdrawalRequestModel({
    required this.id,
    required this.amount,
    required this.method,
    required this.accountDetails,
    required this.status,
    this.adminNote,
    required this.createdAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: json['method']?.toString() ?? 'BANK_TRANSFER',
      accountDetails: (json['accountDetails'] as Map<String, dynamic>?) ?? {},
      status: json['status']?.toString() ?? 'PENDING',
      adminNote: json['adminNote']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
