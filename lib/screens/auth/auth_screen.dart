import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _deviceIdController = TextEditingController(text: 'ESP32_001');

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    if (_isSignUp) {
      success = await authProvider.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        deviceId: _deviceIdController.text,
      );
    } else {
      success = await authProvider.signIn(
        _emailController.text,
        _passwordController.text,
      );
    }

    if (!mounted) return;

    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryCyan.withOpacity(0.2),
                        AppTheme.primaryTeal.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    size: 64,
                    color: AppTheme.primaryCyan,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Smart Medicine Companion',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Create an account & pair your ESP32 device'
                      : 'Sign in to access your medicine schedule',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Form Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Please enter your name'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter email';
                              }
                              if (!val.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? 'Password must be at least 6 chars'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Device ID field on Sign Up
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _deviceIdController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'ESP32 Device ID',
                                hintText: 'e.g. ESP32_001',
                                prefixIcon: Icon(Icons.memory_rounded),
                                helperText:
                                    'Found on hardware label or OLED screen',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Please enter Device ID'
                                      : null,
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],

                          // Submit Button
                          ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _submit,
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(_isSignUp ? 'Register & Pair' : 'Sign In'),
                          ),
                          const SizedBox(height: 12),

                          // Quick Start / Guest Pair Button
                          OutlinedButton.icon(
                            onPressed: authProvider.isLoading
                                ? null
                                : () async {
                                    final devId = _deviceIdController.text.trim().isEmpty
                                        ? 'ESP32_001'
                                        : _deviceIdController.text.trim();
                                    await authProvider.quickStart(devId);
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryCyan,
                              side: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.bolt_rounded, color: AppTheme.primaryCyan),
                            label: const Text(
                              '⚡ Quick Start & Pair ESP32_001',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle Login / Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account?'
                          : "Don't have an account?",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                        });
                      },
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
