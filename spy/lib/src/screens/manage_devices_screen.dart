import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../auth_provider.dart';
import '../api_client.dart';
import '../theme.dart';
import '../widgets/page_header.dart';

class _ActivationCountdownTimer extends StatefulWidget {
  final String rawExpiry;

  /// Called once when the countdown reaches zero — use to re-fetch
  /// activation state so the dialog immediately shows the correct status.
  final VoidCallback? onExpired;

  const _ActivationCountdownTimer({required this.rawExpiry, this.onExpired});

  @override
  State<_ActivationCountdownTimer> createState() => _ActivationCountdownTimerState();
}

class _ActivationCountdownTimerState extends State<_ActivationCountdownTimer> {
  Timer? _timer;
  late DateTime _targetTime;
  Duration _remaining = Duration.zero;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _parseTarget();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _parseTarget() {
    final clean = widget.rawExpiry.replaceAll('Expires: ', '').trim();
    _targetTime = DateTime.tryParse(clean) ?? DateTime.now().add(const Duration(minutes: 30));
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = _targetTime.difference(now);
    final wasPositive = _remaining > Duration.zero;
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
      // Fire onExpired exactly once, the first time the timer reaches zero.
      if (wasPositive && _remaining == Duration.zero && !_expiredFired) {
        _expiredFired = true;
        widget.onExpired?.call();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ActivationCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawExpiry != widget.rawExpiry) {
      _parseTarget();
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 18, color: saathiEmergency),
          SizedBox(width: 6),
          Text(
            'EXPIRED — Please generate new code',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: saathiEmergency,
            ),
          ),
        ],
      );
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final String timeStr = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s'
        : '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 18, color: saathiEmergency),
        const SizedBox(width: 6),
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: saathiEmergency,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(${widget.rawExpiry.replaceAll('Expires: ', '')})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: saathiEmergency.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class ManageDevicesScreen extends StatefulWidget {
  final PatientSearchResult? initialPatient;

  const ManageDevicesScreen({
    super.key,
    this.initialPatient,
  });

  @override
  State<ManageDevicesScreen> createState() => _ManageDevicesScreenState();
}

class _ManageDevicesScreenState extends State<ManageDevicesScreen> {
  final _searchController = TextEditingController();

  // Search state
  List<PatientSearchResult>? _searchResults;
  bool _isSearching = false;
  String? _searchError;

  // Selected patient + device state
  PatientSearchResult? _selectedPatient;
  List<PatientDevice>? _devices;
  bool _isLoadingDevices = false;
  bool _isGeneratingActivation = false;
  String? _deviceError;
  Map<String, String>? _activationInfo;

  @override
  void initState() {
    super.initState();
    if (widget.initialPatient != null) {
      _selectedPatient = widget.initialPatient;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDevicesForPatient(widget.initialPatient!);
      });
    }
  }



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _selectedPatient = null;
      _devices = null;
      _deviceError = null;
      _activationInfo = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      late final List<PatientSearchResult> results;
      if (auth.useMockApi) {
        results = await auth.mockApiClient.searchPatients(query);
      } else {
        final token = auth.token;
        if (token == null) throw ApiException('Session expired. Please sign in again.');
        results = await auth.apiClient.searchPatients(query, token: token);
      }
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.message;
          _searchResults = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Search failed. Please try again.';
          _searchResults = null;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadDevicesForPatient(PatientSearchResult patient) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _selectedPatient = patient;
      _isLoadingDevices = true;
      _deviceError = null;
      _devices = null;
      _activationInfo = null;
    });

    try {
      if (auth.useMockApi) {
        final devices = await auth.mockApiClient.listPatientDevices(patient.registrationNo);
        final activation = await auth.mockApiClient.getPatientActivation(patient.registrationNo);
        if (mounted) {
          setState(() {
            _devices = devices;
            _activationInfo = activation;
            _isLoadingDevices = false;
          });
        }
      } else {
        final token = auth.token;
        if (token == null) throw ApiException('Session expired. Please sign in again.');
        final devices = await auth.apiClient.listPatientDevices(patient.patientId, token: token);
        final activation = await auth.apiClient.getPatientActivation(patient.patientId, token: token);
        if (mounted) {
          setState(() {
            _devices = devices;
            if (activation != null) {
              _activationInfo = {
                'uid': patient.registrationNo,
                'code': activation.activationCode,
                'qrPayload': activation.isUsed ? '' : activation.qrJsonString,
                'deviceIdentifier': activation.deviceIdentifier,
                'expiresAt': activation.expiresAt != null
                    ? 'Expires: ${activation.expiresAt}'
                    : 'Active',
                if (activation.usedAt != null) 'usedAt': activation.usedAt!,
              };
            }
            _isLoadingDevices = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceError = e is ApiException
              ? e.message
              : 'Failed to load device status. Please try again.';
          _isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> _revokeDevice(PatientDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: saathiEmergency, size: 24),
            SizedBox(width: 10),
            Text(
              'Revoke Device Access',
              style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to revoke access for ${_selectedPatient!.name} on "${device.deviceIdentifier}"?',
              style: const TextStyle(fontSize: 14, color: saathiInk, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Revoking access will terminate this device\'s Saathi access immediately. The patient will need a new activation to use Saathi again.',
              style: TextStyle(fontSize: 13, color: saathiBodyGrey, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: saathiBodyGrey, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: saathiEmergency,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Revoke Device'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (auth.useMockApi) {
        await auth.mockApiClient.revokeDevice(
          _selectedPatient!.registrationNo,
          device.deviceId,
        );
      } else {
        final token = auth.token;
        if (token == null) throw ApiException('Session expired. Please sign in again.');
        await auth.apiClient.revokeDevice(device.deviceId, token: token);
      }

      if (mounted) {
        setState(() {
          _devices?.removeWhere((d) => d.deviceId == device.deviceId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device access revoked successfully.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoke failed: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showActivationModal({bool isNew = false}) {
    String selectedIdentifier = 'Patient Primary Device';
    int selectedExpiryMinutes = 30;
    final customIdentifierController = TextEditingController();
    bool showCustomInput = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasActivation = _activationInfo != null;

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 780),
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 22, 32, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_2, color: saathiGreen, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Device Activation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: saathiNavy,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: saathiBodyGrey, size: 22),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: saathiLine, height: 20),

                      if (hasActivation) ...[
                        // ── Branch: code already consumed by patient ──────────
                        if (_activationInfo!.containsKey('usedAt')) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7EE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF4CAF50)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 40),
                                const SizedBox(height: 10),
                                const Text(
                                  'Device Successfully Linked',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Patient scanned the code at ${_activationInfo!['usedAt']}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF388E3C), height: 1.4),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'The QR code is no longer valid. If the patient needs to re-link, generate a new code.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Color(0xFF66BB6A), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                        // ── Branch: active, unused code — show QR ─────────────
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: saathiCream,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: saathiLine),
                            ),
                            child: QrImageView(
                              data: _activationInfo!['qrPayload'] ?? '',
                              version: QrVersions.auto,
                              size: 165.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: saathiNavy,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: saathiNavy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Scan to link device',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: saathiInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Ask the patient to scan this QR code using their Saathi app to link their account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: saathiBodyGrey),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: saathiCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: saathiLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'ACTIVATION CREDENTIALS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: saathiBodyGrey,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildCredentialTile(
                                'DEVICE IDENTIFIER',
                                _activationInfo!['deviceIdentifier'] ?? 'Patient Primary Device',
                              ),
                              const Divider(color: saathiLine, height: 14),
                              _buildCredentialTile(
                                'PATIENT ID',
                                _selectedPatient!.patientId.toString(),
                              ),
                              const Divider(color: saathiLine, height: 14),
                              _buildCredentialTile(
                                'REGISTRATION NUMBER',
                                _selectedPatient!.registrationNo,
                              ),
                              const Divider(color: saathiLine, height: 14),
                              _buildCredentialTile(
                                'ACTIVATION CODE',
                                _activationInfo!['code'] ?? '',
                                isLarge: true,
                              ),
                              const Divider(color: saathiLine, height: 14),
                              _buildCredentialTile(
                                'VALIDITY / EXPIRY',
                                '',
                                showCopy: false,
                                customWidget: _ActivationCountdownTimer(
                                  rawExpiry: _activationInfo!['expiresAt'] ?? '',
                                  // When the code expires on screen, immediately
                                  // re-fetch from the server so the dialog shows
                                  // the correct state (used/expired) without
                                  // requiring a manual Close + reopen.
                                  onExpired: () async {
                                    if (_selectedPatient == null) return;
                                    await _loadDevicesForPatient(_selectedPatient!);
                                    setModalState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        ], // end active code branch
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Issue Device Activation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: saathiNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Generate a secure, single-use activation code and QR payload for ${_selectedPatient!.name}.',
                                style: const TextStyle(fontSize: 13, color: saathiBodyGrey, height: 1.4),
                              ),
                              const SizedBox(height: 14),

                              const Text(
                                'Device Identifier *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: saathiInk),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedIdentifier,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.smartphone_outlined, size: 18),
                                  hintText: 'Select device purpose',
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Patient Primary Device', child: Text('Patient Primary Device')),
                                  DropdownMenuItem(value: 'Patient Secondary Phone', child: Text('Patient Secondary Phone')),
                                  DropdownMenuItem(value: 'Family Caregiver Device', child: Text('Family Caregiver Device')),
                                  DropdownMenuItem(value: 'Custom', child: Text('Custom Identifier...')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      selectedIdentifier = val;
                                      showCustomInput = val == 'Custom';
                                    });
                                  }
                                },
                              ),
                              if (showCustomInput) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customIdentifierController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter custom device name or label',
                                    prefixIcon: Icon(Icons.edit_outlined, size: 18),
                                    isDense: true,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              const Text(
                                'Activation Expiry',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: saathiInk),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: selectedExpiryMinutes,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.timer_outlined, size: 18),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 15, child: Text('15 minutes')),
                                  DropdownMenuItem(value: 30, child: Text('30 minutes (Standard)')),
                                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                                  DropdownMenuItem(value: 1440, child: Text('24 hours')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedExpiryMinutes = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              FilledButton.icon(
                                onPressed: _isGeneratingActivation
                                    ? null
                                    : () async {
                                        final devId = showCustomInput
                                            ? customIdentifierController.text.trim()
                                            : selectedIdentifier;
                                        if (devId.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Please enter a device identifier')),
                                          );
                                          return;
                                        }

                                        setModalState(() => _isGeneratingActivation = true);
                                        final auth = Provider.of<AuthProvider>(context, listen: false);

                                        try {
                                          if (auth.useMockApi) {
                                            // Mock logic simplified for demo
                                            final generatedCode = '${1000 + Random().nextInt(9000)}-${1000 + Random().nextInt(9000)}';
                                            final expiryTime = DateTime.now().add(Duration(minutes: selectedExpiryMinutes));
                                            setState(() {
                                              _activationInfo = {
                                                'uid': _selectedPatient!.registrationNo,
                                                'code': generatedCode,
                                                'qrPayload': '{"patient_id": ${_selectedPatient!.patientId}, "device_identifier": "$devId", "activation_code": "$generatedCode"}',
                                                'deviceIdentifier': devId,
                                                'expiresAt': 'Expires: ${expiryTime.toIso8601String()}',
                                              };
                                            });
                                            setModalState(() {});
                                          } else {
                                            final token = auth.token;
                                            if (token == null) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Session expired. Please sign in again.')),
                                                );
                                              }
                                              return;
                                            }
                                            try {
                                              final result = await auth.apiClient.createActivation(
                                                _selectedPatient!.patientId,
                                                deviceIdentifier: devId,
                                                expiresInMinutes: selectedExpiryMinutes,
                                                token: token,
                                              );
                                              setState(() {
                                                _activationInfo = {
                                                  'uid': _selectedPatient!.registrationNo,
                                                  'code': result.activationCode,
                                                  'qrPayload': result.qrJsonString,
                                                  'deviceIdentifier': result.deviceIdentifier,
                                                  'expiresAt': result.expiresAt != null
                                                      ? 'Expires: ${result.expiresAt}'
                                                      : 'Valid for $selectedExpiryMinutes minutes',
                                                };
                                              });
                                              setModalState(() {});
                                            } on ApiException catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Activation failed: ${e.message}')),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Activation failed. Please try again.')),
                                                );
                                              }
                                            }
                                          }
                                        } finally {
                                          if (mounted) {
                                            setModalState(() => _isGeneratingActivation = false);
                                          }
                                        }
                                      },
                                icon: _isGeneratingActivation
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.qr_code_2, size: 18),
                                label: Text(_isGeneratingActivation
                                    ? 'Generating Activation...'
                                    : 'Generate Activation QR & Code'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  backgroundColor: saathiGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (hasActivation) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    _activationInfo = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Generate New Code'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  foregroundColor: saathiNavy,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                backgroundColor: saathiNavy,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCredentialTile(
    String label,
    String value, {
    bool isLarge = false,
    bool showCopy = true,
    Widget? customWidget,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: saathiBodyGrey),
              ),
              const SizedBox(height: 2),
              if (customWidget != null)
                customWidget
              else
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: isLarge ? 18 : 14.5,
                    fontWeight: FontWeight.w900,
                    color: isLarge ? saathiTeal : saathiNavy,
                    fontFamily: isLarge ? 'monospace' : null,
                    letterSpacing: isLarge ? 1.2 : 0.0,
                  ),
                ),
            ],
          ),
        ),
        if (showCopy)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18, color: saathiTeal),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Copy',
          ),
      ],
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
      _devices = null;
      _deviceError = null;
      _activationInfo = null;
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const PageHeader(
            title: 'Device Management',
            subtitle: 'Manage Saathi devices linked to registered patients.',
          ),
          const SizedBox(height: 20),

          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name or registration number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = null;
                                _searchError = null;
                              });
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (text) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSearching ? null : _performSearch,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: saathiGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSearching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error banner
          if (_searchError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: saathiEmergencyTint,
                border: Border.all(color: saathiEmergency),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _searchError!,
                style: const TextStyle(
                  color: saathiEmergencyDeep,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main Workspace Area
          if (_selectedPatient != null)
            _buildSelectedPatientWorkspace()
          else
            _buildSearchResultsArea(),
        ],
      ),
    );
  }

  // ── Search Results or Initial State ───────────────────────────────────────

  Widget _buildSearchResultsArea() {
    if (_searchResults == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: saathiLine),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: saathiCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: saathiLine),
                ),
                child: const Icon(
                  Icons.devices_outlined,
                  size: 48,
                  color: saathiTeal,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Find a patient to view their Saathi device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: saathiNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search for any registered patient by name or registration number to view device status, check active connections, or review activation details.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: saathiBodyGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: saathiLine),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined, size: 48, color: saathiBodyGrey),
              SizedBox(height: 14),
              Text(
                'No patients found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: saathiNavy),
              ),
              SizedBox(height: 4),
              Text(
                'No patients match your search. Check the spelling or registration number.',
                style: TextStyle(fontSize: 13, color: saathiBodyGrey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final patient = _searchResults![index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _loadDevicesForPatient(patient),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: saathiGreen.withValues(alpha: 0.12),
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: saathiNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: saathiMint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                patient.registrationNo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: saathiGreen,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (patient.diseaseCondition != null &&
                                patient.diseaseCondition!.trim().isNotEmpty)
                              Text(
                                '• ${patient.diseaseCondition}',
                                style: const TextStyle(fontSize: 12, color: saathiBodyGrey),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _loadDevicesForPatient(patient),
                    icon: const Icon(Icons.devices, size: 16),
                    label: const Text('View Devices'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      foregroundColor: saathiTeal,
                      side: const BorderSide(color: saathiTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Selected Patient Device Workspace ────────────────────────────────────

  Widget _buildSelectedPatientWorkspace() {
    final patient = _selectedPatient!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation & Patient Identity Header
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                if (widget.initialPatient != null) {
                  Navigator.pop(context);
                } else {
                  _clearSelection();
                }
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(widget.initialPatient != null ? 'Back' : 'Back to Search'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                foregroundColor: saathiInk,
                side: const BorderSide(color: saathiLine),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      patient.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: saathiMint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      patient.registrationNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: saathiGreen,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoadingDevices)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: saathiGreen),
            ),
          )
        else if (_deviceError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: saathiEmergencyTint,
              border: Border.all(color: saathiEmergency),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceError!,
                  style: const TextStyle(color: saathiEmergencyDeep, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _loadDevicesForPatient(patient),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: saathiEmergency,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_devices != null)
          ...(() {
            // Show all non-revoked devices, plus pending activation card if any device is pending.
            final activeDevices = _devices!.where((d) => d.status == 'active').toList();
            final pendingDevices = _devices!.where((d) => d.status == 'pending').toList();
            final noDevices = _devices!.isEmpty || (activeDevices.isEmpty && pendingDevices.isEmpty);
            return [
              ...activeDevices.map((d) => _buildActiveDeviceCard(d)),
              ...pendingDevices.map((d) => _buildPendingDeviceCard(d)),
              if (noDevices) _buildPendingActivationCard(),
            ];
          })(),
      ],
    );
  }

  // ── State A: Active Device Card ──────────────────────────────────────────

  Widget _buildActiveDeviceCard(PatientDevice device) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: saathiLine),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smartphone, color: saathiNavy, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Saathi Device',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: saathiMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 13, color: saathiGreen),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: saathiGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: saathiLine, height: 28),
            Text(
              device.deviceIdentifier,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: saathiInk,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.link, size: 16, color: saathiBodyGrey),
                const SizedBox(width: 6),
                Text(
                  device.linkedAt != null
                      ? 'Linked on ${_formatDate(device.linkedAt)}'
                      : 'Not yet linked',
                  style: const TextStyle(fontSize: 13, color: saathiBodyGrey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _revokeDevice(device),
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Revoke Device'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  foregroundColor: saathiEmergency,
                  side: const BorderSide(color: saathiEmergency),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State B1: Pending Device Card (activation issued, not used) ──────────────

  Widget _buildPendingDeviceCard(PatientDevice device) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: saathiLine),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phonelink_lock_outlined, color: saathiNavy, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Saathi Device',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: saathiAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_outlined, size: 13, color: saathiAmber),
                      SizedBox(width: 4),
                      Text(
                        'Pending Activation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: saathiAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: saathiLine, height: 28),
            Text(
              device.deviceIdentifier,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: saathiInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Activation issued. Waiting for patient to scan the QR code.',
              style: TextStyle(fontSize: 14, color: saathiBodyGrey),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _showActivationModal,
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('Show Activation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: saathiTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State C: Pending Activation Card (no device registered at all) ────────

  Widget _buildPendingActivationCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: saathiLine),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phonelink_lock_outlined, color: saathiNavy, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Saathi Device',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: saathiAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_outlined, size: 13, color: saathiAmber),
                      SizedBox(width: 4),
                      Text(
                        'Pending Activation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: saathiAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: saathiLine, height: 28),
            const Text(
              'Pending Activation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: saathiInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This patient has not linked a Saathi device yet.',
              style: TextStyle(fontSize: 14, color: saathiBodyGrey),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _showActivationModal,
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('View Activation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: saathiTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
