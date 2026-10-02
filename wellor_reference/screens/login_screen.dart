import 'dart:ui';
import 'dart:math' as math; // Required for background motion
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For High-Fidelity Haptics
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/security_utils.dart';

/// UNICORN GRADE: High-Fidelity Identity Portal.
/// Features: Kinetic Mesh Background, Glassmorphic Triage, and Seamless Layout Morph.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(parent: _mainController, curve: Curves.easeOut);
    
    // Kinetic Background Controller
    _bgAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    
    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bgAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ============================================
  // UI COMPONENTS: THE UNICORN LAYER
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. KINETIC BACKGROUND: Mesh Gradient
          _buildKineticBackground(),

          // 2. BLUR LAYER
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBrandHeader(),
                      const SizedBox(height: 40),
                      _buildGlassForm(),
                      const SizedBox(height: 24),
                      _buildToggleLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKineticBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(_bgAnimationController.value * 2 * math.pi) * 0.5,
                math.cos(_bgAnimationController.value * 2 * math.pi) * 0.5,
              ),
              colors: const [Color(0xFF4CAF50), Color(0xFF1B5E20), Colors.black],
              radius: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10)],
          ),
          child: ClipOval(child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover)),
        ),
        const SizedBox(height: 20),
        const Text('Wellor', 
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5)),
        Text('SYNCHRONIZING NUTRITION', 
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 3)),
      ],
    );
  }

  Widget _buildGlassForm() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutQuart,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                if (!_isLogin) ...[
                  _buildTextField(_nameController, 'Display Name', Icons.badge_outlined),
                  const SizedBox(height: 16),
                ],
                _buildTextField(_emailController, 'Email', Icons.alternate_email_rounded),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Password', Icons.lock_open_rounded, obscure: true),
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_rounded, obscure: true),
                ],
                
                if (_errorMessage != null) _buildErrorLabel(),
                
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.greenAccent, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.greenAccent)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _authenticate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.black)
          : Text(_isLogin ? 'Log In' : 'Sign Up', 
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildToggleLink() {
    return TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isLogin = !_isLogin;
          _errorMessage = null;
        });
      },
      child: Text(
        _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In",
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorLabel() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // ============================================
  // LOGIC: NEURAL AUTHENTICATION
  // ============================================

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first to reset your password.');
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      await auth.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset link sent to $email')),
        );
      }
    } catch (e) {
      // The auth provider already sets the error message on failure
    }
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();
    final security = SecurityManager();

    // SECURITY: Input validation
    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      setState(() => _errorMessage = 'All fields required.');
      return;
    }

    // SECURITY: Email format validation
    if (!security.isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    // SECURITY: Password strength check (sign up only)
    if (!_isLogin) {
      final passwordStrength = security.validatePassword(password);
      if (passwordStrength == PasswordStrength.weak) {
        setState(() => _errorMessage = 'Password too weak. Use 8+ chars with uppercase, numbers, and symbols.');
        return;
      }
    }

    // SECURITY: Password confirmation check
    if (!_isLogin && password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    // SECURITY: Name validation (sign up only)
    if (!_isLogin && name.length < 2) {
      setState(() => _errorMessage = 'Name must be at least 2 characters.');
      return;
    }

    // SECURITY: Sanitize display name
    final sanitizedName = !_isLogin ? security.sanitizeInput(name) : name;

    // SECURITY: Rate limiting check
    if (security.isRateLimited('auth_attempt', maxRequests: 5, window: const Duration(minutes: 1))) {
      setState(() => _errorMessage = 'Too many attempts. Please wait a minute.');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    final authProvider = context.read<AuthProvider>();
    String? error;

    if (_isLogin) {
      error = await authProvider.signIn(email, password);
    } else {
      error = await authProvider.signUp(email: email, password: password, name: sanitizedName);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }
}