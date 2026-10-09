import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';
import '../notification_provider.dart';
import '../theme.dart';
import 'registration_success_screen.dart';
import 'search_patients_screen.dart';
import '../api_client.dart';
import 'role_select_screen.dart';
import 'manage_devices_screen.dart';
import 'admin_staff_management_screen.dart';
import '../widgets/watermark_background.dart';

class ReceptionistHomeScreen extends StatefulWidget {
  const ReceptionistHomeScreen({super.key});

  @override
  State<ReceptionistHomeScreen> createState() => _ReceptionistHomeScreenState();
}

class _ReceptionistHomeScreenState extends State<ReceptionistHomeScreen> {
  int _currentIndex = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotifications();
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _refreshNotifications(),
      );
    });
  }

  Future<void> _refreshNotifications() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null || auth.useMockApi) return;
    await Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).fetchNotifications(apiClient: auth.apiClient, token: token);
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.role?.toLowerCase() == 'admin';

    final List<Widget> pages = [
      const RegisterPatientView(),
      const SearchPatientsScreen(),
      const ManageDevicesScreen(),
      if (isAdmin) const StaffAccountsView(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_add_outlined),
        activeIcon: Icon(Icons.person_add),
        label: 'Register',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people),
        label: 'Patients',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.devices_outlined),
        activeIcon: Icon(Icons.devices),
        label: 'Devices',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Staff',
        ),
    ];

    // Safety check in case we switch roles or index is out of bounds
    final pageIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      backgroundColor: saathiCream,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/saathi_logo.png',
              height: 36,
              width: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text('Saathi Portal'),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => _showNotifications(context, authProvider),
                  ),
                  if (notificationProvider.unreadCount > 0)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        decoration: const BoxDecoration(
                          color: saathiEmergency,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          notificationProvider.unreadCount > 9
                              ? '9+'
                              : '${notificationProvider.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _showSignOutDialog(context, authProvider),
          ),
        ],
      ),
      body: WatermarkBackground(child: pages[pageIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: pageIndex,
        selectedItemColor: saathiGreen,
        unselectedItemColor: saathiBodyGrey,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: navItems,
      ),
    );
  }

  void _showNotifications(BuildContext context, AuthProvider authProvider) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer<NotificationProvider>(
        builder: (context, notifications, _) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Notifications')),
              if (notifications.hasUnread)
                TextButton(
                  onPressed: () => notifications.markAllAsRead(
                    apiClient: authProvider.apiClient,
                    token: authProvider.token,
                  ),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: notifications.notifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('You are all caught up.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = notifications.notifications[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.type == 'admission'
                              ? Icons.local_hospital_outlined
                              : Icons.notifications_active_outlined,
                          color: item.isRead ? saathiBodyGrey : saathiGreen,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text('${item.body}\n${item.timestamp}'),
                        isThreeLine: true,
                        onTap: () => notifications.markAsRead(
                          item.id,
                          apiClient: authProvider.apiClient,
                          token: authProvider.token,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of the Saathi Staff Portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: saathiBodyGrey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: saathiEmergency),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Register Patient Tab ────────────────────────────────────────────────

class RegisterPatientView extends StatefulWidget {
  const RegisterPatientView({
    super.key,
    this.onRegistered,
    this.onExitToDashboard,
  });

  final VoidCallback? onRegistered;
  final VoidCallback? onExitToDashboard;

  @override
  State<RegisterPatientView> createState() => _RegisterPatientViewState();
}

class _RegisterPatientViewState extends State<RegisterPatientView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _conditionController = TextEditingController();

  DateTime? _selectedDateOfBirth;
  String _selectedLanguage = 'English';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _supportedLanguages = [
    'English',
    'Hindi',
    'Kannada',
    'Marathi',
    'Tamil',
    'Telugu',
    'Gujarati',
    'Bengali',
  ];

  // Interaction tracking state
  bool _hasAttemptedSubmit = false;
  bool _nameTouched = false;
  bool _dobTouched = false;
  bool _phoneTouched = false;
  bool _conditionTouched = false;
  bool _doctorTouched = false;

  List<DoctorInfo> _doctors = [];
  int? _selectedDoctorId;
  bool _loadingDoctors = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDoctors());
  }

  Future<void> _loadDoctors() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null || authProvider.useMockApi) return;
    setState(() => _loadingDoctors = true);
    try {
      final list = await authProvider.apiClient.getDoctors(token: token);
      if (mounted) {
        setState(() {
          _doctors = list;
          if (_doctors.isNotEmpty && _selectedDoctorId == null) {
            _selectedDoctorId = _doctors.first.staffId;
          }
        });
      }
    } catch (_) {
      // Non-blocking
    } finally {
      if (mounted) {
        setState(() => _loadingDoctors = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = _formatDate(picked) ?? '';
        _dobTouched = true;
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (_selectedDateOfBirth == null && _dobController.text.trim().isNotEmpty) {
      try {
        _selectedDateOfBirth = DateTime.parse(_dobController.text.trim());
      } catch (_) {}
    }

    if (!_formKey.currentState!.validate()) return;

    if (_doctors.isNotEmpty && _selectedDoctorId == null) {
      setState(() {
        _errorMessage = 'Please select a doctor to assign.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      late final RegisterPatientResponse response;
      final trimmedName = _nameController.text.trim();
      final formattedDob = _formatDate(_selectedDateOfBirth);
      final trimmedCondition = _conditionController.text.trim();
      final trimmedEmergency = _phoneController.text.trim();
      String? assignedDoctorName;
      for (final doctor in _doctors) {
        if (doctor.staffId == _selectedDoctorId) {
          assignedDoctorName = 'Dr. ${doctor.name}';
          break;
        }
      }
      if (authProvider.useMockApi) {
        response = await authProvider.mockApiClient.registerPatient(
          name: trimmedName,
          dateOfBirth: formattedDob,
          diseaseCondition: trimmedCondition,
          preferredLanguage: _selectedLanguage,
          emergencyContact: trimmedEmergency,
          assignedDoctorId: _selectedDoctorId,
        );
      } else {
        final token = authProvider.token;
        if (token == null) {
          throw ApiException('Session expired. Please sign in again.');
        }
        response = await authProvider.apiClient.registerPatient(
          name: trimmedName,
          dateOfBirth: formattedDob,
          diseaseCondition: trimmedCondition,
          preferredLanguage: _selectedLanguage,
          emergencyContact: trimmedEmergency,
          assignedDoctorId: _selectedDoctorId,
          token: token,
        );

        if (response.patientId != null && _selectedDoctorId != null) {
          try {
            await authProvider.apiClient.assignDoctor(
              response.patientId!,
              _selectedDoctorId!,
              token: token,
            );
          } catch (_) {}
        }
      }

      if (mounted) {
        _nameController.clear();
        _dobController.clear();
        _phoneController.clear();
        _conditionController.clear();
        setState(() {
          _selectedDateOfBirth = null;
          _selectedLanguage = 'English';
          _selectedDoctorId = _doctors.isNotEmpty
              ? _doctors.first.staffId
              : null;
          _hasAttemptedSubmit = false;
          _nameTouched = false;
          _dobTouched = false;
          _phoneTouched = false;
          _conditionTouched = false;
          _doctorTouched = false;
        });
        widget.onRegistered?.call();

        // Notify doctors about the new patient registration
        try {
          Provider.of<NotificationProvider?>(
            context,
            listen: false,
          )?.notifyPatientRegistered(
            patientName: trimmedName,
            registrationNo: response.registrationNo ?? 'N/A',
            condition: trimmedCondition.isNotEmpty ? trimmedCondition : null,
          );
        } catch (_) {}

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationSuccessScreen(
              response: response,
              assignedDoctorName: assignedDoctorName,
              onExitToDashboard: widget.onExitToDashboard,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to register patient. Please check your connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Register New Patient',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: saathiNavy, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in the fields below to register a patient.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: saathiEmergencyTint,
                  border: Border.all(color: saathiEmergency),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: saathiEmergencyDeep,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            _buildLabel('Full Name *'),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              autovalidateMode: (_hasAttemptedSubmit || _nameTouched)
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                hintText: 'Enter patient full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (val) {
                if (!_nameTouched) {
                  setState(() => _nameTouched = true);
                }
              },
              validator: (value) {
                if (!_hasAttemptedSubmit && !_nameTouched) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Patient name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Date of Birth *'),
            TextFormField(
              controller: _dobController,
              autovalidateMode: (_hasAttemptedSubmit || _dobTouched)
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: InputDecoration(
                hintText: 'YYYY-MM-DD or select date',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _pickDateOfBirth,
                ),
                suffixIcon:
                    _selectedDateOfBirth != null ||
                        _dobController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _selectedDateOfBirth = null;
                            _dobController.clear();
                            _dobTouched = true;
                          });
                        },
                      )
                    : null,
              ),
              onTap: () {
                if (_dobController.text.isEmpty) {
                  _pickDateOfBirth();
                }
              },
              onChanged: (val) {
                if (!_dobTouched) {
                  setState(() => _dobTouched = true);
                }
                final trimmed = val.trim();
                if (trimmed.isNotEmpty) {
                  try {
                    _selectedDateOfBirth = DateTime.parse(trimmed);
                  } catch (_) {
                    _selectedDateOfBirth = null;
                  }
                } else {
                  _selectedDateOfBirth = null;
                }
              },
              validator: (value) {
                if (!_hasAttemptedSubmit && !_dobTouched) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Date of birth is required';
                }
                final trimmed = value.trim();
                DateTime? parsed;
                try {
                  parsed = DateTime.parse(trimmed);
                } catch (_) {
                  return 'Please enter a valid date (YYYY-MM-DD)';
                }
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dob = DateTime(parsed.year, parsed.month, parsed.day);
                if (dob.isAfter(today)) {
                  return 'Date of birth cannot be in the future';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Emergency Contact Number *'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autovalidateMode: (_hasAttemptedSubmit || _phoneTouched)
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                hintText: 'Enter emergency contact number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              onChanged: (val) {
                if (!_phoneTouched) {
                  setState(() => _phoneTouched = true);
                }
              },
              validator: (value) {
                if (!_hasAttemptedSubmit && !_phoneTouched) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Emergency contact number is required';
                }
                final trimmed = value.trim();
                final digits = trimmed.replaceAll(RegExp(r'\D'), '');
                if (digits.length != 10 &&
                    !(digits.length == 12 && digits.startsWith('91'))) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Disease / Condition *'),
            TextFormField(
              controller: _conditionController,
              textInputAction: TextInputAction.done,
              autovalidateMode: (_hasAttemptedSubmit || _conditionTouched)
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                hintText: 'Primary diagnosis or symptom',
                prefixIcon: Icon(Icons.healing_outlined),
              ),
              onChanged: (val) {
                if (!_conditionTouched) {
                  setState(() => _conditionTouched = true);
                }
              },
              validator: (value) {
                if (!_hasAttemptedSubmit && !_conditionTouched) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Disease / condition is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Preferred Language *'),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.language_outlined),
                hintText: 'Select preferred language',
              ),
              items: _supportedLanguages.map((lang) {
                return DropdownMenuItem<String>(value: lang, child: Text(lang));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedLanguage = val);
                }
              },
            ),
            const SizedBox(height: 16),

            _buildLabel('Assign Doctor *'),
            if (_loadingDoctors)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: saathiGreen,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Loading available doctors...',
                      style: TextStyle(color: saathiBodyGrey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedDoctorId),
                initialValue: _selectedDoctorId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.medical_services_outlined),
                  hintText: 'Select doctor to assign',
                ),
                items: _doctors.map((doc) {
                  final details = [
                    doc.department,
                    doc.specialization,
                  ].whereType<String>().where((v) => v.isNotEmpty).join(' • ');
                  return DropdownMenuItem<int>(
                    value: doc.staffId,
                    child: Text(
                      'Dr. ${doc.name}${details.isNotEmpty ? " ($details)" : ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDoctorId = val;
                    _doctorTouched = true;
                  });
                },
                validator: (val) {
                  if ((_hasAttemptedSubmit || _doctorTouched) &&
                      val == null &&
                      _doctors.isNotEmpty) {
                    return 'Please select a doctor to assign';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Register Patient'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: saathiInk,
        ),
      ),
    );
  }
}
