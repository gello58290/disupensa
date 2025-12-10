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

  // Notifications
  List<Map<String, dynamic>> notifications = [
    {'id': 1, 'title': 'Feeding reminder', 'message': 'Time to feed your pet', 'timestamp': DateTime.now().subtract(const Duration(minutes: 15)), 'read': false, 'page': 'home'},
    {'id': 2, 'title': 'Schedule created', 'message': 'Your new feeding schedule is active', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)), 'read': true, 'page': 'schedule'},
    {'id': 3, 'title': 'Water refill', 'message': 'Remember to refill water bowl', 'timestamp': DateTime.now().subtract(const Duration(days: 1)), 'read': true, 'page': 'home'},
  ];

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
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildDashboardTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF8D6748), const Color(0xFFA0826D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pet Profile 🐾',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nameController.text.isNotEmpty ? nameController.text : 'Your Pet',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8D6748),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          "Pet Details",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8D6748)),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () => setState(() => isEditing = !isEditing),
                                      icon: Icon(
                                        isEditing ? Icons.check : Icons.edit,
                                        color: const Color(0xFF8D6748),
                                      ),
                                    ),
                                  ],
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
                        // Owner Profile Card
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8D6748),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Owner Profile 👤',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8D6748)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (ownerLoading)
                                  const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow('First Name', ownerFirstName),
                                      _buildInfoRow('Last Name', ownerLastName),
                                      _buildInfoRow('Age', ownerAge),
                                      _buildInfoRow('Gender', ownerGender),
                                      _buildInfoRow('Address', ownerAddress),
                                      _buildInfoRow('Email', ownerEmail),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dashboardTab(icon: Icons.home, label: 'Home', idx: 0),
                _dashboardTab(icon: Icons.schedule, label: 'Schedule', idx: 1),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  // Notification Bell
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'clear-all') {
                        setState(() {
                          notifications.clear();
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All notifications cleared")),
                        );
                      } else {
                        final notifId = int.tryParse(value);
                        if (notifId != null) {
                          setState(() {
                            final idx = notifications.indexWhere((n) => n['id'] == notifId);
                            if (idx >= 0) {
                              notifications[idx]['read'] = true;
                              final page = notifications[idx]['page'] as String?;
                              if (page == 'home') {
                                Navigator.of(context).pushNamed('/home');
                              } else if (page == 'schedule') {
                                Navigator.of(context).pushNamed('/schedule');
                              }
                            }
                          });
                        }
                      }
                    },
                    icon: Badge(
                      label: Text('${notifications.where((n) => !n['read']).length}'),
                      child: const Icon(Icons.notifications, color: Colors.white, size: 28),
                    ),
                    itemBuilder: (BuildContext context) {
                      if (notifications.isEmpty) {
                        return [
                          const PopupMenuItem(
                            enabled: false,
                            child: Text('No notifications'),
                          ),
                        ];
                      }
                      return [
                        ...notifications.map((notif) {
                          final isRead = notif['read'] as bool;
                          final title = notif['title'] as String;
                          final message = notif['message'] as String;
                          return PopupMenuItem(
                            value: notif['id'].toString(),
                            child: Container(
                              width: 280,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTime(notif['timestamp'] as DateTime),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'clear-all',
                          child: Text('Clear all', style: TextStyle(color: Colors.red)),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'profile') {
                        _navigateToProfile();
                      } else if (value == 'logout') {
                        _logout();
                      }
                    },
                    icon: const Icon(Icons.account_circle, color: Colors.white, size: 32),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Profile'),
                          ],
                        ),
                        onTap: () => _navigateToProfile(),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    final auth = FirebaseAuth.instance;
    auth.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToProfile() {
    // Already on profile, so show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Already viewing profile')),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
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
        decoration: InputDecoration(
  labelText: label,
  filled: true,
  fillColor: enabled ? Colors.white : const Color(0xFFF4EFE9),
  labelStyle: TextStyle(
    color: enabled ? Colors.black87 : Colors.brown.shade600,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
  ),
),
style: TextStyle(
  color: enabled ? Colors.black87 : Colors.brown.shade700,
),
enabled: enabled,
keyboardType: keyboardType,
onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
