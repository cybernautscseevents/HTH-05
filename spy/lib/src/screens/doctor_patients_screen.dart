import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_provider.dart';
import '../theme.dart';
import '../widgets/page_header.dart';
import '../widgets/patient_table_view.dart';
import 'doctor_patient_profile_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _searchController = TextEditingController();
  List<PatientSearchResult>? _results;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssignedPatients();
  }

  Future<void> _loadAssignedPatients() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.useMockApi || auth.token == null) {
      setState(() => _results = []);
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final patients = await auth.apiClient.getMyAssignedPatients(token: auth.token!);
      if (mounted) setState(() => _results = patients);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        _results = null;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (authProvider.useMockApi || authProvider.token == null) {
        throw ApiException('The doctor patient list requires a signed-in backend session.');
      }
      final results = await authProvider.apiClient.getMyAssignedPatients(token: authProvider.token!);
      final filtered = results.where((patient) => patient.name.toLowerCase().contains(query.toLowerCase()) || patient.registrationNo.toLowerCase().contains(query.toLowerCase())).toList();
      if (mounted) {
        setState(() {
          _results = filtered;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header & search box
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'My Patients',
                subtitle: 'View and review patients under your care.',
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search patients by name or registration number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results = null;
                                _errorMessage = null;
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
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _performSearch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: saathiGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
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
          ),

        // Results area
        Expanded(
          child: _buildResultsArea(),
        ),
      ],
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: saathiGreen),
      );
    }

    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 56,
              color: saathiBodyGrey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Find a patient',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: saathiNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search by patient name or registration number.',
              style: TextStyle(
                fontSize: 13,
                color: saathiBodyGrey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 56,
              color: saathiBodyGrey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No patients found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: saathiNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name or registration number.',
              style: TextStyle(
                fontSize: 13,
                color: saathiBodyGrey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
            child: Text(
              '${_results!.length} ${_results!.length == 1 ? "record" : "records"} found',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: saathiBodyGrey,
              ),
            ),
          ),
          PatientTableView(
            patients: _results!,
            onPatientSelected: (patient) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorPatientProfileScreen(patient: patient),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

