// pet_profile.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule.dart';

class PetProfile extends StatefulWidget {
  final String petName;
  final String petBreed;
  final String petGender;
  final String petAge;
  final String petWeight;
  final String petHabit;

  const PetProfile({
    super.key,
    required this.petName,
    required this.petBreed,
    required this.petGender,
    required this.petAge,
    required this.petWeight,
    required this.petHabit,
  });

  @override
  State<PetProfile> createState() => _PetProfileState();
}

class _PetProfileState extends State<PetProfile> {
  late TextEditingController nameController;
  late TextEditingController breedController;
  late TextEditingController ageController;
  late TextEditingController weightController;
  late TextEditingController habitController;
  late String gender;
  bool isEditing = false;
  int currentTab = 2;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Owner info
  String ownerFirstName = '';
  String ownerLastName = '';
  String ownerAge = '';
  String ownerGender = '';
  String ownerAddress = '';
  String ownerEmail = '';
  bool ownerLoading = true;
  String? ownerUid;
  bool ownerDocExists = false;
  Map<String, dynamic>? ownerDocData;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.petName);
    breedController = TextEditingController(text: widget.petBreed);
    ageController = TextEditingController(text: widget.petAge);
    weightController = TextEditingController(text: widget.petWeight);
    habitController = TextEditingController(text: widget.petHabit);
    gender = widget.petGender;
    _fetchOwnerProfile();
  }

  Future<void> _fetchOwnerProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('user').doc(uid).get();
      ownerUid = uid;
      ownerDocExists = doc.exists;
      if (!doc.exists) {
        setState(() {
          ownerFirstName = _auth.currentUser?.displayName ?? '';
          ownerEmail = _auth.currentUser?.email ?? '';
          ownerLoading = false;
        });
        return;
      }
      final data = doc.data()!;
      ownerDocData = data;
      setState(() {
        ownerFirstName = (data['firstName'] ?? '').toString();
        ownerLastName = (data['lastName'] ?? '').toString();
        ownerAge = (data['age'] ?? '').toString();
        ownerGender = (data['gender'] ?? '').toString();
        ownerAddress = (data['address'] ?? '').toString();
        ownerEmail = (data['email'] ?? _auth.currentUser?.email ?? '').toString();
        ownerLoading = false;
      });
    } catch (e) {
      setState(() => ownerLoading = false);
      print('Error fetching owner profile: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    breedController.dispose();
    ageController.dispose();
    weightController.dispose();
    habitController.dispose();
    super.dispose();
  }

  void saveEdits() {
    setState(() {
      isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
    // Save to Firestore if needed
  }

  void onTabSelected(int idx) {
    setState(() => currentTab = idx);

    if (idx == 0) {
      Navigator.pop(context);
    } else if (idx == 1) {
      // Schedule tab - navigate to SchedulePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SchedulePage(
            petName: widget.petName,
            petBreed: widget.petBreed,
            petGender: widget.petGender,
            petAge: widget.petAge,
            petWeight: widget.petWeight,
            petHabit: widget.petHabit,
          ),
        ),
      );
    }
  }

  @override
/// Builds the main widget for the Pet Profile page.
///
/// This widget contains a dashboard at the top with three tabs.
/// The first tab navigates back to the Home page.
/// The second tab navigates to the Schedule page.
/// The third tab displays the Pet Profile card.
///
/// The Pet Profile card shows the pet's name, breed, age, weight, habit, and owner's profile.
/// The owner's profile is fetched from the Firestore database when the widget is initialized.
/// The profile shows the owner's first name, last name, age, gender, address, and email.
/// If the owner's profile does not exist in the database, the profile card will not be shown.
/// The owner's profile card also shows debug information such as the owner's UID and whether the owner's profile exists in the database.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB3D3F9),
      body: Column(
        children: [
          _buildDashboardTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Pet's Profile",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF8D6748)),
                                ),
                                const SizedBox(height: 18),
                                _buildField('Pet\'s Name', nameController, enabled: isEditing),
                                _buildField('Pet\'s Breed', breedController, enabled: isEditing),
                                _buildField('Pet\'s Age', ageController, enabled: isEditing, keyboardType: TextInputType.number),
                                _buildField('Pet\'s Weight', weightController, enabled: isEditing, keyboardType: TextInputType.number),
                                _buildField('Pet\'s Habit', habitController, enabled: isEditing),
                                DropdownButtonFormField<String>(
                                  initialValue: gender,
                                  decoration: const InputDecoration(labelText: "Pet's Gender"),
                                  items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                  onChanged: isEditing ? (v) => setState(() => gender = v ?? '') : null,
                                  disabledHint: Text(gender),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (isEditing) {
                                        saveEdits();
                                      } else {
                                        setState(() => isEditing = true);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4B8DF8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: Text(
                                      isEditing ? 'Save Profile' : 'Edit Profile',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Owner Profile Card
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Owner Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8D6748))),
                                const SizedBox(height: 12),
                                if (ownerLoading)
                                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                                else ...[
                                  _buildInfoRow('First name', ownerFirstName),
                                  _buildInfoRow('Last name', ownerLastName),
                                  _buildInfoRow('Age', ownerAge),
                                  _buildInfoRow('Gender', ownerGender),
                                  _buildInfoRow('Address', ownerAddress),
                                  _buildInfoRow('Email', ownerEmail),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  // Debug info
                                  _buildInfoRow('UID', ownerUid ?? '-'),
                                  _buildInfoRow('Doc exists', ownerDocExists ? 'true' : 'false'),
                                  if (ownerDocData != null) ...[
                                    const SizedBox(height: 8),
                                    const Text('Doc keys/values:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    ...ownerDocData!.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical:4.0), child: Row(children: [SizedBox(width:110, child: Text('${e.key}:', style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('${e.value}'))]))).toList(),
                                  ],
                                ],
                              ],
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
        ],
      ),
    );
  }

  Widget _buildDashboardTabs() {
    return Container(
      color: const Color(0xFF8D6748),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _dashboardTab(icon: Icons.home, label: 'Home', idx: 0),
            _dashboardTab(icon: Icons.schedule, label: 'Schedule', idx: 1),
            _dashboardTab(icon: Icons.person, label: 'Profile', idx: 2),
          ],
        ),
      ),
    );
  }

  Widget _dashboardTab(
      {required IconData icon, required String label, required int idx}) {
    final bool selected = currentTab == idx;
    return GestureDetector(
      onTap: () => onTabSelected(idx),
      child: Container(
        color: Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.white70,
                size: 28),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool enabled = false,
      TextInputType keyboardType = TextInputType.text,
      void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        enabled: enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
      ),
    );
  }
}
