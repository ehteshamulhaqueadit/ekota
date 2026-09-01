class WalletModel {
  final String walletId;
  final double balance;
  final String currency;
  final String status;

  WalletModel({
    required this.walletId,
    required this.balance,
    required this.currency,
    required this.status,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      walletId: json['walletId'] ?? '',
      balance: (double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0),
      currency: json['currency'] ?? 'BDT',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
