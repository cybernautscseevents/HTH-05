import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';
import '../api_client.dart';
import '../theme.dart';
import '../widgets/page_header.dart';
import '../widgets/patient_table_view.dart';
import 'patient_profile_screen.dart';

class SearchPatientsScreen extends StatefulWidget {
  const SearchPatientsScreen({super.key});

  @override
  State<SearchPatientsScreen> createState() => _SearchPatientsScreenState();
}

class _SearchPatientsScreenState extends State<SearchPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PatientSearchResult>? _allPatients;
  List<PatientSearchResult>? _filteredPatients;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      late final List<PatientSearchResult> patients;

      if (authProvider.useMockApi) {
        patients = await authProvider.mockApiClient.searchPatients('');
      } else {
        final token = authProvider.token;
        if (token == null) {
          throw ApiException('Session expired. Please sign in again.');
        }
        patients = await authProvider.apiClient.searchPatients(
          '',
          token: token,
        );
      }

      if (!mounted) return;

      setState(() {
        _allPatients = patients;
        _applyFilter(_searchController.text);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _allPatients = [];
        _filteredPatients = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Failed to load patients. Please check your connection.';
        _allPatients = [];
        _filteredPatients = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter(String query) {
    final trimmed = query.trim().toLowerCase();
    if (_allPatients == null) {
      _filteredPatients = null;
      return;
    }

    if (trimmed.isEmpty) {
      _filteredPatients = List.of(_allPatients!);
    } else {
      _filteredPatients = _allPatients!.where((p) {
        return p.name.toLowerCase().contains(trimmed) ||
            p.registrationNo.toLowerCase().contains(trimmed) ||
            (p.diseaseCondition?.toLowerCase().contains(trimmed) ?? false) ||
            p.preferredLanguage.toLowerCase().contains(trimmed);
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _applyFilter(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _applyFilter('');
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    // Fast local filter first if all patients already in memory
    if (_allPatients != null) {
      setState(() {
        _applyFilter(query);
      });
    }

    // Also refresh from API/Mock
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      late final List<PatientSearchResult> results;

      if (authProvider.useMockApi) {
        results = await authProvider.mockApiClient.searchPatients(query);
      } else {
        final token = authProvider.token;
        if (token == null) {
          throw ApiException('Session expired. Please sign in again.');
        }
        results = await authProvider.apiClient.searchPatients(
          query,
          token: token,
        );
      }

      if (!mounted) return;

      setState(() {
        if (query.isEmpty) {
          _allPatients = results;
        }
        _filteredPatients = results;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search failed. Please check your connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPatientProfile(PatientSearchResult patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PatientProfileScreen(patient: patient),
      ),
    );

    if (!mounted) return;
    _loadAllPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: PageHeader(
                      title: 'Patients',
                      subtitle: 'View and manage all registered patients.',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadAllPatients,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: saathiGreen,
                      side: const BorderSide(color: saathiGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // SEARCH BAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name, registration number, or condition',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
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
                  child:
                      _isLoading &&
                          (_filteredPatients != null &&
                              _filteredPatients!.isNotEmpty)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Search'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ERROR
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
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: saathiEmergencyDeep,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: saathiEmergencyDeep,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadAllPatients,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: saathiEmergencyDeep),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // RESULTS
        Expanded(child: _buildResultsArea()),
      ],
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading &&
        (_filteredPatients == null || _filteredPatients!.isEmpty)) {
      return const Center(child: CircularProgressIndicator(color: saathiGreen));
    }

    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

    if (_filteredPatients == null || _filteredPatients!.isEmpty) {
      if (isSearching) {
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
                'No matching patients found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: saathiNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No records found for "$query".',
                style: TextStyle(
                  fontSize: 13,
                  color: saathiBodyGrey.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Show All Patients'),
                style: FilledButton.styleFrom(backgroundColor: saathiGreen),
              ),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 56,
                color: saathiBodyGrey.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'No patients registered yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: saathiNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Registered patients will appear here automatically.',
                style: TextStyle(
                  fontSize: 13,
                  color: saathiBodyGrey.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSearching
                      ? 'Found ${_filteredPatients!.length} ${_filteredPatients!.length == 1 ? "record" : "records"} for "$query"'
                      : 'All Registered Patients (${_filteredPatients!.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: saathiNavy,
                  ),
                ),
                if (isSearching)
                  TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'Show all patients',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(foregroundColor: saathiTeal),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => PatientTableView(
                patients: _filteredPatients!,
                onPatientSelected: _openPatientProfile,
                // Rows scroll inside the table while its header remains fixed.
                scrollViewportHeight: (constraints.maxHeight - 60).clamp(
                  0.0,
                  800.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
