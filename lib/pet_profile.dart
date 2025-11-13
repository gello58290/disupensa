import 'package:flutter/material.dart';

class PetProfile extends StatefulWidget {
  final String petName;
  final String petBreed;
  final String petGender;
  final String petAge;
  final String petWeight;
  final String petHabit;

  const PetProfile({
    Key? key,
    required this.petName,
    required this.petBreed,
    required this.petGender,
    required this.petAge,
    required this.petWeight,
    required this.petHabit,
  }) : super(key: key);

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
  int currentTab = 2; // 0: Home, 1: Schedule, 2: Profile

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.petName);
    breedController = TextEditingController(text: widget.petBreed);
    ageController = TextEditingController(text: widget.petAge);
    weightController = TextEditingController(text: widget.petWeight);
    habitController = TextEditingController(text: widget.petHabit);
    gender = widget.petGender;
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
    // TODO: Implement actual navigation for Home and Schedule
  }

  @override
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
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Pet's Profile",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF8D6748)),
                        ),
                        const SizedBox(height: 24),
                        _buildField('Pet\'s Name', nameController, enabled: isEditing),
                        _buildField('Pet\'s Breed', breedController, enabled: isEditing),
                        _buildField('Pet\'s Age', ageController, enabled: isEditing, keyboardType: TextInputType.number),
                        _buildField('Pet\'s Weight', weightController, enabled: isEditing, keyboardType: TextInputType.number),
                        _buildField('Pet\'s Habit', habitController, enabled: isEditing),
                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(labelText: "Pet's Gender"),
                          items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: isEditing ? (v) => setState(() => gender = v ?? '') : null,
                          disabledHint: Text(gender),
                        ),
                        const SizedBox(height: 24),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              isEditing ? 'Save Profile' : 'Edit Profile',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _dashboardTab({required IconData icon, required String label, required int idx}) {
    final bool selected = currentTab == idx;
    return GestureDetector(
      onTap: () => onTabSelected(idx),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white70, size: 28),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool enabled = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        enabled: enabled,
        keyboardType: keyboardType,
      ),
    );
  }
}
