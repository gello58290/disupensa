import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pet_profile.dart';
import 'schedule.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int currentTab = 0; // 0: Home, 1: Schedule, 2: Profile
  
  late String petName = '';
  late String petBreed = '';
  late String petGender = '';
  late String petAge = '';
  late String petWeight = '';
  late String petHabit = '';
  bool _dataFetched = false;
  double foodLevel = 0.7; // 70% default
  double waterLevel = 0.5; // 50% default
  int remainingFoodDispense = 0;
  int remainingWaterDispense = 0;
  final double foodDecrement = 0.15; // 15% per feed
  final double waterDecrement = 0.15; // 15% per dispense
  
  // Notifications
  List<Map<String, dynamic>> notifications = [
    {'id': 1, 'title': 'Feeding time', 'message': 'Food feeding scheduled at 8:00 AM', 'timestamp': DateTime.now().subtract(const Duration(minutes: 30)), 'read': false, 'page': 'home'},
    {'id': 2, 'title': 'Water low', 'message': 'Water level is below 25%', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)), 'read': false, 'page': 'home'},
    {'id': 3, 'title': 'Schedule reminder', 'message': 'You have 3 schedules for today', 'timestamp': DateTime.now().subtract(const Duration(hours: 5)), 'read': true, 'page': 'schedule'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchPetData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _fetchScheduleCounts();
    }
  }

  Future<void> _fetchPetData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final petsSnapshot = await _firestore
          .collection('user')
          .doc(uid)
          .collection('pets')
          .limit(1)
          .get();

      if (petsSnapshot.docs.isNotEmpty) {
        final petData = petsSnapshot.docs.first.data();
        setState(() {
          petName = petData['petName'] ?? '';
          petBreed = petData['petBreed'] ?? '';
          petGender = petData['petGender'] ?? '';
          petAge = (petData['petAge'] ?? 0).toString();
          petWeight = (petData['petWeight'] ?? 0.0).toString();
          petHabit = petData['petHabit'] ?? '';
          _dataFetched = true;
        });
        // Try to fetch container levels from a `status` doc (optional)
        final statusDoc = await _firestore.collection('user').doc(uid).collection('meta').doc('status').get();
        if (statusDoc.exists) {
          final data = statusDoc.data()!;
          setState(() {
            foodLevel = (data['foodLevel'] is num) ? (data['foodLevel'] as num).toDouble() : foodLevel;
            waterLevel = (data['waterLevel'] is num) ? (data['waterLevel'] as num).toDouble() : waterLevel;
          });
        }
        // Fetch remaining schedule counts (schedules not fed today)
        final schedulesSnapshot = await _firestore
            .collection('user')
            .doc(uid)
            .collection('schedules')
            .get();
        final schedules = schedulesSnapshot.docs.map((d) => d.data()).toList();
        final remainingFood = schedules.where((s) => (s['isFedToday'] ?? false) == false && (s.containsKey('type') ? s['type'] : 'Food') == 'Food').length;
        final remainingWater = schedules.where((s) => (s['isFedToday'] ?? false) == false && (s.containsKey('type') ? s['type'] : 'Food') == 'Water').length;
        setState(() {
          remainingFoodDispense = remainingFood;
          remainingWaterDispense = remainingWater;
        });
      }
    } catch (e) {
      print('Error fetching pet data: $e');
    }
  }

  Future<void> _updateStatusDoc(double newFood, double newWater) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('user').doc(uid).collection('meta').doc('status').set({
        'foodLevel': newFood,
        'waterLevel': newWater,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving status: $e');
    }
  }

  Future<void> _fetchScheduleCounts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final schedulesSnapshot = await _firestore
          .collection('user')
          .doc(uid)
          .collection('schedules')
          .get();
      final schedules = schedulesSnapshot.docs.map((d) => d.data()).toList();
      final remainingFood = schedules.where((s) => (s['isFedToday'] ?? false) == false && (s.containsKey('type') ? s['type'] : 'Food') == 'Food').length;
      final remainingWater = schedules.where((s) => (s['isFedToday'] ?? false) == false && (s.containsKey('type') ? s['type'] : 'Food') == 'Water').length;
      
      if (mounted) {
        setState(() {
          remainingFoodDispense = remainingFood;
          remainingWaterDispense = remainingWater;
        });
      }
    } catch (e) {
      print('Error fetching schedule counts: $e');
    }
  }

  Future<void> _confirmAndDispense(String type) async {
    if (!mounted) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final percent = (type == 'Food' ? (foodDecrement * 100).round() : (waterDecrement * 100).round());
        return AlertDialog(
          title: Text('Confirm $type Dispense'),
          content: Text('This will decrease $type level by $percent% and mark one scheduled $type feeding as fed (if any). Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        );
      },
    );

    if (!mounted || confirm != true) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Try to find first unfed schedule of this type
      final qs = await _firestore
          .collection('user')
          .doc(uid)
          .collection('schedules')
          .where('isFedToday', isEqualTo: false)
          .where('type', isEqualTo: type)
          .limit(1)
          .get();

      if (type == 'Food') {
        if (qs.docs.isNotEmpty) {
          await qs.docs.first.reference.update({'isFedToday': true});
          setState(() => remainingFoodDispense = (remainingFoodDispense - 1).clamp(0, 999));
        }
        setState(() => foodLevel = (foodLevel - foodDecrement).clamp(0.0, 1.0));
      } else {
        if (qs.docs.isNotEmpty) {
          await qs.docs.first.reference.update({'isFedToday': true});
          setState(() => remainingWaterDispense = (remainingWaterDispense - 1).clamp(0, 999));
        } else {
          // if no water schedule, just decrement water level
          setState(() => remainingWaterDispense = (remainingWaterDispense - 1).clamp(0, 999));
        }
        setState(() => waterLevel = (waterLevel - waterDecrement).clamp(0.0, 1.0));
      }

      await _updateStatusDoc(foodLevel, waterLevel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type dispensed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void onTabSelected(int idx) {
    setState(() => currentTab = idx);
    
    // Handle tab navigation
    if (idx == 1 && _dataFetched) {
      // Schedule tab - navigate to SchedulePage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SchedulePage(
            petName: petName,
            petBreed: petBreed,
            petGender: petGender,
            petAge: petAge,
            petWeight: petWeight,
            petHabit: petHabit,
          ),
        ),
      ).then((_) {
        setState(() => currentTab = 0); // Reset to Home tab after returning
        _fetchScheduleCounts(); // Refresh schedule counts when returning from Schedule page
      });
    }
  }

  void _navigateToProfile() {
    if (_dataFetched) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PetProfile(
            petName: petName,
            petBreed: petBreed,
            petGender: petGender,
            petAge: petAge,
            petWeight: petWeight,
            petHabit: petHabit,
          ),
        ),
      ).then((_) {
        setState(() => currentTab = 0); // Reset to Home tab after returning
      });
    }
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

  void logout() {
    _auth.signOut();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Pet Greeting Card
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF8D6748), const Color(0xFFA0826D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
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
                              Text(
                                'Welcome back! 👋',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Daily Feeding',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                petName.isNotEmpty ? 'for $petName' : 'for your pet',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Quick Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickActionButton(
                              icon: Icons.food_bank,
                              label: 'Food',
                              color: const Color(0xFFFF9800),
                              onPressed: () => _confirmAndDispense('Food'),
                            ),
                            _buildQuickActionButton(
                              icon: Icons.water_drop,
                              label: 'Water',
                              color: const Color(0xFF2196F3),
                              onPressed: () => _confirmAndDispense('Water'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Container Levels Card
                        _buildLevelCard(),
                        const SizedBox(height: 18),

                        // Feeding Statistics
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF8D6748).withOpacity(0.8), const Color(0xFFA0826D).withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.feed, color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Today\'s Schedule',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('Food Left', remainingFoodDispense.toString(), const Color(0xFFFF9800)),
                                  _buildStatItem('Water Left', remainingWaterDispense.toString(), const Color(0xFF2196F3)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Feed Now button (manual)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // show choices for manual dispense
                              final choice = await showModalBottomSheet<String?>(
                                context: context,
                                builder: (context) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.food_bank, color: Color(0xFFFF9800)),
                                        title: const Text('Feed Food'),
                                        onTap: () => Navigator.pop(context, 'food'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.water_drop, color: Color(0xFF2196F3)),
                                        title: const Text('Dispense Water'),
                                        onTap: () => Navigator.pop(context, 'water'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.close),
                                        title: const Text('Cancel'),
                                        onTap: () => Navigator.pop(context, null),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (!mounted) return;
                              if (choice == 'food') {
                                await _confirmAndDispense('Food');
                              } else if (choice == 'water') {
                                await _confirmAndDispense('Water');
                              }
                            },
                            icon: const Icon(Icons.pets, size: 20),
                            label: const Text(
                              'Quick Feed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8D6748),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

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

/*************  ✨ Windsurf Command ⭐  *************/
/// Builds the dashboard tabs, which include Home and Schedule tabs.
///
/// Also includes buttons for clearing all notifications and marking a notification as read.
///
/*******  966f307e-021f-4b71-9c1f-eaa0d7e4d313  *******/
 Widget _buildDashboardTabs() {
  return Container(
    color: const Color(0xFF8D6748),
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // LEFT TABS
          Row(
            children: [
              _dashboardTab(icon: Icons.home, label: 'Home', idx: 0),
              _dashboardTab(icon: Icons.schedule, label: 'Schedule', idx: 1),
            ],
          ),

          // RIGHT SIDE ICONS
          Row(
            children: [
              
              // 🔔 NOTIFICATION BUTTON
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
                    // Mark as read and navigate
                    final notifId = int.tryParse(value);
                    if (notifId != null) {
                      setState(() {
                        final idx = notifications.indexWhere((n) => n['id'] == notifId);
                        if (idx >= 0) {
                          notifications[idx]['read'] = true;
                          final page = notifications[idx]['page'] as String?;
                          if (page == 'schedule') {
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

              // 👤 PROFILE MENU
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'profile') {
                    _navigateToProfile();
                  } else if (value == 'logout') {
                    logout();
                  }
                },
                icon: const Icon(Icons.account_circle, color: Colors.white, size: 32),
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
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

              const SizedBox(width: 8),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.white70, size: 28),
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, color: Color(0xFF8D6748), size: 24),
              const SizedBox(width: 12),
              const Text('Container Levels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          // Food Level
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.food_bank, color: Color(0xFFFF9800), size: 20),
                      const SizedBox(width: 8),
                      const Text('Food', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text('${(foodLevel * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: foodLevel,
                  minHeight: 10,
                  color: const Color(0xFFFF9800),
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Water Level
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Color(0xFF2196F3), size: 20),
                      const SizedBox(width: 8),
                      const Text('Water', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text('${(waterLevel * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: waterLevel,
                  minHeight: 10,
                  color: const Color(0xFF2196F3),
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

