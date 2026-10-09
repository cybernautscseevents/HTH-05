import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme.dart';

class PatientTableView extends StatelessWidget {
  final List<PatientSearchResult> patients;
  final ValueChanged<PatientSearchResult> onPatientSelected;
  final bool showDateOfBirth;
  final String? emptyMessage;

  final double? scrollViewportHeight;

  const PatientTableView({
    super.key,
    required this.patients,
    required this.onPatientSelected,
    this.showDateOfBirth = true,
    this.emptyMessage,
    this.scrollViewportHeight,
  });

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '—';
    try {
      final parsed = DateTime.parse(rawDate.trim());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: saathiLine),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 40,
                color: saathiBodyGrey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                emptyMessage ?? 'No patient records found.',
                style: const TextStyle(
                  color: saathiBodyGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 750;
        final isMedium = constraints.maxWidth >= 550;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: saathiLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F6F4),
                  border: Border(bottom: BorderSide(color: saathiLine)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: isWide ? 4 : 5,
                      child: const Text(
                        'PATIENT NAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: saathiNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: isWide ? 3 : 4,
                      child: const Text(
                        'REGISTRATION NO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: saathiNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (isMedium)
                      Expanded(
                        flex: isWide ? 4 : 4,
                        child: const Text(
                          'CONDITION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: saathiNavy,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    if (isWide && showDateOfBirth)
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'DOB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: saathiNavy,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    if (isWide)
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'LANGUAGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: saathiNavy,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    const SizedBox(
                      width: 48,
                      child: Text(
                        'ACTION',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: saathiNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Rows
              ConstrainedBox(
                constraints: scrollViewportHeight == null
                    ? const BoxConstraints()
                    : BoxConstraints.tightFor(height: scrollViewportHeight),
                child: ListView.separated(
                  shrinkWrap: scrollViewportHeight == null,
                  physics: scrollViewportHeight == null
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  itemCount: patients.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: saathiLine,
                ),
                itemBuilder: (context, index) {
                  final p = patients[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPatientSelected(p),
                      hoverColor: saathiMint.withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Patient Name with Initials
                            Expanded(
                              flex: isWide ? 4 : 5,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: saathiGreen.withValues(alpha: 0.12),
                                    child: Text(
                                      p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: saathiGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: saathiNavy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Registration Number Badge
                            Expanded(
                              flex: isWide ? 3 : 4,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: saathiCream,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: saathiLine,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    p.registrationNo,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: saathiNavy,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Condition
                            if (isMedium)
                              Expanded(
                                flex: isWide ? 4 : 4,
                                child: Text(
                                  p.diseaseCondition?.isNotEmpty == true
                                      ? p.diseaseCondition!
                                      : 'General Checkup',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: saathiInkSoft,
                                  ),
                                ),
                              ),

                            // Date of Birth
                            if (isWide && showDateOfBirth)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _formatDate(p.dateOfBirth),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: saathiBodyGrey,
                                  ),
                                ),
                              ),

                            // Preferred Language
                            if (isWide)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  p.preferredLanguage,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: saathiBodyGrey,
                                  ),
                                ),
                              ),

                            // Action button / chevron
                            SizedBox(
                              width: 48,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 13,
                                    color: saathiTeal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
