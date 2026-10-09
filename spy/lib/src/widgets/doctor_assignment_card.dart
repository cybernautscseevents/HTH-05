import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../auth_provider.dart';
import '../theme.dart';

class DoctorAssignmentCard extends StatefulWidget {
  final int patientId;
  const DoctorAssignmentCard({super.key, required this.patientId});

  @override
  State<DoctorAssignmentCard> createState() => _DoctorAssignmentCardState();
}

class _DoctorAssignmentCardState extends State<DoctorAssignmentCard> {
  DoctorAssignment? _assignment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.useMockApi || auth.token == null) {
      setState(() {
        _loading = false;
        _error = 'Doctor assignments require a backend connection.';
      });
      return;
    }
    try {
      final value = await auth.apiClient.getAssignedDoctor(
        widget.patientId,
        token: auth.token!,
      );
      if (mounted) {
        setState(() {
          _assignment = value;
          _error = null;
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() => _error = 'Unable to load assigned doctor');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _chooseDoctor() async {
    final auth = context.read<AuthProvider>();
    if (auth.useMockApi || auth.token == null) return;
    List<DoctorInfo> doctors;
    try {
      doctors = await auth.apiClient.getDoctors(token: auth.token!);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active doctors are available.')),
      );
      return;
    }
    final selected = await showDialog<DoctorInfo>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Doctor'),
        children: doctors
            .map(
              (doctor) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, doctor),
                child: ListTile(
                  title: Text(doctor.name),
                  subtitle: Text(
                    [doctor.department, doctor.specialization]
                        .whereType<String>()
                        .where((v) => v.isNotEmpty)
                        .join(' • '),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final saved = await auth.apiClient.assignDoctor(
        widget.patientId,
        selected.staffId,
        token: auth.token!,
      );
      if (mounted) {
        setState(() => _assignment = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor assignment saved.'),
            backgroundColor: saathiGreen,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: saathiEmergency),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role?.toLowerCase();
    final canAssign = role == 'admin' || role == 'receptionist';
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: saathiLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined, color: saathiTeal),
            const SizedBox(width: 14),
            Expanded(
              child: _loading
                  ? const Text('Loading assigned doctor...')
                  : _error != null
                  ? Row(
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: saathiEmergency),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Doctor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: saathiNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_assignment?.doctorName ?? 'No doctor assigned'),
                        if (_assignment?.department != null ||
                            _assignment?.specialization != null)
                          Text(
                            [
                                  _assignment?.department,
                                  _assignment?.specialization,
                                ]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(' • '),
                            style: const TextStyle(color: saathiBodyGrey),
                          ),
                      ],
                    ),
            ),
            if (canAssign && _error == null)
              TextButton(
                onPressed: _loading ? null : _chooseDoctor,
                child: Text(
                  _assignment?.assigned == true
                      ? 'Change Doctor'
                      : 'Assign Doctor',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
