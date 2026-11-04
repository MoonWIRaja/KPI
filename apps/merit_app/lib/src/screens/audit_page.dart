import 'package:flutter/material.dart';

import '../data/merit_repository.dart';
import '../widgets/app_modal.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({required this.repository, required this.canReadSystemAudit, super.key});
  final MeritRepository repository;
  final bool canReadSystemAudit;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  List<MeritEvent> _meritEvents = const [];
  List<Map<String, dynamic>> _systemEvents = const [];
  String _filter = 'all'; // 'all', 'merit', 'system'
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meritEvents = await widget.repository.loadEvents(limit: 200);
      List<Map<String, dynamic>> systemEvents = const [];
      if (widget.canReadSystemAudit) {
        try {
          systemEvents = await widget.repository.loadAuditEvents(limit: 200);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _meritEvents = meritEvents;
          _systemEvents = systemEvents;
        });
      }
    } catch (_) {
      if (mounted) _error = 'Audit log could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.canReadSystemAudit) ...[
              Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'merit', label: Text('Merit')),
                    ButtonSegment(value: 'system', label: Text('System')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: ThinkingOrbsLoader())
                  : _error != null
                      ? Center(
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                        )
                      : _buildUnifiedList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedList(BuildContext context) {
    final items = <_AuditListItem>[];
    if (_filter == 'all' || _filter == 'merit') {
      for (final e in _meritEvents) {
        items.add(_AuditListItem(timestamp: e.createdAt, meritEvent: e));
      }
    }
    if ((_filter == 'all' || _filter == 'system') && widget.canReadSystemAudit) {
      for (final s in _systemEvents) {
        final action = s['action'] as String? ?? '';
        // Skip duplicate merit.adjust / staff.create entries when viewing 'all'
        if (_filter == 'all' && (action == 'merit.adjust' || action == 'merit.correct' || action == 'staff.create')) {
          continue;
        }
        items.add(
          _AuditListItem(
            timestamp: DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
            systemEvent: s,
          ),
        );
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (items.isEmpty) {
      return const Center(child: Text('No audit activity recorded yet.'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Surface3DCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 12,
          child: _buildRow(context, items[index]),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _AuditListItem item) {
    final merit = item.meritEvent;
    if (merit != null) {
      final positive = merit.deltaTenths >= 0;
      final isOpening = merit.type == 'opening';

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isOpening
                ? const Color(0xFFEEF3FF)
                : positive
                    ? const Color(0xFFE8F7EE)
                    : const Color(0xFFFFEEEE),
            child: Icon(
              isOpening
                  ? Icons.flag_outlined
                  : positive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
              color: isOpening
                  ? const Color(0xFF245CEB)
                  : positive
                      ? const Color(0xFF16804A)
                      : const Color(0xFFB42318),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${merit.staffName ?? 'Staff'} (${merit.staffCode ?? '—'})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF141C2E)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOpening
                            ? const Color(0xFFEEF3FF)
                            : positive
                                ? const Color(0xFFE8F7EE)
                                : const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOpening ? 'Opening' : formatDelta(merit.deltaTenths),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOpening
                              ? const Color(0xFF245CEB)
                              : positive
                                  ? const Color(0xFF16804A)
                                  : const Color(0xFFB42318),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  merit.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF34435D)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatDate(merit.createdAt)}${merit.actorName != null ? '  ·  by ${merit.actorName}' : ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF667894)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E9F2)),
            ),
            child: Text(
              formatMerit(merit.afterTenths),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF141C2E)),
            ),
          ),
        ],
      );
    }

    final sys = item.systemEvent!;
    final action = sys['action'] as String? ?? 'system.event';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFEEF3FF),
          child: Icon(Icons.shield_outlined, color: Color(0xFF245CEB), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF141C2E)),
              ),
              const SizedBox(height: 4),
              Text(
                '${sys['target_type'] ?? 'system'}  ·  ${formatDate(item.timestamp)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF667894)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Details',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFF667894)),
          onPressed: () => showAppModal<void>(
            context: context,
            builder: (dialogContext) => AppModalCard(
              maxWidth: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF245CEB), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audit Event Details',
                          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF141C2E),
                              ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF667894)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD6E3FF)),
                    ),
                    child: Text(
                      action,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF245CEB)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE5F2)),
                    ),
                    child: SelectableText(
                      (sys['metadata'] ?? const {}).toString(),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF34435D)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditListItem {
  const _AuditListItem({required this.timestamp, this.meritEvent, this.systemEvent});
  final DateTime timestamp;
  final MeritEvent? meritEvent;
  final Map<String, dynamic>? systemEvent;
}
