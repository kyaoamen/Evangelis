import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../common.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.slug, required this.eventId});
  final String slug, eventId;
  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  int _seats = 1;
  bool _busy = false;

  void _refresh(String churchId) {
    ref.invalidate(myRegistrationProvider(widget.eventId));
    ref.invalidate(seatsProvider(widget.eventId));
    ref.invalidate(myRegistrationsProvider(churchId));
  }

  Future<void> _act(String churchId, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh(churchId);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final church = ref.watch(churchProvider(widget.slug)).value;
    final event = ref.watch(eventProvider(widget.eventId));
    if (church == null) return const SizedBox.shrink();
    final fb = church.defaultLocale;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/c/${widget.slug}/events')),
        title: Text(event.value?.title.tr(context, fb) ?? ''),
      ),
      body: AsyncView(
        value: event,
        onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
        data: (e) => e == null
            ? Center(child: Text(context.l10n.noEvents))
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Poster(url: e.posterUrl, height: 220),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title.tr(context, fb),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _InfoRow(icon: Icons.schedule, text: formatDateTime(context, e.startsAt)),
                      if (e.endsAt != null) _InfoRow(icon: Icons.flag_outlined, text: formatDateTime(context, e.endsAt!)),
                      if (e.location != null) _InfoRow(icon: Icons.place_outlined, text: e.location!),
                      if (e.membersOnly) _InfoRow(icon: Icons.lock_outline, text: context.l10n.membersOnly),
                      if (e.description != null) ...[
                        const SizedBox(height: 12),
                        Text(e.description!.tr(context, fb)),
                      ],
                      const SizedBox(height: 24),
                      _RegistrationPanel(
                        event: e,
                        churchId: church.id,
                        seats: _seats,
                        busy: _busy,
                        onSeats: (v) => setState(() => _seats = v),
                        onRegister: () => _act(church.id,
                            () => ref.read(repositoryProvider).register(e.id, _seats)),
                        onCancel: (r) async {
                          if (await confirmDialog(context, context.l10n.cancelRegistrationConfirm)) {
                            await _act(church.id, () => ref.read(repositoryProvider).cancelRegistration(r.id));
                          }
                        },
                      ),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

class _RegistrationPanel extends ConsumerWidget {
  const _RegistrationPanel({
    required this.event,
    required this.churchId,
    required this.seats,
    required this.busy,
    required this.onSeats,
    required this.onRegister,
    required this.onCancel,
  });
  final ChurchEvent event;
  final String churchId;
  final int seats;
  final bool busy;
  final ValueChanged<int> onSeats;
  final VoidCallback onRegister;
  final ValueChanged<Registration> onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signedIn = ref.watch(userIdProvider) != null;
    final membership = ref.watch(membershipProvider(churchId)).value;
    final reg = ref.watch(myRegistrationProvider(event.id)).value;
    final seatInfo = ref.watch(seatsProvider(event.id)).value;
    final slug = GoRouterState.of(context).pathParameters['slug']!;

    if (reg != null) {
      final confirmed = reg.status == RegistrationStatus.confirmed;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Icon(confirmed ? Icons.check_circle : Icons.hourglass_top,
                  color: confirmed ? Colors.green : Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(confirmed ? l10n.registered : l10n.waitlisted,
                    key: const Key('registration-status'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('${l10n.seats}: ${reg.seats}'),
            ]),
            if (confirmed) ...[
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: reg.qrToken, size: 180),
              ),
              const SizedBox(height: 8),
              Text(l10n.showAtEntrance),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: busy ? null : () => onCancel(reg), child: Text(l10n.cancelRegistration)),
          ]),
        ),
      );
    }

    if (!event.canRegister) {
      return Text(l10n.registrationClosed, style: Theme.of(context).textTheme.titleSmall);
    }

    final left = seatInfo?.left;
    final isMember = membership?.isActive ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (left != null) Text(l10n.seatsLeft(left), style: Theme.of(context).textTheme.titleSmall),
      if (isMember && event.maxSeatsPerRegistration > 1) ...[
        const SizedBox(height: 8),
        Row(children: [
          Text(l10n.seats),
          const Spacer(),
          IconButton(onPressed: seats > 1 ? () => onSeats(seats - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$seats', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: seats < event.maxSeatsPerRegistration ? () => onSeats(seats + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ]),
      ],
      const SizedBox(height: 12),
      if (!signedIn || !isMember)
        FilledButton(
          key: const Key('join-to-register'),
          onPressed: membership == null
              ? () => context.go(signedIn ? '/c/$slug/join' : '/login?next=/c/$slug/join')
              : null,
          child: Text(membership == null ? l10n.joinToRegister : l10n.pending),
        )
      else
        FilledButton(
          key: const Key('register'),
          onPressed: busy ? null : onRegister,
          child: Text(l10n.register),
        ),
    ]);
  }
}
