import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// A single notification item displayed in the Doctor's notification bell.
class SaathiNotification {
  final String id;
  final int? notificationId;
  final String title;
  final String body;
  final String timestamp;
  final String type; // 'patient_registered', 'report_pending', 'general'
  final Map<String, dynamic>? metadata;
  bool isRead;

  SaathiNotification({
    required this.id,
    this.notificationId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = 'general',
    this.metadata,
    this.isRead = false,
  });

  factory SaathiNotification.fromJson(Map<String, dynamic> json) {
    return SaathiNotification(
      id: json['id']?.toString() ?? 'notif-${json['notification_id']}',
      notificationId: json['notification_id'] as int?,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      metadata: json['metadata'] is Map ? (json['metadata'] as Map).cast<String, dynamic>() : null,
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// Shared notification provider that bridges receptionist and doctor views.
/// Polls the backend in real-time so doctor tabs are immediately notified
/// across different browser sessions/tabs without manual refresh.
class NotificationProvider extends ChangeNotifier {
  final List<SaathiNotification> _notifications = [];
  bool _isFetching = false;

  List<SaathiNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  /// Fetch latest notifications from backend and merge.
  /// Returns true if new notifications were received.
  Future<bool> fetchNotifications({
    required ApiClient apiClient,
    required String token,
  }) async {
    if (_isFetching) return false;
    _isFetching = true;
    try {
      final remoteList = await apiClient.getNotifications(token);
      if (remoteList.isEmpty) {
        final hadNotifications = _notifications.isNotEmpty;
        _notifications.clear();
        if (hadNotifications) notifyListeners();
        return false;
      }

      final incoming = remoteList.map(SaathiNotification.fromJson).toList();

      final existingIds = _notifications.map((n) => n.id).toSet();
      final hasNew = incoming.any((n) => !existingIds.contains(n.id));

      final readLocalIds = _notifications.where((n) => n.isRead).map((n) => n.id).toSet();
      for (final item in incoming) {
        if (readLocalIds.contains(item.id)) {
          item.isRead = true;
        }
      }

      _notifications.clear();
      _notifications.addAll(incoming);
      notifyListeners();
      return hasNew;
    } catch (_) {
      return false;
    } finally {
      _isFetching = false;
    }
  }

  /// Push a new notification (newest first).
  void addNotification(SaathiNotification notification) {
    _notifications.removeWhere((n) => n.id == notification.id);
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Convenience: fire a "new patient registered" notification.
  void notifyPatientRegistered({
    required String patientName,
    required String registrationNo,
    String? condition,
  }) {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    addNotification(SaathiNotification(
      id: 'notif-${now.millisecondsSinceEpoch}',
      title: 'New Patient Registered',
      body: '$patientName ($registrationNo)${condition != null && condition.isNotEmpty ? ' — $condition' : ''} has been registered by the receptionist.',
      timestamp: '$timeStr, $dateStr',
      type: 'patient_registered',
      metadata: {
        'patientName': patientName,
        'registrationNo': registrationNo,
        'condition': condition,
      },
    ));
  }

  /// Mark a single notification as read.
  void markAsRead(String id, {ApiClient? apiClient, String? token}) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      notifyListeners();

      final notifId = _notifications[idx].notificationId;
      if (apiClient != null && token != null && notifId != null) {
        apiClient.markNotificationRead(notifId, token: token);
      }
    }
  }

  /// Mark all notifications as read.
  void markAllAsRead({ApiClient? apiClient, String? token}) {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      if (apiClient != null && token != null) {
        apiClient.markAllNotificationsRead(token: token);
      }
    }
  }

  /// Clear all notifications.
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
