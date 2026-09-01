class WalletTransactionModel {
  final String id;
  final String type;
  final String title;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String reference;
  final String description;
  final String status;
  final String statusSubtitle;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reference,
    required this.description,
    required this.status,
    required this.statusSubtitle,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DEPOSIT',
      title: json['title']?.toString() ?? 'Transaction',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      reference: json['reference']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      statusSubtitle: json['statusSubtitle']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
