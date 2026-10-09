import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../theme.dart';
import '../api_client.dart';
import 'staff_shell.dart';
import 'doctor_home_screen.dart';

import '../widgets/watermark_background.dart';

class LoginScreen extends StatefulWidget {
  final String role; // 'Hospital Staff' or 'Doctor'

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signIn(
        _idController.text.trim(),
        _passwordController.text,
        widget.role,
      );

      if (mounted) {
        final userRole = authProvider.role?.toLowerCase();
        if (userRole == 'doctor') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DoctorHomeScreen()),
            (route) => false,
          );
        } else if (userRole == 'receptionist' || userRole == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const StaffShell()),
            (route) => false,
          );
        }
      }
    } on ApiException catch (e) {
      debugPrint('[LoginScreen] ApiException: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('[LoginScreen] Unexpected ${e.runtimeType}: $e');
      setState(() {
        // Show the actual error type so we can diagnose issues.
        // In production, this should be a generic message.
        _errorMessage = kDebugMode
            ? 'Error: ${e.runtimeType} — $e'
            : 'An error occurred. Please check your connection and try again.';
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
    final Color roleColor = widget.role == 'Doctor' ? saathiGreen : saathiNavy;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: saathiCream,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: saathiInk),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isWide
          ? _buildWideLayout(context, roleColor)
          : _buildNarrowLayout(context, roleColor),
    );
  }

  /// Wide/desktop layout: full-viewport two-column 50/50 split.
  Widget _buildWideLayout(BuildContext context, Color roleColor) {
    return WatermarkBackground(
      child: SizedBox.expand(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT COLUMN: Exactly 50% of viewport width
            Expanded(
              flex: 1,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/saathi_logo.png',
                        height: 380,
                        width: 380,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.role,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: saathiNavy,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Log in to your portal account to continue',
                        style: TextStyle(
                          color: saathiBodyGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // RIGHT COLUMN: Exactly 50% of viewport width, card aligned to left edge
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-28, 0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 0.0, right: 48.0, top: 24.0, bottom: 24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 740),
                      child: _buildFormCard(context, roleColor, isWide: true),
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

  /// Narrow/mobile layout: single column, scrollable.
  Widget _buildNarrowLayout(BuildContext context, Color roleColor) {
    return WatermarkBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/saathi_logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.role,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: saathiNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in to your portal account to continue',
                    style: TextStyle(
                      color: saathiBodyGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildFormCard(context, roleColor, isWide: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, Color roleColor, {required bool isWide}) {
    final cardTitle = widget.role == 'Hospital Staff' ? 'Staff Login' : '${widget.role} Login';
    final cardSubtitle = widget.role == 'Doctor'
        ? 'Please enter your doctor credentials to access your account'
        : 'Please enter your staff credentials to access your account';
    final idLabel = widget.role == 'Doctor' ? 'Doctor ID / Username' : 'Staff ID / Username';
    final idHint = widget.role == 'Doctor' ? 'Enter your doctor ID' : 'Enter your staff ID';

    final double titleSize = isWide ? 34 : 24;
    final double subtitleSize = isWide ? 16 : 13;
    final double labelSize = isWide ? 16 : 14;
    final double inputFontSize = isWide ? 17 : 14;
    final double iconSize = isWide ? 24 : 20;
    final double buttonHeight = isWide ? 58 : 48;
    final double buttonFontSize = isWide ? 18 : 15;
    final double disclaimerSize = isWide ? 13 : 11.5;
    final EdgeInsets cardPadding = isWide
        ? const EdgeInsets.symmetric(horizontal: 48.0, vertical: 64.0)
        : const EdgeInsets.all(24.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: saathiLine.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: cardPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                cardTitle,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: saathiNavy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cardSubtitle,
                style: TextStyle(
                  fontSize: subtitleSize,
                  fontWeight: FontWeight.w500,
                  color: saathiBodyGrey,
                ),
              ),
              SizedBox(height: isWide ? 36 : 22),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: saathiEmergencyTint,
                    border: Border.all(color: saathiEmergency),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: saathiEmergency),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: saathiEmergencyDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              Text(
                idLabel,
                style: TextStyle(
                  color: saathiInk,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _idController,
                textInputAction: TextInputAction.next,
                style: TextStyle(fontSize: inputFontSize, color: saathiInk, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: idHint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: inputFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(
                      Icons.badge_outlined,
                      color: const Color(0xFF8B9DAF),
                      size: iconSize,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWide ? 22 : 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: saathiLine.withValues(alpha: 0.9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: saathiLine.withValues(alpha: 0.9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: saathiNavy, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your $idLabel';
                  }
                  return null;
                },
              ),
              SizedBox(height: isWide ? 28 : 16),

              Text(
                'Password',
                style: TextStyle(
                  color: saathiInk,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleSignIn(),
                style: TextStyle(fontSize: inputFontSize, color: saathiInk, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: inputFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(
                      Icons.lock_outline,
                      color: const Color(0xFF8B9DAF),
                      size: iconSize,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8B9DAF),
                        size: iconSize,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWide ? 22 : 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: saathiLine.withValues(alpha: 0.9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: saathiLine.withValues(alpha: 0.9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: saathiNavy, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              SizedBox(height: isWide ? 36 : 20),

              SizedBox(
                height: buttonHeight,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3A5C),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isWide ? 28 : 20),

              Text(
                'Accounts are created by hospital administrators only. If you do not have an account or need to reset credentials, please contact the IT department.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: saathiBodyGrey,
                  fontSize: disclaimerSize,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
