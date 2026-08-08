class PaymentModel {
  final String id;
  final String tranId;
  final String? valId;
  final double amount;
  final String currency;
  final String paymentType;
  final String status;
  final String? gatewayPageUrl;
  final String? cardType;
  final String createdAt;

  PaymentModel({
    required this.id,
    required this.tranId,
    this.valId,
    required this.amount,
    required this.currency,
    required this.paymentType,
    required this.status,
    this.gatewayPageUrl,
    this.cardType,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? '',
      tranId: json['tranId'] ?? '',
      valId: json['valId'],
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency'] ?? 'BDT',
      paymentType: json['paymentType'] ?? 'RENT',
      status: json['status'] ?? 'PENDING',
      gatewayPageUrl: json['gatewayPageUrl'],
      cardType: json['cardType'],
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
