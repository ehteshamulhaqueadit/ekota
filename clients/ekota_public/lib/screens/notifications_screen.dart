import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String authToken;

  const NotificationsScreen({Key? key, required this.authToken}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];

  final List<NotificationModel> _mockNotifications = [
    NotificationModel(
      id: 'n1',
      title: 'Payment Successful',
      message: 'Your payment of ৳15000 (RENT) with Tran ID EKOTA-PAY-991 was completed successfully.',
      type: 'PAYMENT_SUCCESS',
      isRead: false,
      createdAt: DateTime.now().subtract(Duration(minutes: 35)).toIso8601String(),
    ),
    NotificationModel(
      id: 'n2',
      title: 'Withdrawal Request Approved',
      message: 'Your withdrawal request of ৳15000 via BANK_TRANSFER has been approved. Reference: BRAC-TX-998811',
      type: 'WITHDRAWAL_APPROVED',
      isRead: true,
      createdAt: DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await _service.fetchNotifications(widget.authToken);
    setState(() {
      _notifications = list.isNotEmpty ? list : _mockNotifications;
    });
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(widget.authToken);
    setState(() {
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id,
        title: n.title,
        message: n.message,
        type: n.type,
        isRead: true,
        createdAt: n.createdAt,
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final n = _notifications[index];
            final isWithdrawal = n.type.contains('WITHDRAWAL');

            return Card(
              color: n.isRead ? Colors.transparent : Colors.blue.withOpacity(0.08),
              margin: EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isWithdrawal ? Colors.purple[100] : Colors.blue[100],
                  child: Icon(
                    isWithdrawal ? Icons.account_balance_wallet : Icons.notifications_active,
                    color: isWithdrawal ? Colors.purple : Colors.blue,
                  ),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(n.message),
                ),
                trailing: Text(
                  DateTime.parse(n.createdAt).hour.toString() + ':' + DateTime.parse(n.createdAt).minute.toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
