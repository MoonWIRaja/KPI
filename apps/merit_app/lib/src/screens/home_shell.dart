import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
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
import '../widgets/app_modal.dart';

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
  String _organizationName = 'MESRC DEVICE';
  String _scoreUnit = 'merit';
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
    final defaultScoreFallback = _hasPermission('staff.create') || _hasPermission('staff.import') || _hasPermission('settings.manage')
        ? await _repository.defaultScoreTenths()
        : 50;
    _defaultScore = defaultScoreFallback;
    final profiles = _isOwner ? await _repository.loadProfiles() : const <Map<String, dynamic>>[];
    try {
      final settings = await _repository.loadSettings();
      _defaultScore = settings.defaultScoreTenths;
      _organizationName = settings.organizationName;
      _scoreUnit = settings.scoreUnit;
    } catch (_) {}
    _staff = staff;
    _events = events;
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
    await showAppModal<void>(
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
          organizationName: _organizationName,
          scoreUnit: _scoreUnit,
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
        search: _search,
        onAdjust: _openAdjustment,
        onSearchChanged: () => setState(() {}),
        loading: _loading,
        scoreUnit: _scoreUnit,
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
        search: _search,
        onAddStaff: _openAddStaff,
        onImportCsv: _openCsvImport,
        onOpenStaff: _openUnifiedStaff,
        onSearchChanged: () => setState(() {}),
        loading: _loading,
        scoreUnit: _scoreUnit,
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
                      child: _EventsCard(
                        events: _events,
                        canSeeAllStaff: false,
                        scoreUnit: _scoreUnit,
                      ),
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
          child: _EventsCard(
            events: _events,
            canSeeAllStaff: _hasPermission('merit.read.all'),
            scoreUnit: _scoreUnit,
          ),
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
                  : ListView.builder(
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Surface3DCard(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 14,
                            child: _UserAccessRow(
                              profile: profile,
                              onPermissions: () => _editUserPermissions(profile),
                              onToggleActive: () => _toggleUserActive(profile),
                              onDelete: profile['role'] == 'owner' ? null : () => _deleteUser(profile),
                              onResendEmail: () => _resendLoginEmail(profile),
                            ),
                          ),
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
    final created = await showAppModal<bool>(
      context: context,
      builder: (_) => _AddStaffDialog(defaultScoreTenths: _defaultScore, repository: _repository),
    );
    if (created == true) await _refresh();
  }

  Future<void> _openUnifiedStaff(StaffMember staff) async {
    final updated = await showAppModal<bool>(
      context: context,
      builder: (_) => _StaffUnifiedDialog(
        staff: staff,
        repository: _repository,
        canEdit: _hasPermission('staff.update'),
        canCorrectMerit: _hasPermission('merit.correct'),
        canDelete: _hasPermission('staff.delete'),
        scoreUnit: _scoreUnit,
      ),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _openCsvImport() async {
    final imported = await showAppModal<bool>(context: context, builder: (_) => CsvImportDialog(repository: _repository));
    if (imported == true) await _refresh();
  }

  Future<void> _editUserPermissions(Map<String, dynamic> profile) async {
    final existing = (profile['user_permissions'] as List<dynamic>? ?? const [])
        .map((item) => (item as Map<String, dynamic>)['permission_key'] as String)
        .toSet();
    final updated = await showAppModal<Set<String>>(
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
    final confirmed = await showAppModal<bool>(
      context: context,
      builder: (_) => _ConfirmCardDialog(
        title: active ? 'Activate account?' : 'Deactivate account?',
        message: active
            ? 'This user will be able to sign in again.'
            : 'The user will lose access to data as soon as this change is saved.',
        confirmLabel: active ? 'Activate' : 'Deactivate',
        destructive: !active,
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

  Widget _settingsPage() => _SettingsPage(
        repository: _repository,
        onSaved: _refresh,
        staff: _staff,
        events: _events,
        profiles: _profiles,
      );

  Future<void> _openAdjustment(StaffMember staff) async {
    if (!_hasPermission('merit.adjust')) return;
    final change = await showAppModal<_AdjustmentInput>(
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


  Future<void> _deleteUser(Map<String, dynamic> profile) async {
    final userId = profile['user_id']?.toString() ?? '';
    final email = profile['email']?.toString() ?? 'this user';
    if (userId.isEmpty) return;

    final confirmed = await showAppModal<bool>(
      context: context,
      builder: (_) => _ConfirmCardDialog(
        title: 'Delete user account?',
        message: 'Are you sure you want to delete the account for $email? All access permissions will be removed. You can re-invite them afterwards if needed.',
        confirmLabel: 'Delete account',
        destructive: true,
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account for $email deleted.')),
      );
      await _refresh();
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _resendLoginEmail(Map<String, dynamic> profile) async {
    final email = profile['email']?.toString() ?? '';
    if (email.isEmpty) return;
    try {
      await _repository.resendLoginEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login email sent to $email.')),
      );
    } on MeritRepositoryException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openInvite() async {
    final invited = await showAppModal<bool>(
      context: context,
      builder: (_) => _InviteDialog(repository: _repository, staff: _staff, profiles: _profiles),
    );
    if (invited == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent. A login email with code was dispatched.')),
        );
      }
      await _refresh();
    }
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

  Future<void> _editDisplayName() async {
    final current = _profile['display_name'] as String? ?? '';
    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();

    final updated = await showAppModal<String>(
      context: context,
      builder: (modalCtx) => AppModalCard(
        maxWidth: 360,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit display name',
                style: Theme.of(modalCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Your display name',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name.' : null,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(modalCtx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(modalCtx, controller.text.trim());
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updated != null && updated.isNotEmpty && updated != current) {
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        await widget.repository.updateMyDisplayName(updated);
        setState(() => _profile['display_name'] = updated);
        await widget.onAvatarUpdated();
      } on MeritRepositoryException catch (e) {
        setState(() => _error = e.message);
      } catch (_) {
        setState(() => _error = 'Could not update display name.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppModalCard(
        maxWidth: 380,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _profile['display_name'] as String? ?? '',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Edit display name',
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF245CEB)),
                        onPressed: _saving ? null : _editDisplayName,
                      ),
                    ],
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
    required this.search,
    required this.onAdjust,
    required this.onSearchChanged,
    required this.loading,
    this.scoreUnit = 'merit',
  });
  final List<StaffMember> staff;
  final List<MeritEvent> events;
  final bool canAdjust;
  final TextEditingController search;
  final ValueChanged<StaffMember> onAdjust;
  final VoidCallback onSearchChanged;
  final bool loading;
  final String scoreUnit;

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
                                onAdjust: onAdjust,
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
    required this.search,
    required this.onAddStaff,
    required this.onImportCsv,
    required this.onOpenStaff,
    required this.onSearchChanged,
    required this.loading,
    this.scoreUnit = 'merit',
  });
  final List<StaffMember> staff;
  final bool canCreate;
  final bool canImport;
  final TextEditingController search;
  final VoidCallback onAddStaff;
  final VoidCallback onImportCsv;
  final ValueChanged<StaffMember> onOpenStaff;
  final VoidCallback onSearchChanged;
  final bool loading;
  final String scoreUnit;

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
              if (!narrow)
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
                                  interactive: true,
                                  onTap: () => onOpenStaff(item),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEEF3FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${formatMerit(item.scoreTenths)} $scoreUnit',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF245CEB),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.code}  •  ${item.department ?? 'No department'}',
                                              style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                                            ),
                                          ],
                                        ),
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
                                    DataColumn(label: Text('MERIT')),
                                  ],
                                  rows: staff.map((item) {
                                    return DataRow(
                                      onSelectChanged: (_) => onOpenStaff(item),
                                      cells: [
                                        DataCell(Text(item.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF245CEB))),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.touch_app_outlined, size: 15, color: Color(0xFF245CEB)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(item.department ?? '—')),
                                        DataCell(
                                          Text(
                                            formatMerit(item.scoreTenths),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF141C2E)),
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
          if (narrow && (canImport || canCreate)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  if (canImport)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onImportCsv,
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: const Text('Import CSV', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  if (canImport && canCreate) const SizedBox(width: 8),
                  if (canCreate)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddStaff,
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text('Add staff', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
    required this.onAdjust,
  });
  final StaffMember staff;
  final MeritEvent? latest;
  final bool canAdjust;
  final ValueChanged<StaffMember> onAdjust;

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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${staff.code}  •  ${staff.department ?? 'No department'}',
                      style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                    ),
                  ),
                  if (latest != null) _DeltaPill(delta: latest!.deltaTenths),

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
  const _EventsCard({
    required this.events,
    required this.canSeeAllStaff,
    this.scoreUnit = 'merit',
  });
  final List<MeritEvent> events;
  final bool canSeeAllStaff;
  final String scoreUnit;
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
                    : '${formatDelta(event.deltaTenths)}  •  ${formatMerit(event.afterTenths)} $scoreUnit',
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
    this.onDelete,
    this.onResendEmail,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onPermissions;
  final VoidCallback onToggleActive;
  final VoidCallback? onDelete;
  final VoidCallback? onResendEmail;

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
      return Column(
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
              if (onResendEmail != null)
                IconButton(
                  tooltip: 'Resend login email',
                  visualDensity: VisualDensity.compact,
                  onPressed: onResendEmail,
                  icon: const Icon(Icons.mail_outline, size: 20, color: Color(0xFF245CEB)),
                ),
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
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete user account',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFB42318)),
                ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
          if (onResendEmail != null)
            IconButton(
              tooltip: 'Resend login email',
              onPressed: onResendEmail,
              icon: const Icon(Icons.mail_outline, size: 20, color: Color(0xFF245CEB)),
            ),
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
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete user account',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFB42318)),
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
  Widget build(BuildContext context) => AppModalCard(
        maxWidth: 480,
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
                      Text(
                        'Permissions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.profile['display_name'] as String? ?? 'User',
                        style: const TextStyle(color: Color(0xFF667894), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Permissions are enforced by database security rules.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF667894)),
            ),
            const SizedBox(height: 8),
            ..._permissions.map(
              (item) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.$2, style: const TextStyle(fontSize: 13.5)),
                value: _selected.contains(item.$1),
                onChanged: (value) => setState(() {
                  value == true ? _selected.add(item.$1) : _selected.remove(item.$1);
                }),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Save permissions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _ConfirmCardDialog extends StatelessWidget {
  const _ConfirmCardDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) => AppModalCard(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 13.5, color: Color(0xFF667894), height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: destructive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)) : null,
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.repository,
    required this.onSaved,
    required this.staff,
    required this.events,
    required this.profiles,
  });
  final MeritRepository repository;
  final Future<void> Function() onSaved;
  final List<StaffMember> staff;
  final List<MeritEvent> events;
  final List<Map<String, dynamic>> profiles;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _default = TextEditingController();
  final _floor = TextEditingController();
  final _ceiling = TextEditingController();
  final _orgName = TextEditingController(text: 'MESRC DEVICE');
  final _unit = TextEditingController(text: 'merit');
  bool _loading = true;
  bool _saving = false;
  bool _exportingBackup = false;
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
    _orgName.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await widget.repository.loadSettings();
      _default.text = formatMerit(values.defaultScoreTenths);
      _floor.text = values.floorTenths == null ? '' : formatMerit(values.floorTenths!);
      _ceiling.text = values.ceilingTenths == null ? '' : formatMerit(values.ceilingTenths!);
      _orgName.text = values.organizationName;
      _unit.text = values.scoreUnit;
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
      setState(() => _error = 'Enter a valid merit score with at most one decimal place.');
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
        organizationName: _orgName.text.trim(),
        scoreUnit: _unit.text.trim(),
      );
      await widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All system settings saved successfully.')),
        );
      }
    } on MeritRepositoryException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadBackup() async {
    setState(() => _exportingBackup = true);
    try {
      final backup = {
        'system': 'Merit Tracker System',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'organization': _orgName.text.trim(),
        'score_unit': _unit.text.trim(),
        'default_starting_score': _default.text,
        'floor_limit': _floor.text.isEmpty ? null : _floor.text,
        'ceiling_limit': _ceiling.text.isEmpty ? null : _ceiling.text,
        'statistics': {
          'total_staff': widget.staff.length,
          'total_events': widget.events.length,
          'total_profiles': widget.profiles.length,
        },
        'staff_records': widget.staff
            .map((s) => {
                  'id': s.id,
                  'code': s.code,
                  'name': s.name,
                  'department': s.department,
                  'current_score': formatMerit(s.scoreTenths),
                })
            .toList(),
        'recent_events': widget.events
            .map((e) => {
                  'id': e.id,
                  'staff_id': e.staffId,
                  'type': e.type,
                  'delta': formatDelta(e.deltaTenths),
                  'score_before': e.beforeTenths == null ? null : formatMerit(e.beforeTenths!),
                  'score_after': formatMerit(e.afterTenths),
                  'reason': e.reason,
                  'actor': e.actorName,
                  'created_at': e.createdAt.toUtc().toIso8601String(),
                })
            .toList(),
      };

      final jsonBytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      await FileSaver.instance.saveFile(
        name: 'merit-tracker-backup-$dateStr',
        bytes: jsonBytes,
        fileExtension: 'json',
        mimeType: MimeType.custom,
        customMimeType: 'application/json',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full database JSON backup downloaded successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 14, isMobile ? 14 : 24, 18),
      child: Surface3DCard(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: _loading
            ? const Center(child: ThinkingOrbsLoader())
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Merit Scoring Configuration',
                      subtitle: 'Set initial default merit score and boundary limits for all staff.',
                    ),
                    const SizedBox(height: 14),
                    _SettingsGroup(
                      padding: isMobile ? 14 : 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldsLayout(isMobile, [
                            TextField(
                              controller: _default,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: InputDecoration(
                                labelText: 'Default starting score',
                                hintText: 'e.g. 5.0',
                                suffixText: _unit.text.trim(),
                              ),
                            ),
                            TextField(
                              controller: _floor,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(
                                labelText: 'Minimum floor (optional)',
                                hintText: 'e.g. 0.0',
                              ),
                            ),
                            TextField(
                              controller: _ceiling,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(
                                labelText: 'Maximum ceiling (optional)',
                                hintText: 'e.g. 10.0',
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      icon: Icons.business_rounded,
                      title: 'Organization & System Units',
                      subtitle: 'Customize organization display name and merit point unit label.',
                    ),
                    const SizedBox(height: 14),
                    _SettingsGroup(
                      padding: isMobile ? 14 : 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldsLayout(isMobile, [
                            TextField(
                              controller: _orgName,
                              decoration: const InputDecoration(
                                labelText: 'Organization / Company Name',
                                prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                              ),
                            ),
                            TextField(
                              controller: _unit,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Score Unit Label',
                                hintText: 'e.g. merit, pts',
                                prefixIcon: Icon(Icons.stars_rounded, size: 20),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      icon: Icons.verified_user_outlined,
                      title: 'Evaluation Policy & Reports Cycle',
                      subtitle: 'Operational policies governing monthly staff merit evaluations and audit logging.',
                    ),
                    const SizedBox(height: 14),
                    _SettingsGroup(
                      padding: isMobile ? 14 : 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPolicyTile(
                            icon: Icons.calendar_month_outlined,
                            title: 'Monthly Evaluation Cycle',
                            description: 'Evaluations automatically span from the 1st of every month to the end of the month.',
                            badge: 'Active Cycle',
                            badgeColor: const Color(0xFF16804A),
                          ),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildPolicyTile(
                            icon: Icons.picture_as_pdf_outlined,
                            title: 'Multi-Format Export Engine',
                            description: 'PDF report generation for appraisals & CSV export for external spreadsheet auditing.',
                            badge: 'PDF / CSV',
                            badgeColor: const Color(0xFF245CEB),
                          ),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildPolicyTile(
                            icon: Icons.security_rounded,
                            title: 'Tamper-Evident Audit Trail',
                            description: 'Every score addition, deduction, correction, and user permission modification is permanently logged with actor metadata.',
                            badge: 'Strict Logging',
                            badgeColor: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      icon: Icons.dns_outlined,
                      title: 'System Health & Data Backup',
                      subtitle: 'Live system diagnostic metrics and instant full database JSON backup export.',
                    ),
                    const SizedBox(height: 14),
                    _SettingsGroup(
                      padding: isMobile ? 14 : 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              _buildMetricCard('Active Staff', '${widget.staff.length}', Icons.groups_outlined, const Color(0xFF245CEB)),
                              _buildMetricCard('Merit Records', '${widget.events.length}', Icons.history_rounded, const Color(0xFF16804A)),
                              _buildMetricCard('User Accounts', '${widget.profiles.length}', Icons.manage_accounts_outlined, const Color(0xFF7C3AED)),
                              _buildMetricCard('Database', 'Connected', Icons.cloud_done_rounded, const Color(0xFF0284C7)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _exportingBackup ? null : _downloadBackup,
                                icon: _exportingBackup
                                    ? const ThinkingOrbsLoader(size: 16, label: 'Exporting')
                                    : const Icon(Icons.download_rounded, size: 16),
                                label: Text(_exportingBackup ? 'Exporting…' : 'Download JSON backup'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  await widget.onSaved();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('System state refreshed successfully.')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Refresh state'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const ThinkingOrbsLoader(size: 16, label: 'Saving')
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save settings'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldsLayout(bool isMobile, List<Widget> fields) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            fields[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF245CEB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF141C2E))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF667894))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyTile({required IconData icon, required String title, required String description, required String badge, required Color badgeColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.child, this.padding = 18});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );
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
  Widget build(BuildContext context) => AppModalCard(
        maxWidth: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add staff',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Staff code'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name'), validator: _required),
                  const SizedBox(height: 10),
                  TextFormField(controller: _department, decoration: const InputDecoration(labelText: 'Department (optional)')),
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save staff'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
  int _step = 1; // 0.1 merit (1 tenth)
  static const _steps = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

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

    return AppModalCard(
      maxWidth: 500,
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
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accentColor),
                  onPressed: _reason.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, _AdjustmentInput(delta, _reason.text.trim())),
                  child: Text('Confirm ${formatDelta(delta)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffUnifiedDialog extends StatefulWidget {
  const _StaffUnifiedDialog({
    required this.staff,
    required this.repository,
    required this.canEdit,
    required this.canCorrectMerit,
    required this.canDelete,
    this.scoreUnit = 'merit',
  });
  final StaffMember staff;
  final MeritRepository repository;
  final bool canEdit;
  final bool canCorrectMerit;
  final bool canDelete;
  final String scoreUnit;

  @override
  State<_StaffUnifiedDialog> createState() => _StaffUnifiedDialogState();
}

class _StaffUnifiedDialogState extends State<_StaffUnifiedDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _department = TextEditingController();
  final _score = TextEditingController();
  final _reason = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _code.text = widget.staff.code;
    _name.text = widget.staff.name;
    _department.text = widget.staff.department ?? '';
    _score.text = formatMerit(widget.staff.scoreTenths);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _code.dispose();
    _name.dispose();
    _department.dispose();
    _score.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showAppModal<bool>(
      context: context,
      builder: (_) => _ConfirmCardDialog(
        title: 'Delete ${widget.staff.name}?',
        message: 'This will permanently remove ${widget.staff.name} and all associated merit history from the system. This action cannot be undone.',
        confirmLabel: 'Delete permanently',
        destructive: true,
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.deleteStaff(widget.staff.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.staff.name} was deleted.')),
        );
      }
    } on MeritRepositoryException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Staff record could not be deleted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      bool changed = false;

      // 1. Staff info changes
      final infoChanged = _code.text.trim() != widget.staff.code ||
          _name.text.trim() != widget.staff.name ||
          _department.text.trim() != (widget.staff.department ?? '');

      if (infoChanged) {
        if (!widget.canEdit) {
          throw const MeritRepositoryException('You do not have permission to edit staff details.');
        }
        if (_code.text.trim().isEmpty) {
          throw const MeritRepositoryException('Staff code cannot be empty.');
        }
        if (_name.text.trim().isEmpty) {
          throw const MeritRepositoryException('Full name cannot be empty.');
        }
        await widget.repository.updateStaff(
          widget.staff,
          code: _code.text.trim(),
          name: _name.text.trim(),
          department: _department.text.trim().isEmpty ? null : _department.text.trim(),
        );
        changed = true;
      }

      // 2. Merit score correction
      final newScoreTenths = parseScoreTenths(_score.text.trim());
      final scoreChanged = newScoreTenths != null && newScoreTenths != widget.staff.scoreTenths;

      if (scoreChanged) {
        if (!widget.canCorrectMerit) {
          throw const MeritRepositoryException('You do not have permission to correct merit score.');
        }
        if (_reason.text.trim().isEmpty) {
          throw const MeritRepositoryException('A reason is required when correcting merit score.');
        }
        await widget.repository.correctMerit(
          staffId: widget.staff.id,
          scoreTenths: newScoreTenths,
          reason: _reason.text.trim(),
        );
        changed = true;
      }

      if (mounted) {
        Navigator.pop(context, changed);
        if (changed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff details saved successfully.')),
          );
        }
      }
    } on MeritRepositoryException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save changes. Please check input values.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppModalCard(
        maxWidth: 480,
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
                      Text(
                        widget.staff.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.staff.code}  •  ${widget.staff.department ?? 'No department'}',
                        style: const TextStyle(color: Color(0xFF667894), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${formatMerit(widget.staff.scoreTenths)} ${widget.scoreUnit}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF245CEB)),
                  ),
                ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete staff',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318), size: 20),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                labelColor: const Color(0xFF245CEB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Staff Details'),
                  Tab(icon: Icon(Icons.stars_outlined, size: 18), text: 'Merit Points'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 310,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _code,
                          enabled: widget.canEdit && !_busy,
                          decoration: const InputDecoration(labelText: 'Staff code', isDense: true),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          enabled: widget.canEdit && !_busy,
                          decoration: const InputDecoration(labelText: 'Full name', isDense: true),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _department,
                          enabled: widget.canEdit && !_busy,
                          decoration: const InputDecoration(labelText: 'Department (optional)', isDense: true),
                        ),
                        if (!widget.canEdit)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'You have read-only view of staff records.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF667894)),
                            ),
                          ),
                        if (widget.canDelete) ...[
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB42318),
                              side: const BorderSide(color: Color(0xFFFECDCA)),
                              backgroundColor: const Color(0xFFFFF5F5),
                            ),
                            onPressed: _busy ? null : _confirmDelete,
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Delete this staff record'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFF245CEB), size: 28),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CURRENT MERIT SCORE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                  Text(
                                    formatMerit(widget.staff.scoreTenths),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.remove, size: 14, color: Color(0xFFB42318)),
                              label: const Text('-0.5', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB42318))),
                              backgroundColor: const Color(0xFFFFEEEE),
                              onPressed: !widget.canCorrectMerit || _busy ? null : () {
                                final current = widget.staff.scoreTenths;
                                _score.text = formatMerit(current - 5);
                                if (_reason.text.isEmpty) _reason.text = 'Deduction of 0.5 merit';
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.remove, size: 14, color: Color(0xFFB42318)),
                              label: const Text('-0.1', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB42318))),
                              backgroundColor: const Color(0xFFFFEEEE),
                              onPressed: !widget.canCorrectMerit || _busy ? null : () {
                                final current = widget.staff.scoreTenths;
                                _score.text = formatMerit(current - 1);
                                if (_reason.text.isEmpty) _reason.text = 'Deduction of 0.1 merit';
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 14, color: Color(0xFF16804A)),
                              label: const Text('+0.1', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16804A))),
                              backgroundColor: const Color(0xFFE8F7EE),
                              onPressed: !widget.canCorrectMerit || _busy ? null : () {
                                final current = widget.staff.scoreTenths;
                                _score.text = formatMerit(current + 1);
                                if (_reason.text.isEmpty) _reason.text = 'Addition of 0.1 merit';
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 14, color: Color(0xFF16804A)),
                              label: const Text('+0.5', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16804A))),
                              backgroundColor: const Color(0xFFE8F7EE),
                              onPressed: !widget.canCorrectMerit || _busy ? null : () {
                                final current = widget.staff.scoreTenths;
                                _score.text = formatMerit(current + 5);
                                if (_reason.text.isEmpty) _reason.text = 'Addition of 0.5 merit';
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _score,
                          enabled: widget.canCorrectMerit && !_busy,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Corrected score',
                            isDense: true,
                            suffixText: 'merit',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _reason,
                          enabled: widget.canCorrectMerit && !_busy,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Correction reason (required if changing score)',
                            isDense: true,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Text(
                          'A correction records an adjustment in history with your account details.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return AppModalCard(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invite user',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the email address. A login OTP email will be sent automatically, and users can set up their own profile name after signing in.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF667894)),
          ),
          const SizedBox(height: 14),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'User Email Address',
                    hintText: 'e.g. user@mesrc.com.my',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (value) => value == null || !value.trim().contains('@') ? 'Enter a valid email address.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || (_role == 'staff' && available.isEmpty) ? null : _send,
                  icon: _busy ? const ThinkingOrbsLoader(size: 18, label: 'Sending invitation') : const Icon(Icons.send_outlined),
                  label: Text(_busy ? 'Sending…' : 'Send invitation'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;
