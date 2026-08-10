class PaymentModel {
  final String id;
  final String tranId;
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
      tranId: json['tranId'] ?? json['tran_id'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.parse(json['amount'].toString()),
      currency: json['currency'] ?? 'BDT',
      paymentType: json['paymentType'] ?? json['payment_type'] ?? 'RENT',
      status: json['status'] ?? 'PENDING',
      gatewayPageUrl: json['gatewayPageUrl'] ?? json['gateway_page_url'],
      cardType: json['cardType'] ?? json['card_type'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tranId': tranId,
      'amount': amount,
      'currency': currency,
      'paymentType': paymentType,
      'status': status,
      'gatewayPageUrl': gatewayPageUrl,
      'cardType': cardType,
      'createdAt': createdAt,
    };
  }
}
