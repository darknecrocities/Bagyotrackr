import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _toggleForm() => setState(() => _isLogin = !_isLogin);

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      User? user;
      if (_isLogin) {
        user = await _firebaseService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        user = await _firebaseService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        // Optional: Save additional info (firstName, etc.) to Firestore
      }

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: user!)),
        );
      } else {
        _showError("Authentication failed.");
      }
    } catch (e) {
      _showError("Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && email.contains("@")) {
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showError("Password reset email sent.");
    } else {
      _showError("Enter a valid email to reset password.");
    }
  }

  InputDecoration _inputDecoration(String label, Icon icon) => InputDecoration(
    labelText: label,
    prefixIcon: icon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 12,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "🌀 TyphoonGuard",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? "Login to your account"
                          : "Create a new account",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    if (!_isLogin)
                      Column(
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            decoration: _inputDecoration(
                              "First Name",
                              const Icon(Icons.person),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? "First name is required"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: _inputDecoration(
                              "Last Name",
                              const Icon(Icons.person_outline),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? "Last name is required"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration(
                              "Phone Number",
                              const Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                    TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration(
                        "Email",
                        const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email.'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration:
                          _inputDecoration(
                            "Password",
                            const Icon(Icons.lock),
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters.';
                        } else if (!RegExp(
                          r'^(?=.*[A-Z])(?=.*\d)',
                        ).hasMatch(value)) {
                          return 'Include at least 1 uppercase & number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text("Forgot Password?"),
                        ),
                      ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_isLogin ? Icons.login : Icons.person_add),
                        label: Text(_isLogin ? "Login" : "Sign Up"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _toggleForm,
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Login",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
