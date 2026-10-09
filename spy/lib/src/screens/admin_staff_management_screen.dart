import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../theme.dart';

class StaffAccountsView extends StatefulWidget {
  const StaffAccountsView({super.key});

  @override
  State<StaffAccountsView> createState() => _StaffAccountsViewState();
}

class _StaffAccountsViewState extends State<StaffAccountsView> {
  bool _isLoading = true;
  List<StaffMember> _staffList = [];
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (authProvider.useMockApi) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _staffList = [
            StaffMember(
              staffId: 1,
              userId: 1,
              username: 'doctor1',
              role: 'doctor',
              name: 'Dr. Sharma',
              department: 'General Medicine',
              specialization: 'Diabetes',
              phone: '9876543210',
              email: 'dr.sharma@saathi.org',
              active: true,
            ),
            StaffMember(
              staffId: 2,
              userId: 2,
              username: 'receptionist1',
              role: 'receptionist',
              name: 'Sita Ram',
              department: 'Front Desk',
              phone: '9876543211',
              email: 'sita.ram@saathi.org',
              active: true,
            ),
          ];
          _isLoading = false;
        });
      } else {
        final token = authProvider.token;
        if (token == null) {
          throw ApiException('Session expired.');
        }

        final list = await authProvider.apiClient.getStaffList(token);
        setState(() {
          _staffList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStaffStatus(StaffMember member, bool active) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'Activate Account' : 'Deactivate Account'),
        content: Text(
          'Are you sure you want to ${active ? "activate" : "deactivate"} ${member.name}\'s account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              active ? 'Activate' : 'Deactivate',
              style: TextStyle(
                color: active ? saathiGreen : saathiEmergency,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (!authProvider.useMockApi) {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');
        await authProvider.apiClient.updateStaffStatus(
          member.staffId,
          active: active,
          token: token,
        );
      }

      setState(() {
        final idx = _staffList.indexWhere((s) => s.staffId == member.staffId);
        if (idx != -1) {
          final old = _staffList[idx];
          _staffList[idx] = StaffMember(
            staffId: old.staffId,
            userId: old.userId,
            username: old.username,
            role: old.role,
            name: old.name,
            department: old.department,
            specialization: old.specialization,
            phone: old.phone,
            email: old.email,
            active: active,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff status updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: saathiEmergency,
          ),
        );
      }
    }
  }

  Future<void> _deleteStaff(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff Account'),
        content: Text('Delete ${member.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: saathiEmergency),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.useMockApi) {
        final token = auth.token;
        if (token == null) throw ApiException('Session expired.');
        await auth.apiClient.deleteStaff(member.staffId, token: token);
      }

      if (!mounted) return;
      setState(() {
        _staffList.removeWhere((staff) => staff.staffId == member.staffId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.name} was deleted.'),
          backgroundColor: saathiGreen,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Account'),
            content: Text('${e.message}\n\nWould you like to deactivate this account instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleStaffStatus(member, false);
                },
                child: const Text('Deactivate Account'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAddStaffDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddStaffDialog(
        onStaffAdded: () {
          _loadStaff();
        },
      ),
    );
  }

  void _showEditStaffDialog(StaffMember member) {
    showDialog(
      context: context,
      builder: (context) => _EditStaffDialog(
        member: member,
        onStaffUpdated: () {
          _loadStaff();
        },
      ),
    );
  }

  void _showChangeAdminPasswordDialog(StaffMember member) {
    showDialog(
      context: context,
      builder: (context) => _ChangeAdminPasswordDialog(member: member),
    );
  }

  List<StaffMember> get _filteredStaff {
    return _staffList.where((member) {
      final matchesRole = _selectedRoleFilter == 'all' || member.role.toLowerCase() == _selectedRoleFilter;
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return matchesRole;

      final matchesQuery = member.name.toLowerCase().contains(q) ||
          member.username.toLowerCase().contains(q) ||
          (member.department?.toLowerCase().contains(q) ?? false) ||
          (member.specialization?.toLowerCase().contains(q) ?? false) ||
          (member.phone?.toLowerCase().contains(q) ?? false) ||
          (member.email?.toLowerCase().contains(q) ?? false);

      return matchesRole && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hospital Staff Accounts',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: saathiNavy,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage doctors, receptionists, and user access permissions.',
                      style: TextStyle(color: saathiBodyGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                child: FilledButton.icon(
                  onPressed: _showAddStaffDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Staff Member'),
                  style: FilledButton.styleFrom(backgroundColor: saathiGreen),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SEARCH AND FILTER BAR
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, username, department, or phone...',
                    prefixIcon: const Icon(Icons.search, color: saathiNavy),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'doctor', label: Text('Doctors')),
                  ButtonSegment(value: 'receptionist', label: Text('Receptionists')),
                ],
                selected: {_selectedRoleFilter},
                onSelectionChanged: (set) => setState(() => _selectedRoleFilter = set.first),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ERROR MESSAGE
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: saathiEmergencyTint,
                border: Border.all(color: saathiEmergency),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: saathiEmergencyDeep),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: saathiEmergencyDeep, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: saathiEmergencyDeep),
                    onPressed: _loadStaff,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // STAFF TABLE
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStaff.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _selectedRoleFilter != 'all'
                              ? 'No staff members match the selected filters.'
                              : 'No staff accounts found.',
                          style: const TextStyle(color: saathiBodyGrey, fontSize: 16),
                        ),
                      )
                    : Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: saathiLine),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(saathiCream),
                              columns: const [
                                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Department / Spec', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy))),
                              ],
                              rows: _filteredStaff.map((member) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        member.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: member.role == 'doctor' ? saathiMint : saathiCream,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          member.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: member.role == 'doctor' ? saathiGreen : saathiNavy,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(member.username)),
                                    DataCell(
                                      Text(
                                        member.department != null
                                            ? '${member.department}${member.specialization != null ? " / ${member.specialization}" : ""}'
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        member.phone != null && member.phone!.isNotEmpty
                                            ? member.phone!
                                            : member.email != null && member.email!.isNotEmpty
                                                ? member.email!
                                                : '-',
                                      ),
                                    ),
                                    DataCell(
                                      member.role.toLowerCase() == 'admin'
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: saathiMint,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: saathiGreen.withValues(alpha: 0.3)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, size: 14, color: saathiGreen),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Active',
                                                    style: TextStyle(
                                                      color: saathiGreen,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Switch(
                                              value: member.active,
                                              activeColor: saathiGreen,
                                              onChanged: (val) => _toggleStaffStatus(member, val),
                                            ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (member.role.toLowerCase() == 'admin')
                                            IconButton(
                                              tooltip: 'Change Admin Password',
                                              icon: const Icon(Icons.key_outlined, color: saathiNavy),
                                              onPressed: () => _showChangeAdminPasswordDialog(member),
                                            )
                                          else ...[
                                            IconButton(
                                              tooltip: 'Edit staff details',
                                              icon: const Icon(Icons.edit_outlined, color: saathiNavy),
                                              onPressed: () => _showEditStaffDialog(member),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete staff account',
                                              icon: const Icon(Icons.delete_outline, color: saathiEmergency),
                                              onPressed: () => _deleteStaff(member),
                                            ),
                                          ],
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

// ======================================================
// ADD STAFF DIALOG (WITH FULL FORM VALIDATION)
// ======================================================

class _AddStaffDialog extends StatefulWidget {
  final VoidCallback onStaffAdded;
  const _AddStaffDialog({required this.onStaffAdded});

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deptController = TextEditingController();
  final _specController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  final Set<String> _touchedFields = {};
  bool _hasSubmitted = false;
  String _role = 'doctor';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => _onFocusChange('name', _nameFocusNode));
    _usernameFocusNode.addListener(() => _onFocusChange('username', _usernameFocusNode));
    _passwordFocusNode.addListener(() => _onFocusChange('password', _passwordFocusNode));
    _phoneFocusNode.addListener(() => _onFocusChange('phone', _phoneFocusNode));
    _emailFocusNode.addListener(() => _onFocusChange('email', _emailFocusNode));
  }

  void _onFocusChange(String field, FocusNode focusNode) {
    if (!focusNode.hasFocus) {
      _touchedFields.add(field);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _deptController.dispose();
    _specController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    _nameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 100) return false;

    final username = _usernameController.text.trim();
    if (username.length < 3 || username.length > 50 || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return false;

    final password = _passwordController.text;
    if (password.length < 8) return false;

    if (_role.trim().isEmpty) return false;

    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) return false;

    final email = _emailController.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) return false;

    return true;
  }

  bool _shouldShowError(String field, FocusNode focusNode) {
    if (focusNode.hasFocus) return false;
    return _hasSubmitted || _touchedFields.contains(field);
  }

  Future<void> _submit() async {
    setState(() => _hasSubmitted = true);
    if (!_formKey.currentState!.validate() || !_isFormValid) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (!authProvider.useMockApi) {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');

        await authProvider.apiClient.createStaff(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          role: _role,
          name: _nameController.text.trim(),
          department: _deptController.text.trim(),
          specialization: _specController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          token: token,
        );
      }

      widget.onStaffAdded();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member registered successfully.')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException ? e.message : 'Failed to save staff member.';
        _isSaving = false;
      });
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: saathiLine)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: saathiNavy, width: 2)),
      errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Staff Member',
        style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: saathiEmergencyTint,
                      border: Border.all(color: saathiEmergency),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: saathiEmergencyDeep, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => setState(() => _touchedFields.add('name')),
                  decoration: _buildInputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (val) {
                    if (!_shouldShowError('name', _nameFocusNode)) return null;
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Full name is required';
                    if (trimmed.length > 100) return 'Full name must be at most 100 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => setState(() => _touchedFields.add('username')),
                  decoration: _buildInputDecoration(
                    labelText: 'Username *',
                    prefixIcon: Icons.account_box_outlined,
                  ),
                  validator: (val) {
                    if (!_shouldShowError('username', _usernameFocusNode)) return null;
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Username is required';
                    if (trimmed.length < 3) return 'Username must be at least 3 characters';
                    if (trimmed.length > 50) return 'Username must be at most 50 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
                      return 'Username can only contain letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => setState(() => _touchedFields.add('password')),
                  decoration: _buildInputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icons.lock_outline,
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (!_shouldShowError('password', _passwordFocusNode)) return null;
                    final str = val ?? '';
                    if (str.isEmpty) return 'Password is required';
                    if (str.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _buildInputDecoration(
                    labelText: 'Role *',
                    prefixIcon: Icons.security_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Role is required';
                    return null;
                  },
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _deptController,
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icons.business_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _specController,
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icons.star_outline,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => setState(() => _touchedFields.add('phone')),
                  decoration: _buildInputDecoration(
                    labelText: 'Phone Number (10 digits) *',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (val) {
                    if (!_shouldShowError('phone', _phoneFocusNode)) return null;
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Phone number is required';
                    if (!RegExp(r'^\d{10}$').hasMatch(trimmed)) {
                      return 'Enter exactly 10 digits for Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => setState(() => _touchedFields.add('email')),
                  decoration: _buildInputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (val) {
                    if (!_shouldShowError('email', _emailFocusNode)) return null;
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Email address is required';
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
        ),
        FilledButton(
          onPressed: _isFormValid && !_isSaving ? _submit : null,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Staff Member'),
        ),
      ],
    );
  }
}

// ======================================================
// EDIT STAFF DIALOG
// ======================================================

class _EditStaffDialog extends StatefulWidget {
  final StaffMember member;
  final VoidCallback onStaffUpdated;

  const _EditStaffDialog({required this.member, required this.onStaffUpdated});

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _deptController;
  late TextEditingController _specController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late String _role;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _deptController = TextEditingController(text: widget.member.department ?? '');
    _specController = TextEditingController(text: widget.member.specialization ?? '');
    _phoneController = TextEditingController(text: widget.member.phone ?? '');
    _emailController = TextEditingController(text: widget.member.email ?? '');
    _role = widget.member.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deptController.dispose();
    _specController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (!authProvider.useMockApi) {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');

        await authProvider.apiClient.updateStaff(
          widget.member.staffId,
          name: _nameController.text.trim(),
          department: _deptController.text.trim(),
          specialization: _specController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          role: _role,
          token: token,
        );
      }

      widget.onStaffUpdated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff details updated successfully.')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException ? e.message : 'Failed to update staff member.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Staff Member (${widget.member.username})'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: saathiEmergencyTint,
                      border: Border.all(color: saathiEmergency),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: saathiEmergencyDeep, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Full name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    prefixIcon: Icon(Icons.security_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _specController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icon(Icons.star_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (10 digits)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final cleaned = val.trim();
                    if (!RegExp(r'^\d{10}$').hasMatch(cleaned)) {
                      return 'Enter exactly 10 digits for Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final cleaned = val.trim();
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(cleaned)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Changes'),
        ),
      ],
    );
  }
}

class _ChangeAdminPasswordDialog extends StatefulWidget {
  final StaffMember member;

  const _ChangeAdminPasswordDialog({required this.member});

  @override
  State<_ChangeAdminPasswordDialog> createState() => _ChangeAdminPasswordDialogState();
}

class _ChangeAdminPasswordDialogState extends State<_ChangeAdminPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (!authProvider.useMockApi) {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');

        await authProvider.apiClient.updateStaffPassword(
          widget.member.staffId,
          newPassword: _passwordController.text.trim(),
          token: token,
        );
      } else {
        await authProvider.mockApiClient.updateStaffPassword(
          widget.member.staffId,
          newPassword: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin password updated successfully.'),
            backgroundColor: saathiGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException ? e.message : 'Failed to update password.';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: saathiMint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_reset, color: saathiGreen, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Change Admin Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: saathiNavy),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update password for administrator account (${widget.member.username}).',
                style: const TextStyle(fontSize: 13, color: saathiBodyGrey),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: saathiEmergencyTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: saathiEmergency),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: saathiEmergencyDeep, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter a new password';
                  if (val.trim().length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please confirm your new password';
                  if (val.trim() != _passwordController.text.trim()) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: saathiGreen),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }
}