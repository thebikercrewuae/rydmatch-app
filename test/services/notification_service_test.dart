import 'package:flutter_test/flutter_test.dart';
import 'package:rydmatch/services/notification_service.dart';

void main() {
  test('parses emergency SOS notifications and route arguments', () {
    final notification = AppNotification.fromJson({
      'id': 'notification-id',
      'user_id': 'recipient-id',
      'notification_type': 'emergency_sos',
      'title': 'Emergency SOS',
      'message': 'A rider needs assistance.',
      'is_read': false,
      'action_route': '/emergency-alert-screen',
      'action_arguments': {'alert_id': 'alert-id'},
      'created_at': '2026-06-15T12:00:00Z',
    });

    expect(notification.type, NotificationType.emergencySos);
    expect(notification.type.toDbString(), 'emergency_sos');
    expect(notification.actionRoute, '/emergency-alert-screen');
    expect(notification.actionArguments?['alert_id'], 'alert-id');
  });
}
