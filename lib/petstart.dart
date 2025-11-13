import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'pet_profile.dart';


class PetStart extends StatefulWidget {
  const PetStart({Key? key}) : super(key: key);

  @override
  State<PetStart> createState() => _PetStartState();
}

class _PetStartState extends State<PetStart> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController petName = TextEditingController();
  final TextEditingController petBreed = TextEditingController();
  final TextEditingController petAge = TextEditingController();
  final TextEditingController petWeight = TextEditingController();
  final TextEditingController petHabit = TextEditingController();

  String petGender = '';
  bool isLoading = false;


Future<void> registerUser() async {
  if (!_formKey.currentState!.validate()) return;
  if (petGender.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select gender')),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    String uid;
    if (_auth.currentUser != null) {
      uid = _auth.currentUser!.uid;
    } else {
      UserCredential userCredential = await _auth.signInAnonymously();
      uid = userCredential.user!.uid;
    }

    // ✅ FIXED — Firestore now accepts this
    await _firestore.collection('user').doc(uid).set({
      'petName': petName.text.trim(),
      'petBreed': petBreed.text.trim(),
      'petGender': petGender,
      'petAge': petAge.text.trim(),
      'petWeight': petWeight.text.trim(),
      'petHabit': petHabit.text.trim(),
      'createdAt': Timestamp.now(), // ✅ IMPORTANT
    });

    if (!mounted) return;

    // ✅ Navigation to PetProfile
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PetProfile(
          petName: petName.text.trim(),
          petBreed: petBreed.text.trim(),
          petGender: petGender,
          petAge: petAge.text.trim(),
          petWeight: petWeight.text.trim(),
          petHabit: petHabit.text.trim(),
        ),
      ),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8D6748), Color(0xFFB9935A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pets, size: 60, color: Color(0xFF8D6748)),
                      SizedBox(height: 12),
                      Text(
                        "Let's get started!",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      Text(
                        "Tell us about your furry friend",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(height: 24),
                      _buildTextField(
                        label: "Pet's Name",
                        controller: petName,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        label: "Pet's Breed",
                        controller: petBreed,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        label: "Pet's Age",
                        controller: petAge,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        label: "Pet's Weight",
                        controller: petWeight,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        label: "Pet's Habit",
                        controller: petHabit,
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: petGender.isEmpty ? null : petGender,
                        decoration: InputDecoration(
                          labelText: "Pet's Gender",
                          labelStyle: TextStyle(color: Color(0xFF8D6748)),
                          filled: true,
                          fillColor: Color(0xFFB3D3F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: ['Male', 'Female'].map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            petGender = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please select gender' : null,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4B8DF8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  "Finish!",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
          (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Color(0xFF8D6748), fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Color(0xFFB3D3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}