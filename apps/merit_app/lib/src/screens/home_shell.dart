import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/merit_repository.dart';
import '../utils/pwa_bridge.dart';
import 'csv_import_dialog.dart';
import 'reports_page.dart';
import 'audit_page.dart';
import '../widgets/glassy_otp_view.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

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
  Set<String> _permissions = {};
  int _defaultScore = 50;
  int _selectedPage = 0;
  bool _loading = true;
  String? _loadError;

  bool get _isOwner => _profile?['role'] == 'owner';
  bool get _isStaff => _profile?['role'] == 'staff';
  bool _hasPermission(String key) => _isOwner || _permissions.contains(key);

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
      _permissions = _isOwner ? const {} : await _repository.loadPermissions(user.id);
      await _loadData();
      autoCheckAuthenticatedIosPwa();
    } on MeritRepositoryException catch (error) {
      _loadError = error.message;
    } catch (_) {
      _loadError = 'Account data could not be loaded. Try again or contact the system owner.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final canReadStaff = _hasPermission('staff.read.all') || _hasPermission('merit.read.self');
    final canReadEvents = _hasPermission('merit.read.all') || _hasPermission('merit.read.self');
    final staff = canReadStaff ? await _repository.loadStaff() : <StaffMember>[];
    final events = canReadEvents ? await _repository.loadEvents() : <MeritEvent>[];
    final defaultScore = _hasPermission('staff.create') || _hasPermission('staff.import') || _hasPermission('settings.manage')
        ? await _repository.defaultScoreTenths()
        : 50;
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      _profile = await _repository.loadProfile(user.id);
      _permissions = _isOwner ? const {} : await _repository.loadPermissions(user.id);
      await _loadData();
    } catch (_) {
      _loadError = 'Data could not be loaded. Check your connection and try again.';
    } finally {
      if (mounted) {
        setState(() {
          if (_navItems.isNotEmpty) {
            _selectedPage = _selectedPage.clamp(0, _navItems.length - 1).toInt();
          }
          _loading = false;
        });
      }
    }
  }

  List<_NavItem> get _navItems {
    final items = <_NavItem>[];
    if (_isStaff && _hasPermission('merit.read.self')) {
      items.add(const _NavItem('My Merit', Icons.person_outline, 'self', mobileLabel: 'Merit'));
      items.add(const _NavItem('My History', Icons.history, 'self-events', mobileLabel: 'History'));
    }
    if (_hasPermission('staff.read.all')) {
      items.add(const _NavItem('Dashboard', Icons.dashboard_outlined, 'dashboard', mobileLabel: 'Board'));
    }
    if (_hasPermission('staff.read.all') ||
        _hasPermission('staff.create') ||
        _hasPermission('staff.update') ||
        _hasPermission('staff.archive') ||
        _hasPermission('staff.delete') ||
        _hasPermission('staff.import')) {
      items.add(const _NavItem('Staff', Icons.badge_outlined, 'staff', mobileLabel: 'Staff'));
    }
    if (_hasPermission('reports.read')) {
      items.add(const _NavItem('Reports', Icons.bar_chart_outlined, 'reports'));
    }
    if (_hasPermission('users.manage')) {
      items.add(const _NavItem('Users', Icons.manage_accounts_outlined, 'users'));
    }
    if (_hasPermission('settings.manage')) {
      items.add(const _NavItem('Settings', Icons.tune_outlined, 'settings'));
    }
    if (_hasPermission('audit.read') || _hasPermission('merit.read.all')) {
      items.add(const _NavItem('Audit Log', Icons.fact_check_outlined, 'audit', mobileLabel: 'Audit'));
    }
    return items;
  }

  Future<void> _openProfileDialog() async {
    if (_profile == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ProfileAccountDialog(
        profile: _profile!,
        repository: _repository,
        onAvatarUpdated: _refresh,
        onSignOut: () => Supabase.instance.client.auth.signOut(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) return const _LoadingPage();
    if (_loadError != null && _profile == null) {
      return _FailurePage(message: _loadError!, onRetry: _loadProfile);
    }
    if (_profile == null) {
      return _FailurePage(message: 'Account profile could not be found.', onRetry: _loadProfile);
    }

    final width = MediaQuery.sizeOf(context).width;
    if (_navItems.isEmpty) {
      return const Scaffold(
        body: Center(
          child: _EmptyState(
            icon: Icons.lock_outline,
            title: 'Access not granted',
            detail: 'Contact the system owner to enable permissions for this account.',
          ),
        ),
      );
    }
    final wide = width >= 1040;
    final narrow = width < 1040;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: [
            _BrandMark(),
            if (wide) ...[
              const SizedBox(width: 22),
              const Tooltip(
                message: 'Only invited accounts can sign in.',
                child: Icon(Icons.lock_outline, size: 17, color: Color(0xFF667894)),
              ),
            ],
          ],
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: ThinkingOrbsLoader(size: 22, label: 'Refreshing data'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              if (wide)
                SizedBox(
                  width: 224,
                  child: _Navigation(
                    items: _navItems,
                    selected: _selectedPage,
                    onSelected: _selectPage,
                    profile: _profile!,
                    onOpenProfile: _openProfileDialog,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: narrow ? 88 + MediaQuery.paddingOf(context).bottom : 0,
                  ),
                  child: _loadError != null
                      ? _FailurePage(message: _loadError!, onRetry: _refresh)
                      : SmoothStepSwitcher(
                          child: KeyedSubtree(
                            key: ValueKey(_navItems[_selectedPage].route),
                            child: _buildPage(),
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (narrow) _mobileNavigation(),
        ],
      ),
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedPage = index.clamp(0, _navItems.length - 1).toInt());
  }

  Widget _buildPage() {
    final route = _navItems[_selectedPage].route;
    return switch (route) {
      'dashboard' => _dashboardPage(),
      'staff' => _staffRegistrationPage(),
      'self' => _staffSelfPage(),
      'self-events' => _eventsPage(),
      'reports' => ReportsPage(
          repository: _repository,
          staff: _staff,
          canExport: _hasPermission('reports.export'),
        ),
      'users' => _usersPage(),
      'settings' => _settingsPage(),
      'audit' => AuditPage(
          repository: _repository,
          canReadSystemAudit: _hasPermission('audit.read'),
        ),
      _ => const _EmptyState(
          icon: Icons.lock_outline,
          title: 'Page unavailable',
          detail: 'Contact the system owner for access.',
        ),
    };
  }

  Widget _mobileNavigation() => Positioned(
        left: 12,
        right: 12,
        bottom: 8,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFDCE5F2), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFCBD6E6), blurRadius: 0, offset: Offset(0, 3)),
                      BoxShadow(color: Color(0x180F1D36), blurRadius: 22, offset: Offset(0, 7)),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (var index = 0; index < _visibleMobileNavItems.length; index++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _visibleMobileNavItems[index] == _selectedPage,
                            label: _navItems[_visibleMobileNavItems[index]].label,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _selectPage(_visibleMobileNavItems[index]),
                              child: AnimatedContainer(
                                duration: MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: _visibleMobileNavItems[index] == _selectedPage
                                      ? const Color(0xFFEEF3FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _navItems[_visibleMobileNavItems[index]].icon,
                                      size: 20,
                                      color: _visibleMobileNavItems[index] == _selectedPage
                                          ? const Color(0xFF245CEB)
                                          : const Color(0xFF667894),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _navItems[_visibleMobileNavItems[index]].mobileLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: _visibleMobileNavItems[index] == _selectedPage
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _visibleMobileNavItems[index] == _selectedPage
                                            ? const Color(0xFF245CEB)
                                            : const Color(0xFF667894),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Account profile',
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _openProfileDialog,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .97),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDCE5F2), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFFCBD6E6), blurRadius: 0, offset: Offset(0, 3)),
                        BoxShadow(color: Color(0x180F1D36), blurRadius: 22, offset: Offset(0, 7)),
                      ],
                    ),
                    child: Center(
                      child: _ProfileAvatar(profile: _profile!, radius: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  List<int> get _visibleMobileNavItems => List<int>.generate(_navItems.length, (index) => index);

  Widget _dashboardPage() {
    final active = _staff.where((staff) => !staff.archived).toList();
    final staff = active
        .where((item) =>
            '${item.code} ${item.name} ${item.department ?? ''}'.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: _DashboardMeritCard(
        staff: staff,
        events: _events,
        canAdjust: _hasPermission('merit.adjust'),
        canCorrect: _hasPermission('merit.correct'),
        search: _search,
        onAdjust: _openAdjustment,
        onCorrect: _openCorrection,
        onSearchChanged: () => setState(() {}),
        loading: _loading,
      ),
    );
  }

  Widget _staffRegistrationPage() {
    final staff = _staff
        .where((item) =>
            '${item.code} ${item.name} ${item.department ?? ''}'.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: _StaffRosterCard(
        staff: staff,
        canCreate: _hasPermission('staff.create'),
        canImport: _hasPermission('staff.import'),
        canEdit: _hasPermission('staff.update'),
        canArchive: _hasPermission('staff.archive'),
        canDelete: _hasPermission('staff.delete'),
        search: _search,
        onAddStaff: _openAddStaff,
        onImportCsv: _openCsvImport,
        onEdit: _openEditStaff,
        onArchive: _toggleStaffArchived,
        onDelete: _deleteStaff,
        onSearchChanged: () => setState(() {}),
        loading: _loading,
      ),
    );
  }

  Widget _staffSelfPage() {
    final ownId = _profile?['staff_id'];
    final own = _staff.where((item) => item.id == ownId).toList();
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(18),
        child: own.isEmpty
            ? const Center(
                child: _EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'No staff record linked',
                  detail: 'Contact the system owner to link your account to a staff record.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelfScoreCard(staff: own.single),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _EventsCard(events: _events, canSeeAllStaff: false),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _eventsPage() {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: _EventsCard(events: _events, canSeeAllStaff: _hasPermission('merit.read.all')),
        ),
      ),
    );
  }

  Widget _usersPage() {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: _openInvite,
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Invite user'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _profiles.isEmpty
                  ? const Center(
                      child: _EmptyState(
                        icon: Icons.people_outline,
                        title: 'No additional users',
                        detail: 'Use Invite user to add accounts.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _profiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEF2F8)),
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return _UserAccessRow(
                          profile: profile,
                          onPermissions: () => _editUserPermissions(profile),
                          onToggleActive: () => _toggleUserActive(profile),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddStaff() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStaffDialog(defaultScoreTenths: _defaultScore, repository: _repository),
    );
    if (created == true) await _refresh();
  }

  Future<void> _openEditStaff(StaffMember staff) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStaffDialog(defaultScoreTenths: _defaultScore, repository: _repository, staff: staff),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _openCsvImport() async {
    final imported = await showDialog<bool>(context: context, builder: (_) => CsvImportDialog(repository: _repository));
    if (imported == true) await _refresh();
  }

  Future<void> _toggleStaffArchived(StaffMember staff) async {
    final archive = !staff.archived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archive ? 'Archive staff?' : 'Restore staff?'),
        content: Text(
          archive
              ? '${staff.name}’s record and merit history will be retained. Their account will not be deleted.'
              : '${staff.name} will return to the active staff list.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(archive ? 'Archive' : 'Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.setStaffArchived(staff.id, archive);
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteStaff(StaffMember staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete staff record?'),
        content: Text(
          '${staff.name} can only be deleted if no account is linked and no merit history exists. Records with history must be archived.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete record')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteStaffWithoutHistory(staff.id);
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editUserPermissions(Map<String, dynamic> profile) async {
    final existing = (profile['user_permissions'] as List<dynamic>? ?? const [])
        .map((item) => (item as Map<String, dynamic>)['permission_key'] as String)
        .toSet();
    final updated = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _PermissionsDialog(profile: profile, selected: existing),
    );
    if (updated == null) return;
    try {
      await _repository.setUserPermissions(profile['user_id'] as String, updated);
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _toggleUserActive(Map<String, dynamic> profile) async {
    final active = profile['is_active'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Activate account?' : 'Deactivate account?'),
        content: Text(
          active
              ? 'This user will be able to sign in again.'
              : 'The user will lose access to data as soon as this change is saved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(active ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.setUserActive(profile['user_id'] as String, active);
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _settingsPage() => _SettingsPage(repository: _repository, onSaved: _refresh);

  Future<void> _openAdjustment(StaffMember staff) async {
    if (!_hasPermission('merit.adjust')) return;
    final change = await showDialog<_AdjustmentInput>(
      context: context,
      builder: (_) => _AdjustmentDialog(staff: staff),
    );
    if (change == null) return;
    try {
      await _repository.adjustMerit(
        staffId: staff.id,
        deltaTenths: change.deltaTenths,
        reason: change.reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merit adjustment recorded.')),
      );
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCorrection(StaffMember staff) async {
    final correction = await showDialog<_CorrectionInput>(
      context: context,
      builder: (_) => _CorrectionDialog(staff: staff),
    );
    if (correction == null) return;
    try {
      await _repository.correctMerit(
        staffId: staff.id,
        scoreTenths: correction.scoreTenths,
        reason: correction.reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correction recorded in merit history.')),
      );
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openInvite() async {
    final invited = await showDialog<bool>(
      context: context,
      builder: (_) => _InviteDialog(repository: _repository, staff: _staff, profiles: _profiles),
    );
    if (invited == true) await _refresh();
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route, {String? mobileLabel}) : mobileLabel = mobileLabel ?? label;
  final String label;
  final String mobileLabel;
  final IconData icon;
  final String route;
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.profile,
    required this.onOpenProfile,
  });
  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Map<String, dynamic> profile;
  final VoidCallback onOpenProfile;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: _AccountTrigger(
                profile: profile,
                onTap: onOpenProfile,
                expanded: true,
              ),
            ),
          ],
        ),
      );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, this.radius = 16});
  final Map<String, dynamic> profile;
  final double radius;

  Uint8List? _decodeAvatar(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeAvatar(profile['avatar_url'] as String?);
    final name = (profile['display_name'] as String? ?? 'U').trim();
    final initial = name.isEmpty ? 'U' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF0FF),
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF245CEB),
              ),
            )
          : null,
    );
  }
}

class _AccountTrigger extends StatelessWidget {
  const _AccountTrigger({required this.profile, required this.onTap, this.expanded = false});
  final Map<String, dynamic> profile;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Surface3DCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderRadius: 12,
        interactive: true,
        onTap: onTap,
        child: Row(
          children: [
            _ProfileAvatar(profile: profile, radius: 15),
            const SizedBox(width: 9),
            if (expanded || MediaQuery.sizeOf(context).width > 460)
              Expanded(
                flex: expanded ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile['display_name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF141C2E)),
                    ),
                    Text(
                      _roleLabel(profile['role'] as String),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667894), fontSize: 10),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF245CEB)),
          ],
        ),
      );
}

class _ProfileAccountDialog extends StatefulWidget {
  const _ProfileAccountDialog({
    required this.profile,
    required this.repository,
    required this.onAvatarUpdated,
    required this.onSignOut,
  });

  final Map<String, dynamic> profile;
  final MeritRepository repository;
  final Future<void> Function() onAvatarUpdated;
  final VoidCallback onSignOut;

  @override
  State<_ProfileAccountDialog> createState() => _ProfileAccountDialogState();
}

class _ProfileAccountDialogState extends State<_ProfileAccountDialog> {
  late Map<String, dynamic> _profile = {...widget.profile};
  bool _saving = false;
  String? _error;

  Future<void> _pickPhoto() async {
    setState(() => _error = null);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 450 * 1024) {
        setState(() => _error = 'Please choose an image smaller than 450 KB.');
        return;
      }
      final name = file.name.toLowerCase();
      final mime = name.endsWith('.jpg') || name.endsWith('.jpeg') ? 'image/jpeg' : 'image/png';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() => _saving = true);
      await widget.repository.updateAvatarDataUrl(dataUrl);
      setState(() => _profile['avatar_url'] = dataUrl);
      await widget.onAvatarUpdated();
    } on MeritRepositoryException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not update photo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _installApp(String platformHint) async {
    Navigator.pop(context);
    await triggerMeritPwaInstall(platformHint);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Surface3DCard(
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MY ACCOUNT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF667894),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF667894)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD6E6), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF245CEB).withValues(alpha: 0.14),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _ProfileAvatar(profile: _profile, radius: 36),
                      ),
                      Material(
                        color: const Color(0xFF245CEB),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _saving ? null : _pickPhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.camera_alt_outlined, size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile['display_name'] as String? ?? '',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profile['email'] as String? ?? '',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF667894)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD6E3FF)),
                    ),
                    child: Text(
                      _roleLabel(_profile['role'] as String? ?? 'staff'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF245CEB),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickPhoto,
                      icon: _saving
                          ? const ThinkingOrbsLoader(size: 16, label: 'Uploading')
                          : const Icon(Icons.photo_camera_outlined, size: 17),
                      label: Text(_saving ? 'Saving photo…' : 'Change profile photo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDCE5F2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.install_mobile_rounded, size: 16, color: Color(0xFF245CEB)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Install Merit Tracker App (PWA)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF141C2E),
                                ),
                              ),
                            ),
                            const InfoTooltip(
                              message:
                                  'Install on Desktop, Android, or iPhone (iOS). iPhone opens an automatic permission & Add-to-Home-Screen guide.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEF3FF),
                                  foregroundColor: const Color(0xFF245CEB),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                                onPressed: () => _installApp('desktop'),
                                icon: const Icon(Icons.devices_rounded, size: 15),
                                label: const Text('PC / Android'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF245CEB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                                onPressed: () => _installApp('ios'),
                                icon: const Icon(Icons.phone_iphone_rounded, size: 15),
                                label: const Text('iPhone (iOS)'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF34435D),
                        side: const BorderSide(color: Color(0xFFDCE5F2)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        triggerSwarmRebuild();
                      },
                      icon: const Icon(Icons.auto_awesome_motion_rounded, size: 16, color: Color(0xFF245CEB)),
                      label: const Text(
                        'Swarm Cursors Rebuild (Alt+Shift+S)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEEEE),
                        foregroundColor: const Color(0xFFB42318),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSignOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const MeritBrand(compact: true);
}

class _DashboardMeritCard extends StatelessWidget {
  const _DashboardMeritCard({
    required this.staff,
    required this.events,
    required this.canAdjust,
    required this.canCorrect,
    required this.search,
    required this.onAdjust,
    required this.onCorrect,
    required this.onSearchChanged,
    required this.loading,
  });
  final List<StaffMember> staff;
  final List<MeritEvent> events;
  final bool canAdjust;
  final bool canCorrect;
  final TextEditingController search;
  final ValueChanged<StaffMember> onAdjust;
  final ValueChanged<StaffMember> onCorrect;
  final VoidCallback onSearchChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 820;
    return Surface3DCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: search,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search staff code or name',
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: loading && staff.isEmpty
                ? const Center(child: ThinkingOrbsLoader())
                : staff.isEmpty
                    ? const Center(
                        child: _EmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No active staff yet',
                          detail: 'Open the Staff tab to add staff records.',
                        ),
                      )
                    : narrow
                        ? ListView.builder(
                            itemCount: staff.length,
                            itemBuilder: (context, index) {
                              final item = staff[index];
                              return _DashboardStaffCard(
                                staff: item,
                                latest: _latestFor(item, events),
                                canAdjust: canAdjust,
                                canCorrect: canCorrect,
                                onAdjust: onAdjust,
                                onCorrect: onCorrect,
                              );
                            },
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.sizeOf(context).width - 310,
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                                  columns: const [
                                    DataColumn(label: Text('STAFF CODE')),
                                    DataColumn(label: Text('NAME')),
                                    DataColumn(label: Text('DEPARTMENT')),
                                    DataColumn(label: Text('MERIT')),
                                    DataColumn(label: Text('LATEST CHANGE')),
                                    DataColumn(label: Text('ACTION')),
                                  ],
                                  rows: staff.map((item) {
                                    final latest = _latestFor(item, events);
                                    return DataRow(
                                      onSelectChanged: canAdjust ? (_) => onAdjust(item) : null,
                                      cells: [
                                        DataCell(Text(item.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: canAdjust ? const Color(0xFF245CEB) : const Color(0xFF141C2E),
                                                ),
                                              ),
                                              if (canAdjust) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.touch_app_outlined, size: 15, color: Color(0xFF245CEB)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(item.department ?? '—')),
                                        DataCell(
                                          Text(
                                            formatMerit(item.scoreTenths),
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        DataCell(latest == null ? const Text('—') : _DeltaPill(delta: latest.deltaTenths)),
                                        DataCell(
                                          Wrap(
                                            spacing: 4,
                                            children: [
                                              if (canAdjust)
                                                FilledButton.tonal(
                                                  onPressed: () => onAdjust(item),
                                                  child: const Text('Adjust merit'),
                                                ),
                                              if (canCorrect)
                                                IconButton(
                                                  tooltip: 'Correct score',
                                                  onPressed: () => onCorrect(item),
                                                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StaffRosterCard extends StatelessWidget {
  const _StaffRosterCard({
    required this.staff,
    required this.canCreate,
    required this.canImport,
    required this.canEdit,
    required this.canArchive,
    required this.canDelete,
    required this.search,
    required this.onAddStaff,
    required this.onImportCsv,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onSearchChanged,
    required this.loading,
  });
  final List<StaffMember> staff;
  final bool canCreate;
  final bool canImport;
  final bool canEdit;
  final bool canArchive;
  final bool canDelete;
  final TextEditingController search;
  final VoidCallback onAddStaff;
  final VoidCallback onImportCsv;
  final ValueChanged<StaffMember> onEdit;
  final ValueChanged<StaffMember> onArchive;
  final ValueChanged<StaffMember> onDelete;
  final VoidCallback onSearchChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 820;
    return Surface3DCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: narrow ? double.infinity : 320,
                child: TextField(
                  controller: search,
                  onChanged: (_) => onSearchChanged(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search staff code, name, or department',
                    isDense: true,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canImport)
                    OutlinedButton.icon(
                      onPressed: onImportCsv,
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Import CSV'),
                    ),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: onAddStaff,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add staff'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: loading && staff.isEmpty
                ? const Center(child: ThinkingOrbsLoader())
                : staff.isEmpty
                    ? const Center(
                        child: _EmptyState(
                          icon: Icons.badge_outlined,
                          title: 'No staff registered yet',
                          detail: 'Use Add staff or Import CSV above.',
                        ),
                      )
                    : narrow
                        ? ListView.builder(
                            itemCount: staff.length,
                            itemBuilder: (context, index) {
                              final item = staff[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Surface3DCard(
                                  padding: const EdgeInsets.all(14),
                                  borderRadius: 12,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${item.code}  •  ${item.department ?? 'No department'}${item.archived ? '  •  Archived' : ''}',
                                              style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (canEdit)
                                        IconButton(
                                          tooltip: 'Edit staff',
                                          onPressed: () => onEdit(item),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      if (canArchive)
                                        IconButton(
                                          tooltip: item.archived ? 'Restore staff' : 'Archive staff',
                                          onPressed: () => onArchive(item),
                                          icon: Icon(item.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                                        ),
                                      if (canDelete)
                                        IconButton(
                                          tooltip: 'Delete staff record',
                                          onPressed: () => onDelete(item),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.sizeOf(context).width - 310,
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                                  columns: const [
                                    DataColumn(label: Text('STAFF CODE')),
                                    DataColumn(label: Text('FULL NAME')),
                                    DataColumn(label: Text('DEPARTMENT')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('MANAGE')),
                                  ],
                                  rows: staff.map((item) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                                        DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(item.department ?? '—')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: item.archived ? const Color(0xFFF0F3F8) : const Color(0xFFE8F7EE),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.archived ? 'Archived' : 'Active',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: item.archived ? const Color(0xFF667894) : const Color(0xFF16804A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Wrap(
                                            spacing: 4,
                                            children: [
                                              if (canEdit)
                                                IconButton(
                                                  tooltip: 'Edit staff',
                                                  onPressed: () => onEdit(item),
                                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                                ),
                                              if (canArchive)
                                                IconButton(
                                                  tooltip: item.archived ? 'Restore staff' : 'Archive staff',
                                                  onPressed: () => onArchive(item),
                                                  icon: Icon(item.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18),
                                                ),
                                              if (canDelete)
                                                IconButton(
                                                  tooltip: 'Delete staff without merit history',
                                                  onPressed: () => onDelete(item),
                                                  icon: const Icon(Icons.delete_outline, size: 18),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
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

class _DashboardStaffCard extends StatelessWidget {
  const _DashboardStaffCard({
    required this.staff,
    required this.latest,
    required this.canAdjust,
    required this.canCorrect,
    required this.onAdjust,
    required this.onCorrect,
  });
  final StaffMember staff;
  final MeritEvent? latest;
  final bool canAdjust;
  final bool canCorrect;
  final ValueChanged<StaffMember> onAdjust;
  final ValueChanged<StaffMember> onCorrect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Surface3DCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 12,
          interactive: canAdjust,
          onTap: canAdjust ? () => onAdjust(staff) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      staff.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: canAdjust ? const Color(0xFF245CEB) : const Color(0xFF141C2E),
                      ),
                    ),
                  ),
                  Text(
                    formatMerit(staff.scoreTenths),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${staff.code}  •  ${staff.department ?? 'No department'}',
                style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (latest != null) _DeltaPill(delta: latest!.deltaTenths),
                  if (canCorrect)
                    IconButton(
                      tooltip: 'Correct score',
                      onPressed: () => onCorrect(staff),
                      icon: const Icon(Icons.edit_note_outlined),
                    ),
                  if (canAdjust)
                    FilledButton.tonal(
                      onPressed: () => onAdjust(staff),
                      child: const Text('Adjust merit'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});
  final int delta;
  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = delta == 0
        ? const Color(0xFF667894)
        : positive
            ? const Color(0xFF16804A)
            : const Color(0xFFB42318);
    final bg = delta == 0
        ? const Color(0xFFF0F3F8)
        : positive
            ? const Color(0xFFE8F7EE)
            : const Color(0xFFFFEEEE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(formatDelta(delta), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _SelfScoreCard extends StatelessWidget {
  const _SelfScoreCard({required this.staff});
  final StaffMember staff;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE5F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT MERIT',
              style: TextStyle(fontSize: 11, letterSpacing: .5, color: Color(0xFF667894), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              formatMerit(staff.scoreTenths),
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Color(0xFF172033)),
            ),
            Text('${staff.code}  •  ${staff.name}', style: const TextStyle(color: Color(0xFF667894))),
          ],
        ),
      );
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events, required this.canSeeAllStaff});
  final List<MeritEvent> events;
  final bool canSeeAllStaff;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        title: 'No activity yet',
        detail: 'Merit records will appear here.',
      );
    }
    return Column(
      children: events
          .map(
            (event) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              leading: CircleAvatar(
                backgroundColor: event.deltaTenths >= 0 ? const Color(0xFFE8F7EE) : const Color(0xFFFFEEEE),
                child: Icon(
                  event.deltaTenths >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: event.deltaTenths >= 0 ? const Color(0xFF16804A) : const Color(0xFFB42318),
                  size: 18,
                ),
              ),
              title: Text(
                canSeeAllStaff
                    ? '${event.staffName ?? 'Staff'}  •  ${formatDelta(event.deltaTenths)}'
                    : '${formatDelta(event.deltaTenths)}  •  ${formatMerit(event.afterTenths)} merit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${event.reason}\n${formatDate(event.createdAt)}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Text(formatMerit(event.afterTenths), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
          .toList(),
    );
  }
}

class _UserAccessRow extends StatelessWidget {
  const _UserAccessRow({
    required this.profile,
    required this.onPermissions,
    required this.onToggleActive,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onPermissions;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 650;
    final name = (profile['display_name'] as String? ?? 'User').trim();
    final email = (profile['email'] as String? ?? '').trim();
    final isActive = profile['is_active'] == true;
    final role = profile['role'] as String? ?? 'staff';
    final permCount = (profile['user_permissions'] as List<dynamic>? ?? const []).length;
    final initial = name.isEmpty ? 'U' : name.characters.first.toUpperCase();

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEEF3FF),
                  child: Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF245CEB)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF141C2E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFEEF3FF) : const Color(0xFFF0F3F8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isActive ? const Color(0xFFD6E3FF) : const Color(0xFFDCE5F2)),
                  ),
                  child: Text(
                    isActive ? _roleLabel(role) : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? const Color(0xFF245CEB) : const Color(0xFF667894),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$permCount permissions',
                  style: const TextStyle(color: Color(0xFF667894), fontSize: 11.5),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Set permissions',
                  visualDensity: VisualDensity.compact,
                  onPressed: onPermissions,
                  icon: const Icon(Icons.tune_outlined, size: 20),
                ),
                IconButton(
                  tooltip: isActive ? 'Deactivate account' : 'Activate account',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleActive,
                  icon: Icon(
                    isActive ? Icons.person_off_outlined : Icons.person_outline,
                    size: 20,
                    color: isActive ? const Color(0xFFB42318) : const Color(0xFF16804A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEEF3FF),
            child: Text(
              initial,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF245CEB)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF141C2E)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$email  •  $permCount permissions',
                  style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF3FF) : const Color(0xFFF0F3F8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isActive ? const Color(0xFFD6E3FF) : const Color(0xFFDCE5F2)),
            ),
            child: Text(
              isActive ? _roleLabel(role) : 'Inactive',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isActive ? const Color(0xFF245CEB) : const Color(0xFF667894),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Set permissions',
            onPressed: onPermissions,
            icon: const Icon(Icons.tune_outlined, size: 20),
          ),
          IconButton(
            tooltip: isActive ? 'Deactivate account' : 'Activate account',
            onPressed: onToggleActive,
            icon: Icon(
              isActive ? Icons.person_off_outlined : Icons.person_outline,
              size: 20,
              color: isActive ? const Color(0xFFB42318) : const Color(0xFF16804A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.profile, required this.selected});
  final Map<String, dynamic> profile;
  final Set<String> selected;
  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late final Set<String> _selected = {...widget.selected};
  static const _permissions = <(String, String)>[
    ('staff.read.all', 'View all staff records'),
    ('staff.create', 'Add staff'),
    ('staff.update', 'Edit staff'),
    ('staff.archive', 'Archive or restore staff'),
    ('staff.delete', 'Delete staff without merit history'),
    ('staff.import', 'Import CSV'),
    ('merit.read.all', 'View all merit activity'),
    ('merit.adjust', 'Adjust merit'),
    ('merit.correct', 'Correct merit'),
    ('reports.read', 'View reports'),
    ('reports.export', 'Export reports'),
    ('settings.manage', 'Change merit settings'),
    ('audit.read', 'View audit log'),
  ];

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Permissions for ${widget.profile['display_name']}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Permissions are enforced by the database.'),
                const SizedBox(height: 8),
                ..._permissions.map(
                  (item) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.$2),
                    value: _selected.contains(item.$1),
                    onChanged: (value) => setState(() {
                      value == true ? _selected.add(item.$1) : _selected.remove(item.$1);
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save permissions')),
        ],
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.repository, required this.onSaved});
  final MeritRepository repository;
  final Future<void> Function() onSaved;
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _default = TextEditingController();
  final _floor = TextEditingController();
  final _ceiling = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _default.dispose();
    _floor.dispose();
    _ceiling.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await widget.repository.loadSettings();
      _default.text = formatMerit(values.defaultScoreTenths);
      _floor.text = values.floorTenths == null ? '' : formatMerit(values.floorTenths!);
      _ceiling.text = values.ceilingTenths == null ? '' : formatMerit(values.ceilingTenths!);
    } catch (_) {
      _error = 'Settings could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final defaultValue = parseScoreTenths(_default.text);
    final floorValue = _floor.text.trim().isEmpty ? null : parseScoreTenths(_floor.text);
    final ceilingValue = _ceiling.text.trim().isEmpty ? null : parseScoreTenths(_ceiling.text);
    if (defaultValue == null ||
        (_floor.text.trim().isNotEmpty && floorValue == null) ||
        (_ceiling.text.trim().isNotEmpty && ceilingValue == null)) {
      setState(() => _error = 'Enter a merit value with at most one decimal place.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateSettings(
        defaultScoreTenths: defaultValue,
        floorTenths: floorValue,
        ceilingTenths: ceilingValue,
      );
      await widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merit settings saved.')));
      }
    } on MeritRepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 700 ? 14 : 24, 14, width < 700 ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: ThinkingOrbsLoader())
                  : SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _default,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: const InputDecoration(
                                  labelText: 'Default starting merit score (e.g. 5.0)',
                                  suffixText: 'merit',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _floor,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: const InputDecoration(labelText: 'Minimum limit (optional)', hintText: 'Not set'),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _ceiling,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: const InputDecoration(labelText: 'Maximum limit (optional)', hintText: 'Not set'),
                              ),
                              const SizedBox(height: 18),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const ThinkingOrbsLoader(size: 18, label: 'Saving settings')
                                      : const Icon(Icons.save_outlined),
                                  label: Text(_saving ? 'Saving…' : 'Save settings'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF7A8AA3)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667894), fontSize: 12)),
          ],
        ),
      );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: ThinkingOrbsLoader(size: 44)));
}

class _FailurePage extends StatelessWidget {
  const _FailurePage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 38, color: Color(0xFF667894)),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
}

String _roleLabel(String role) => switch (role) {
      'owner' => 'System owner',
      'ceo' => 'CEO',
      _ => 'Staff',
    };

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog({required this.defaultScoreTenths, required this.repository, this.staff});
  final int defaultScoreTenths;
  final MeritRepository repository;
  final StaffMember? staff;
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
    final staff = widget.staff;
    _score.text = formatMerit(staff?.scoreTenths ?? widget.defaultScoreTenths);
    _code.text = staff?.code ?? '';
    _name.text = staff?.name ?? '';
    _department.text = staff?.department ?? '';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _department.dispose();
    _score.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final staff = widget.staff;
      if (staff == null) {
        final scoreTenths = parseScoreTenths(_score.text);
        if (scoreTenths == null) {
          throw const MeritRepositoryException('Enter a valid score with at most one decimal place.');
        }
        await widget.repository.createStaff(
          code: _code.text,
          name: _name.text,
          department: _department.text,
          startingScoreTenths: scoreTenths,
        );
      } else {
        await widget.repository.updateStaff(
          staff,
          code: _code.text,
          name: _name.text,
          department: _department.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on MeritRepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Please check the merit value and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.staff == null ? 'Add staff' : 'Edit staff record'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Staff code'), validator: _required),
                const SizedBox(height: 10),
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: _required),
                const SizedBox(height: 10),
                TextFormField(controller: _department, decoration: const InputDecoration(labelText: 'Department (optional)')),
                if (widget.staff == null) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _score,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: 'Starting merit score (default ${formatMerit(widget.defaultScoreTenths)})',
                      suffixText: 'merit',
                    ),
                    validator: (value) =>
                        parseScoreTenths(value ?? '') == null ? 'Enter a valid score (e.g. 5.0).' : null,
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : widget.staff == null ? 'Save staff' : 'Save changes'),
          ),
        ],
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
  int _direction = -1; // Default to Tolak (-), user can toggle Tambah (+)
  int _step = 10; // 0.1 to 1.0 (10 to 100 tenths)
  static const _steps = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delta = _direction * _step;
    final after = widget.staff.scoreTenths + delta;
    final isPositive = _direction > 0;
    final accentColor = isPositive ? const Color(0xFF16804A) : const Color(0xFFB42318);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Surface3DCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.staff.name, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.staff.code}  •  Current Merit: ${formatMerit(widget.staff.scoreTenths)}',
                              style: const TextStyle(color: Color(0xFF667894), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: -1,
                        label: Text('Deduct (-)'),
                        icon: Icon(Icons.remove_circle_outline, size: 18),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Add (+)'),
                        icon: Icon(Icons.add_circle_outline, size: 18),
                      ),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (selection) => setState(() => _direction = selection.first),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select points (0.1 – 1.0)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF34435D)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _steps.map((amount) {
                      final selected = _step == amount;
                      final label = '${isPositive ? '+' : '-'}${formatMerit(amount)}';
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF141C2E),
                          ),
                        ),
                        selected: selected,
                        selectedColor: accentColor,
                        backgroundColor: const Color(0xFFF5F8FC),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _step = amount),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reason,
                    onChanged: (_) => setState(() {}),
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Reason (required)',
                      hintText: 'State the reason for this merit adjustment…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFFE8F7EE) : const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Updated Merit Score', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${formatMerit(widget.staff.scoreTenths)}  →  ${formatDelta(delta)}  →  ${formatMerit(after)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: accentColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: accentColor),
                        onPressed: _reason.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(context, _AdjustmentInput(delta, _reason.text.trim())),
                        child: Text('Confirm ${formatDelta(delta)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }
}

class _CorrectionInput {
  const _CorrectionInput(this.scoreTenths, this.reason);
  final int scoreTenths;
  final String reason;
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.staff});
  final StaffMember staff;
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _score = TextEditingController();
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    _score.text = formatMerit(widget.staff.scoreTenths);
  }

  @override
  void dispose() {
    _score.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Correct merit score'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.staff.code}  •  ${widget.staff.name}', style: const TextStyle(color: Color(0xFF667894))),
              const SizedBox(height: 14),
              TextField(
                controller: _score,
                onChanged: (_) => setState(() {}),
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Corrected score',
                  helperText: 'Current score: ${formatMerit(widget.staff.scoreTenths)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                onChanged: (_) => setState(() {}),
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Correction reason (required)', alignLabelWithHint: true),
              ),
              const Text(
                'A correction adds a new record; the original history is retained.',
                style: TextStyle(fontSize: 12, color: Color(0xFF667894)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: parseScoreTenths(_score.text) == null || _reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _CorrectionInput(parseScoreTenths(_score.text)!, _reason.text.trim())),
            child: const Text('Save correction'),
          ),
        ],
      );
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
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.inviteUser(
        email: _email.text,
        displayName: _name.text,
        role: _role,
        staffId: _role == 'staff' ? _staffId : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on MeritRepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Invitation failed. Check SMTP configuration and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = widget.profiles.map((item) => item['staff_id']).whereType<String>().toSet();
    final available = widget.staff.where((item) => !item.archived && !assigned.contains(item.id)).toList();
    final ceoExists = widget.profiles.any((item) => item['role'] == 'ceo');
    if (_role == 'staff' && _staffId != null && !available.any((item) => item.id == _staffId)) _staffId = null;
    return AlertDialog(
      title: const Text('Invite user'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The user will be authorized to receive Email OTP sign-in codes via Google SMTP (support@mesrc.com.my).',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'User name'), validator: _required),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  if (!ceoExists) const DropdownMenuItem(value: 'ceo', child: Text('CEO')),
                  const DropdownMenuItem(value: 'staff', child: Text('Staff — own records only')),
                ],
                onChanged: (value) => setState(() {
                  _role = value ?? 'staff';
                  _staffId = null;
                }),
              ),
              if (_role == 'staff') ...[
                const SizedBox(height: 10),
                if (available.isEmpty)
                  const Text(
                    'Add a staff record before sending a staff invitation.',
                    style: TextStyle(color: Color(0xFF667894), fontSize: 12),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _staffId,
                    decoration: const InputDecoration(labelText: 'Link staff record'),
                    items: available
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.code} — ${item.name}', overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _staffId = value),
                    validator: (value) => _role == 'staff' && value == null ? 'Select a staff record.' : null,
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy || (_role == 'staff' && available.isEmpty) ? null : _send,
          icon: _busy ? const ThinkingOrbsLoader(size: 18, label: 'Sending invitation') : const Icon(Icons.send_outlined),
          label: Text(_busy ? 'Sending…' : 'Send invitation'),
        ),
      ],
    );
  }
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;
