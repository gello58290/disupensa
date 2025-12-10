import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isVerifying = false;
  bool _isUpdating = false;
  bool _showNewPasswordField = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _verifyOldPassword() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      // Sign in with email & old password to verify
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _oldPasswordController.text.trim(),
      );

      // Show new password field
      setState(() {
        _showNewPasswordField = true;
      });
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Old password is incorrect.';
      } else {
        message = 'Error: ${e.message}';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _updatePassword() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(_newPasswordController.text.trim());
        await _auth.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated successfully. Please log in again.')),
        );

        Navigator.of(context).pop(); // Go back to login page
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A6A8C), Color(0xFF1A6A8C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Forgot Password',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_showNewPasswordField)
                    TextField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Old Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_showNewPasswordField)
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  !_showNewPasswordField
                      ? ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyOldPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF987554),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isVerifying
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Verify Old Password',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        )
                      : ElevatedButton(
                          onPressed: _isUpdating ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF987554),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                             
                            ),
                           
                          ),
                          child: _isUpdating
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Update Password',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // back to login
                    },
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
