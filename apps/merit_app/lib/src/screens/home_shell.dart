import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/merit_repository.dart';
import 'mfa_gate.dart';
import 'password_setup_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _search = TextEditingController();
  late final MeritRepository _repository;
  Map<String, dynamic>? _profile;
  List<StaffMember> _staff = const [];
  List<MeritEvent> _events = const [];
  List<Map<String, dynamic>> _profiles = const [];
  int _defaultScore = 50;
  int _selectedPage = 0;
  bool _loading = true;
  bool _mfaRequired = false;
  bool _passwordSetupRequired = false;
  String? _loadError;

  bool get _isOwner => _profile?['role'] == 'owner';
  bool get _isExecutive => _profile?['role'] == 'owner' || _profile?['role'] == 'ceo';
  bool get _isStaff => _profile?['role'] == 'staff';

  @override
  void initState() {
    super.initState();
    _repository = MeritRepository(Supabase.instance.client);
    _loadProfile();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await _repository.loadProfile(user.id);
      _profile = profile;
      if (profile['must_set_password'] == true) {
        setState(() {
          _passwordSetupRequired = true;
          _loading = false;
        });
        return;
      }
      if (profile['role'] == 'owner' || profile['role'] == 'ceo') {
        final aal = Supabase.instance.client.auth.mfa.getAuthenticatorAssuranceLevel();
        if (aal.currentLevel?.name != 'aal2') {
          setState(() {
            _mfaRequired = true;
            _loading = false;
          });
          return;
        }
      }
      await _loadData();
    } on MeritRepositoryException catch (error) {
      _loadError = error.message;
    } catch (_) {
      _loadError = 'Data akaun tidak dapat dimuat. Cuba semula atau hubungi pemantau sistem.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final staff = await _repository.loadStaff();
    final events = await _repository.loadEvents();
    final defaultScore = await _repository.defaultScoreTenths();
    final profiles = _isOwner ? await _repository.loadProfiles() : const <Map<String, dynamic>>[];
    _staff = staff;
    _events = events;
    _defaultScore = defaultScore;
    _profiles = profiles;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _loadData();
    } catch (_) {
      _loadError = 'Data tidak dapat dimuat. Periksa sambungan dan cuba lagi.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _afterMfa() async {
    setState(() {
      _mfaRequired = false;
      _loading = true;
    });
    try {
      await _loadData();
    } catch (_) {
      _loadError = 'Pengesahan berjaya, tetapi data tidak dapat dimuat.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_NavItem> get _navItems {
    if (_isStaff) {
      return const [
        _NavItem('Merit Saya', Icons.person_outline),
        _NavItem('Sejarah', Icons.history),
      ];
    }
    final items = <_NavItem>[
      const _NavItem('Gambaran', Icons.grid_view_outlined),
      const _NavItem('Staff', Icons.groups_outlined),
      const _NavItem('Aktiviti Merit', Icons.receipt_long_outlined),
    ];
    if (_isOwner) items.add(const _NavItem('Pengguna', Icons.manage_accounts_outlined));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_passwordSetupRequired) return const PasswordSetupPage(isRecovery: false);
    if (_mfaRequired) return MfaGate(onComplete: _afterMfa);
    if (_loading && _profile == null) return const _LoadingPage();
    if (_loadError != null && _profile == null) {
      return _FailurePage(message: _loadError!, onRetry: _loadProfile);
    }
    if (_profile == null) return _FailurePage(message: 'Profil akaun tidak dijumpai.', onRetry: _loadProfile);

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1040;
    final narrow = width < 700;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: [
            _BrandMark(),
            if (wide) ...[
              const SizedBox(width: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFEAF8F1), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [Icon(Icons.circle, size: 7, color: Color(0xFF1A9B68)), SizedBox(width: 7), Text('AKSES TERHAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF46715E)))]),
              ),
            ],
          ],
        ),
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(tooltip: 'Segarkan data', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 5),
          _AccountMenu(profile: _profile!, onSignOut: () => Supabase.instance.client.auth.signOut()),
          const SizedBox(width: 16),
        ],
      ),
      drawer: narrow ? Drawer(child: _Navigation(items: _navItems, selected: _selectedPage, onSelected: _selectPage)) : null,
      body: Row(
        children: [
          if (wide) SizedBox(width: 224, child: _Navigation(items: _navItems, selected: _selectedPage, onSelected: _selectPage)),
          Expanded(
            child: Column(
              children: [
                if (narrow)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(builder: (context) => IconButton(tooltip: 'Buka menu', onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu))),
                  ),
                Expanded(child: _loadError != null ? _FailurePage(message: _loadError!, onRetry: _refresh) : _buildPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedPage = index.clamp(0, _navItems.length - 1).toInt());
    if (MediaQuery.sizeOf(context).width < 700) Navigator.of(context).maybePop();
  }

  Widget _buildPage() {
    if (_isStaff) {
      return _selectedPage == 0 ? _staffSelfPage() : _eventsPage();
    }
    if (_selectedPage == 0) return _overviewPage();
    if (_selectedPage == 1) return _staffPage();
    if (_selectedPage == 2) return _eventsPage();
    return _usersPage();
  }

  Widget _overviewPage() {
    final active = _staff.where((staff) => !staff.archived).toList();
    final average = active.isEmpty ? '—' : formatMerit((active.map((s) => s.scoreTenths).reduce((a, b) => a + b) / active.length).round());
    final firstOfMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final monthChanges = _events.where((event) => event.type == 'adjustment' && event.createdAt.toLocal().isAfter(firstOfMonth)).toList();
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      padding: EdgeInsets.fromLTRB(width < 700 ? 18 : 32, 18, width < 700 ? 18 : 32, 30),
      children: [
        _PageHeading(title: 'Direktori staff & merit', subtitle: 'Semak skor semasa dan rekod perubahan merit.', actions: [
          if (_isOwner || _isExecutive)
            OutlinedButton.icon(onPressed: _openInvite, icon: const Icon(Icons.mail_outline), label: const Text('Jemput pengguna')),
          const SizedBox(width: 8),
          if (_isOwner || _isExecutive)
            FilledButton.icon(onPressed: _openAddStaff, icon: const Icon(Icons.person_add_alt_1), label: const Text('Tambah staff')),
        ]),
        const SizedBox(height: 22),
        _StatsRow(items: [
          _StatItem('STAFF AKTIF', '${active.length}', 'Rekod aktif dalam sistem', Icons.groups_outlined),
          _StatItem('PURATA MERIT', average, 'Daripada rekod yang boleh dilihat', Icons.analytics_outlined),
          _StatItem('PELARASAN TERKINI', '${monthChanges.length}', 'Daripada maksimum 100 rekod terkini', Icons.trending_up),
        ]),
        const SizedBox(height: 22),
        _DirectoryCard(
          staff: active.where((item) => '${item.code} ${item.name} ${item.department ?? ''}'.toLowerCase().contains(_search.text.toLowerCase())).take(8).toList(),
          events: _events,
          canAdjust: _isExecutive,
          search: _search,
          onAdjust: _openAdjustment,
          onViewAll: () => _selectPage(_isStaff ? 0 : 1),
          onSearchChanged: () => setState(() {}),
          loading: _loading,
        ),
      ],
    );
  }

  Widget _staffPage() {
    final staff = _staff.where((item) => '${item.code} ${item.name} ${item.department ?? ''}'.toLowerCase().contains(_search.text.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 30),
      children: [
        _PageHeading(title: 'Direktori staff', subtitle: 'Senarai staff dan skor merit semasa.', actions: [
          if (_isOwner || _isExecutive) FilledButton.icon(onPressed: _openAddStaff, icon: const Icon(Icons.person_add_alt_1), label: const Text('Tambah staff')),
        ]),
        const SizedBox(height: 20),
        _DirectoryCard(staff: staff, events: _events, canAdjust: _isExecutive, search: _search, onAdjust: _openAdjustment, onViewAll: () {}, onSearchChanged: () => setState(() {}), loading: _loading),
      ],
    );
  }

  Widget _staffSelfPage() {
    final ownId = _profile?['staff_id'];
    final own = _staff.where((item) => item.id == ownId).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _PageHeading(title: 'Merit saya', subtitle: 'Skor dan sejarah merit akaun anda.'),
        const SizedBox(height: 20),
        if (own.isEmpty)
          const _EmptyState(icon: Icons.person_off_outlined, title: 'Rekod staff belum dipautkan', detail: 'Hubungi pemantau sistem untuk menghubungkan akaun anda kepada rekod staff.'
          )
        else ...[
          _SelfScoreCard(staff: own.single),
          const SizedBox(height: 18),
          _EventsCard(events: _events, canSeeAllStaff: false),
        ],
      ],
    );
  }

  Widget _eventsPage() => ListView(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 30),
        children: [
          _PageHeading(title: _isStaff ? 'Sejarah merit' : 'Aktiviti merit', subtitle: 'Rekod perubahan merit yang dibenarkan untuk akaun ini.'),
          const SizedBox(height: 20),
          _EventsCard(events: _events, canSeeAllStaff: _isExecutive),
        ],
      );

  Widget _usersPage() => ListView(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 30),
        children: [
          _PageHeading(title: 'Pengguna & jemputan', subtitle: 'Akses tertutup. Hanya Owner boleh menghantar jemputan dan menetapkan peranan.', actions: [
            FilledButton.icon(onPressed: _openInvite, icon: const Icon(Icons.mail_outline), label: const Text('Jemput pengguna')),
          ]),
          const SizedBox(height: 20),
          Card(child: _profiles.isEmpty
              ? const _EmptyState(icon: Icons.people_outline, title: 'Belum ada pengguna tambahan', detail: 'Ceo dan staff boleh ditambah melalui jemputan e-mel.')
              : Column(children: _profiles.map((profile) => _ProfileRow(profile: profile)).toList())),
          const SizedBox(height: 14),
          const _InfoBanner(text: 'Pendaftaran awam ditutup. E-mel jemputan dihantar oleh Supabase Auth menggunakan SMTP yang disediakan pemilik sistem.'),
        ],
      );

  Future<void> _openAddStaff() async {
    final created = await showDialog<bool>(context: context, builder: (_) => _AddStaffDialog(defaultScoreTenths: _defaultScore, repository: _repository));
    if (created == true) await _refresh();
  }

  Future<void> _openAdjustment(StaffMember staff) async {
    final change = await showDialog<_AdjustmentInput>(context: context, builder: (_) => _AdjustmentDialog(staff: staff));
    if (change == null) return;
    try {
      await _repository.adjustMerit(staffId: staff.id, deltaTenths: change.deltaTenths, reason: change.reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelarasan merit berjaya direkodkan.')));
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openInvite() async {
    final invited = await showDialog<bool>(context: context, builder: (_) => _InviteDialog(repository: _repository, staff: _staff, profiles: _profiles));
    if (invited == true) await _refresh();
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.items, required this.selected, required this.onSelected});
  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE3E9F2)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                child: ListTile(
                  selected: i == selected,
                  selectedTileColor: const Color(0xFFEEF3FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: Icon(items[i].icon, size: 20),
                  title: Text(items[i].label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onTap: () => onSelected(i),
                ),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(14),
              child: _InfoBanner(text: 'Akses jemputan sahaja\nData merit dilindungi'),
            ),
          ],
        ),
      );
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.profile, required this.onSignOut});
  final Map<String, dynamic> profile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Menu akaun',
        onSelected: (value) {
          if (value == 'signout') onSignOut();
        },
        itemBuilder: (_) => const [PopupMenuItem(value: 'signout', child: ListTile(leading: Icon(Icons.logout), title: Text('Log keluar')))],
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE3E9F2)), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            CircleAvatar(radius: 14, backgroundColor: const Color(0xFFEAF0FF), child: Text((profile['display_name'] as String).characters.first.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF245CEB)))),
            const SizedBox(width: 9),
            if (MediaQuery.sizeOf(context).width > 460)
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(profile['display_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(_roleLabel(profile['role'] as String), style: const TextStyle(color: Color(0xFF667894), fontSize: 10)),
              ]),
            const SizedBox(width: 5),
            const Icon(Icons.expand_more, size: 18),
          ]),
        ),
      );
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF172033), borderRadius: BorderRadius.circular(8)), child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        const SizedBox(width: 9),
        Text('Merit Tracker', style: Theme.of(context).textTheme.titleMedium),
      ]);
}

class _StatItem {
  const _StatItem(this.label, this.value, this.detail, this.icon);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 820;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items.map((item) => SizedBox(
        width: narrow ? double.infinity : (MediaQuery.sizeOf(context).width - 320) / 3,
        child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.label, style: const TextStyle(fontSize: 10, color: Color(0xFF667894), fontWeight: FontWeight.w700, letterSpacing: .3)), Icon(item.icon, size: 18, color: const Color(0xFF245CEB))]),
          const SizedBox(height: 12),
          Text(item.value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: Color(0xFF141C2E))),
          const SizedBox(height: 4),
          Text(item.detail, style: const TextStyle(fontSize: 11, color: Color(0xFF667894))),
        ]))),
      )).toList(),
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({required this.staff, required this.events, required this.canAdjust, required this.search, required this.onAdjust, required this.onViewAll, required this.onSearchChanged, required this.loading});
  final List<StaffMember> staff;
  final List<MeritEvent> events;
  final bool canAdjust;
  final TextEditingController search;
  final ValueChanged<StaffMember> onAdjust;
  final VoidCallback onViewAll;
  final VoidCallback onSearchChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 820;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text('Staff dan skor semasa', style: Theme.of(context).textTheme.titleMedium)), TextButton(onPressed: onViewAll, child: const Text('Lihat semua'))]),
          const SizedBox(height: 14),
          TextField(controller: search, onChanged: (_) => onSearchChanged(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari kod staff atau nama', isDense: true)),
          const SizedBox(height: 14),
          if (loading && staff.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (staff.isEmpty)
            const _EmptyState(icon: Icons.groups_outlined, title: 'Belum ada rekod staff', detail: 'Tambah rekod pertama untuk mula mengurus merit.')
          else if (narrow)
            Column(children: staff.map((item) => _StaffCard(staff: item, latest: _latestFor(item, events), canAdjust: canAdjust, onAdjust: onAdjust)).toList())
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                columns: const [DataColumn(label: Text('KOD STAFF')), DataColumn(label: Text('NAMA')), DataColumn(label: Text('JABATAN')), DataColumn(label: Text('MERIT')), DataColumn(label: Text('PERUBAHAN TERKINI')), DataColumn(label: Text('TINDAKAN'))],
                rows: staff.map((item) {
                  final latest = _latestFor(item, events);
                  return DataRow(cells: [
                    DataCell(Text(item.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(item.department ?? '—')),
                    DataCell(Text(formatMerit(item.scoreTenths), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    DataCell(latest == null ? const Text('Belum ada perubahan') : _DeltaPill(delta: latest.deltaTenths)),
                    DataCell(canAdjust ? OutlinedButton(onPressed: () => onAdjust(item), child: const Text('Pelarasan')) : const Text('—')),
                  ]);
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }
}

MeritEvent? _latestFor(StaffMember staff, List<MeritEvent> events) {
  for (final event in events) {
    if (event.staffId == staff.id && event.type == 'adjustment') return event;
  }
  return null;
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff, required this.latest, required this.canAdjust, required this.onAdjust});
  final StaffMember staff;
  final MeritEvent? latest;
  final bool canAdjust;
  final ValueChanged<StaffMember> onAdjust;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE3E9F2)), borderRadius: BorderRadius.circular(9)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w700))), Text(formatMerit(staff.scoreTenths), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 5),
          Text('${staff.code}  •  ${staff.department ?? 'Tiada jabatan'}', style: const TextStyle(color: Color(0xFF667894), fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [if (latest != null) _DeltaPill(delta: latest!.deltaTenths), const Spacer(), if (canAdjust) OutlinedButton(onPressed: () => onAdjust(staff), child: const Text('Pelarasan'))]),
        ]),
      );
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});
  final int delta;
  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = delta == 0 ? const Color(0xFF667894) : positive ? const Color(0xFF16804A) : const Color(0xFFB42318);
    final bg = delta == 0 ? const Color(0xFFF0F3F8) : positive ? const Color(0xFFE8F7EE) : const Color(0xFFFFEEEE);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Text(formatDelta(delta), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)));
  }
}

class _SelfScoreCard extends StatelessWidget {
  const _SelfScoreCard({required this.staff});
  final StaffMember staff;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MERIT SEMASA', style: TextStyle(fontSize: 11, letterSpacing: .5, color: Color(0xFF667894), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(formatMerit(staff.scoreTenths), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Color(0xFF172033))),
        Text('${staff.code}  •  ${staff.name}', style: const TextStyle(color: Color(0xFF667894))),
      ])));
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events, required this.canSeeAllStaff});
  final List<MeritEvent> events;
  final bool canSeeAllStaff;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const Card(child: _EmptyState(icon: Icons.history, title: 'Belum ada aktiviti', detail: 'Rekod merit akan dipaparkan di sini.'));
    return Card(child: Column(children: events.map((event) => ListTile(
      leading: CircleAvatar(backgroundColor: event.deltaTenths >= 0 ? const Color(0xFFE8F7EE) : const Color(0xFFFFEEEE), child: Icon(event.deltaTenths >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: event.deltaTenths >= 0 ? const Color(0xFF16804A) : const Color(0xFFB42318), size: 18)),
      title: Text(canSeeAllStaff ? '${event.staffName ?? 'Staff'}  •  ${formatDelta(event.deltaTenths)}' : '${formatDelta(event.deltaTenths)}  •  ${formatMerit(event.afterTenths)} merit', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${event.reason}\n${formatDate(event.createdAt)}', maxLines: 3, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      trailing: Text(formatMerit(event.afterTenths), style: const TextStyle(fontWeight: FontWeight.w700)),
    )).toList()));
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(child: Text((profile['display_name'] as String).characters.first.toUpperCase())),
        title: Text(profile['display_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(profile['email'] as String),
        trailing: Chip(label: Text(_roleLabel(profile['role'] as String))),
      );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle, this.actions = const []});
  final String title;
  final String subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF667894))),
    ]);
    if (MediaQuery.sizeOf(context).width < 760) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading,
        if (actions.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: actions)],
      ]);
    }
    return Row(children: [Expanded(child: heading), ...actions]);
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF0F4FA), borderRadius: BorderRadius.circular(8)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, size: 18, color: Color(0xFF667894)), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF53637D), fontSize: 12)))]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(26), child: Column(children: [Icon(icon, size: 30, color: const Color(0xFF7A8AA3)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667894), fontSize: 12))]));
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _FailurePage extends StatelessWidget {
  const _FailurePage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 38, color: Color(0xFF667894)), const SizedBox(height: 14), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Cuba semula'))]))));
}

String _roleLabel(String role) => switch (role) {
      'owner' => 'Pemantau sistem',
      'ceo' => 'CEO',
      _ => 'Staff',
    };

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog({required this.defaultScoreTenths, required this.repository});
  final int defaultScoreTenths;
  final MeritRepository repository;
  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _department = TextEditingController();
  final _score = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _score.text = formatMerit(widget.defaultScoreTenths);
  }
  @override
  void dispose() { _code.dispose(); _name.dispose(); _department.dispose(); _score.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final scoreTenths = parseScoreTenths(_score.text);
      if (scoreTenths == null) throw const MeritRepositoryException('Gunakan skor sah dengan maksimum satu tempat perpuluhan.');
      await widget.repository.createStaff(code: _code.text, name: _name.text, department: _department.text, startingScoreTenths: scoreTenths);
      if (mounted) Navigator.pop(context, true);
    } on MeritRepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Semak nilai merit dan cuba lagi.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Tambah staff'),
        content: SizedBox(width: 420, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Kod staff'), validator: _required),
          const SizedBox(height: 10),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama penuh'), validator: _required),
          const SizedBox(height: 10),
          TextFormField(controller: _department, decoration: const InputDecoration(labelText: 'Jabatan (pilihan)')),
          const SizedBox(height: 10),
          TextFormField(controller: _score, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Skor permulaan'), validator: (value) => parseScoreTenths(value ?? '') == null ? 'Gunakan skor sah dengan maksimum satu tempat perpuluhan.' : null),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318)))),
        ]))),
        actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Menyimpan…' : 'Simpan staff'))],
      );
}

class _AdjustmentInput {
  const _AdjustmentInput(this.deltaTenths, this.reason);
  final int deltaTenths;
  final String reason;
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.staff});
  final StaffMember staff;
  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _reason = TextEditingController();
  int _direction = 1;
  int _step = 10;
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final after = widget.staff.scoreTenths + _direction * _step;
    return AlertDialog(
      title: const Text('Pelarasan merit'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${widget.staff.code}  •  ${widget.staff.name}', style: const TextStyle(color: Color(0xFF667894))),
        const SizedBox(height: 16),
        SegmentedButton<int>(segments: const [ButtonSegment(value: 1, label: Text('Tambah'), icon: Icon(Icons.add)), ButtonSegment(value: -1, label: Text('Kurang'), icon: Icon(Icons.remove))], selected: {_direction}, onSelectionChanged: (selection) => setState(() => _direction = selection.first)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: _step, decoration: const InputDecoration(labelText: 'Jumlah perubahan'), items: List.generate(10, (index) { final amount = (index + 1) * 10; return DropdownMenuItem(value: amount, child: Text(formatMerit(amount))); }), onChanged: (value) => setState(() => _step = value ?? 10)),
        const SizedBox(height: 12),
        TextField(controller: _reason, onChanged: (_) => setState(() {}), minLines: 2, maxLines: 4, maxLength: 500, decoration: const InputDecoration(labelText: 'Sebab (wajib)', alignLabelWithHint: true)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF3F6FB), borderRadius: BorderRadius.circular(8)), child: Text('${formatMerit(widget.staff.scoreTenths)}  →  ${formatDelta(_direction * _step)}  →  ${formatMerit(after)}', style: const TextStyle(fontWeight: FontWeight.w700))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _AdjustmentInput(_direction * _step, _reason.text.trim())), child: const Text('Sahkan perubahan'))],
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.repository, required this.staff, required this.profiles});
  final MeritRepository repository;
  final List<StaffMember> staff;
  final List<Map<String, dynamic>> profiles;
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  String _role = 'staff';
  String? _staffId;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (!widget.profiles.any((item) => item['role'] == 'ceo')) _role = 'ceo';
  }
  @override
  void dispose() { _email.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repository.inviteUser(email: _email.text, displayName: _name.text, role: _role, staffId: _role == 'staff' ? _staffId : null);
      if (mounted) Navigator.pop(context, true);
    } on MeritRepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Jemputan tidak berjaya. Semak SMTP dan cuba lagi.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = widget.profiles.map((item) => item['staff_id']).whereType<String>().toSet();
    final available = widget.staff.where((item) => !item.archived && !assigned.contains(item.id)).toList();
    final ceoExists = widget.profiles.any((item) => item['role'] == 'ceo');
    if (_role == 'staff' && _staffId != null && !available.any((item) => item.id == _staffId)) _staffId = null;
    return AlertDialog(
      title: const Text('Jemput pengguna'),
      content: SizedBox(width: 440, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Pautan jemputan akan dihantar ke e-mel. SMTP production mesti telah disediakan.'),
        const SizedBox(height: 14),
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mel'), validator: (value) => value == null || !value.trim().contains('@') ? 'Masukkan e-mel yang sah.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama pengguna'), validator: _required),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _role, decoration: const InputDecoration(labelText: 'Peranan'), items: [if (!ceoExists) const DropdownMenuItem(value: 'ceo', child: Text('CEO')), const DropdownMenuItem(value: 'staff', child: Text('Staff — paparan sendiri'))], onChanged: (value) => setState(() { _role = value ?? 'staff'; _staffId = null; })),
        if (_role == 'staff') ...[
          const SizedBox(height: 10),
          if (available.isEmpty)
            const Text('Tambah rekod staff dahulu sebelum menghantar jemputan staff.', style: TextStyle(color: Color(0xFF667894), fontSize: 12))
          else
            DropdownButtonFormField<String>(initialValue: _staffId, decoration: const InputDecoration(labelText: 'Pautkan rekod staff'), items: available.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.code} — ${item.name}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => _staffId = value), validator: (value) => _role == 'staff' && value == null ? 'Pilih rekod staff.' : null),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318)))),
      ]))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')), FilledButton.icon(onPressed: _busy || (_role == 'staff' && available.isEmpty) ? null : _send, icon: const Icon(Icons.send_outlined), label: Text(_busy ? 'Menghantar…' : 'Hantar jemputan'))],
    );
  }
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'Medan ini wajib diisi.' : null;
