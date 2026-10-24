import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../presentation/providers/notifications_providers.dart';

/// Shared inbox (students, faculty, admin). Marks items read on tap;
/// deep-links to booking details land with Phase D/E.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) {
    switch (type) {
      case 'request':
        return Icons.mark_email_unread_outlined;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'rescheduled':
        return Icons.event_repeat_outlined;
      case 'cancelled':
        return Icons.event_busy_outlined;
      case 'completed':
        return Icons.task_alt_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Sign in to view notifications.')),
      );
    }
    final inbox = ref.watch(userNotificationsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(notificationsRepositoryProvider)
                    .markAllAsRead(uid);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not update: $e')));
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userNotificationsProvider(uid)),
        child: inbox.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ListView(
            children: [
              ErrorState(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(userNotificationsProvider(uid)))
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    title: 'No notifications yet',
                    subtitle:
                        'Booking requests and status changes will appear here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                final when = n.createdAt == null
                    ? ''
                    : DateFormat('MMM d, h:mm a').format(n.createdAt!);
                return ListTile(
                  leading: Icon(_icon(n.type),
                      semanticLabel: 'Notification type ${n.type}'),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.normal
                              : FontWeight.w700)),
                  subtitle: Text('${n.body}\n$when'),
                  isThreeLine: true,
                  trailing: n.isRead
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: n.isRead
                      ? null
                      : () => ref
                          .read(notificationsRepositoryProvider)
                          .markAsRead(n.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
