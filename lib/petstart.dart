import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'pet_profile.dart';


class PetStart extends StatefulWidget {
  const PetStart({super.key});

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
  String selectedBreed = '';
  bool isLoading = false;

  // List of dog breeds
  final List<String> dogBreeds = [
    'Labrador Retriever',
    'German Shepherd',
    'Golden Retriever',
    'Bulldog',
    'Poodle',
    'Beagle',
  ];


Future<void> registerUser() async {
  if (!_formKey.currentState!.validate()) return;
  if (petGender.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select gender')),
    );
    return;
  }
  if (selectedBreed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a breed')),
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

    // ✅ Save pet data to subcollection: user/{uid}/pets/{petId}
    await _firestore
        .collection('user')
        .doc(uid)
        .collection('pets')
        .add({
      'petName': petName.text.trim(),
      'petBreed': selectedBreed,
      'petGender': petGender,
      'petAge': int.parse(petAge.text.trim()),
      'petWeight': double.parse(petWeight.text.trim()),
      'petHabit': petHabit.text.trim(),
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;

    // ✅ Navigation to PetProfile
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PetProfile(
          petName: petName.text.trim(),
          petBreed: selectedBreed,
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
      backgroundColor: const Color(0xFF1A6A8C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF66B2FF),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pets,
                        size: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Let's get started!",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Tell us about your furry friend",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Pet Name + Pet Breed Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: "Pet Name",
                              controller: petName,
                              inputFormatters: [LengthLimitingTextInputFormatter(20)],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter Pet Name';
                                if (value.length > 20) return 'Max 20 characters';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Breed",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedBreed.isEmpty ? null : selectedBreed,
                                  isExpanded: false,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                    hintText: "Breed",
                                  ),
                                  items: dogBreeds.map((breed) {
                                    return DropdownMenuItem<String>(
                                      value: breed,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          breed,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedBreed = value ?? '';
                                    });
                                  },
                                  validator: (value) => value == null || value.isEmpty
                                      ? 'Select breed'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Pet Age + Pet Weight Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: "Age",
                              controller: petAge,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter Age';
                                final parsed = int.tryParse(value);
                                if (parsed == null) return 'Enter whole number';
                                if (parsed < 0 || parsed > 10) return 'Age must be 0-10';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              label: "Weight",
                              controller: petWeight,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), LengthLimitingTextInputFormatter(5)],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter Weight';
                                // Allow up to 2 integer digits and up to 2 decimal digits
                                final pattern = RegExp(r'^\d{1,2}(?:\.\d{1,2})?$');
                                if (!pattern.hasMatch(value)) return 'Enter valid weight (e.g. 12.5)';
                                final parsed = double.tryParse(value);
                                if (parsed == null) return 'Enter valid number';
                                if (parsed <= 0) return 'Invalid weight';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Pet Habit Full Width
                      _buildTextField(
                        label: "Pet Habit",
                        controller: petHabit,
                      ),

                      // Pet Gender Full Width
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Pet Gender",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: petGender.isEmpty ? null : petGender,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              isDense: true,
                              hintText: "Select",
                            ),
                            items: ['Male', 'Female'].map((gender) {
                              return DropdownMenuItem<String>(
                                value: gender,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    gender,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                petGender = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please select gender'
                                : null,
                            menuMaxHeight: 80,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Finish Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF987554),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                )
                              : const Text(
                                  "Finish!",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator ??
              (value) => value == null || value.isEmpty ? 'Enter $label' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}