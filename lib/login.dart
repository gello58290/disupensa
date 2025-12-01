import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register.dart';
import 'petstart.dart';
import 'homepage.dart';
import 'Forgot_Password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isForgotPasswordHovered = false;
  bool isRegisterHovered = false;

  // Check if user has registered a pet
  Future<bool> hasPetRegistered(String uid) async {
    try {
      final petsSnapshot = await _firestore
          .collection('user')
          .doc(uid)
          .collection('pets')
          .limit(1)
          .get();
      return petsSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Function for login
   Future<void> loginUser() async {
  setState(() => isLoading = true);
  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    if (!mounted) return;
    
    // Check if user has registered a pet
    bool petExists = await hasPetRegistered(userCredential.user!.uid);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login successful!')),
    );
    
    if (mounted) {
      if (petExists) {
        // User has pet → go to homepage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        // User has no pet → go to petstart
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PetStart()),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    String message = 'Login failed';
    if (e.code == 'user-not-found') {
      message = 'Wrong email. No user found for that email.';
    } else if (e.code == 'wrong-password') {
      message = 'Wrong password. Please try again.';
    } else if (e.code == 'invalid-email') {
      message = 'Invalid email format.';
    } else if (e.code == 'user-disabled') {
      message = 'This account has been disabled.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An unexpected error occurred: $e')),
    );
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A6A8C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 30),
                  child: Text(
                    "Disupensa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66B2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Email field with validation
                        buildTextField(
                          label: "Email Address",
                          controller: emailController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),

                        // Password field with validation
                        buildTextField(
                          label: "Password",
                          controller: passwordController,
                          obscure: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Login button
                        isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: loginUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF987554),
                                  minimumSize: const Size(double.infinity, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  "Enter",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                        const SizedBox(height: 8),

                        // Navigation to Forgot Password with hover effect
                        MouseRegion(
                          onEnter: (_) => setState(() => isForgotPasswordHovered = true),
                          onExit: (_) => setState(() => isForgotPasswordHovered = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: isForgotPasswordHovered 
                                    ? const Color.fromARGB(255, 0, 62, 112)
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: isForgotPasswordHovered ? 13 : 12,
                             
                              ),
                            ),
                          ),
                        ),

                        const Divider(color: Colors.black),

                        // Navigation to Register
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don’t have an account yet? ",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 12),
                            ),
                            MouseRegion(
                              onEnter: (_) => setState(() => isRegisterHovered = true),
                              onExit: (_) => setState(() => isRegisterHovered = false),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Register",
                                  style: TextStyle(
                                    color: isRegisterHovered
                                        ? const Color.fromARGB(255, 0, 62, 112)
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isRegisterHovered ? 13 : 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom text field widget
  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(                                       
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}


        