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
    } else if (idx == 2 && _dataFetched) {
      // Profile tab - navigate to PetProfile
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
      backgroundColor: const Color(0xFFB3D3F9),
      body: Column(
        children: [
          _buildDashboardTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth:400),
                  child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Daily Feeding",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF8D6748),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Icons row for Food and Water
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconAction(
                              icon: Icons.food_bank,
                              label: 'Food',
                              onPressed: () => _confirmAndDispense('Food'),
                            ),
                            _buildIconAction(
                              icon: Icons.water_drop,
                              label: 'Water',
                              onPressed: () => _confirmAndDispense('Water'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Levels display
                        _buildLevelCard(),

                        const SizedBox(height: 18),

                        // Feeding Log
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8D6748),
                            borderRadius: BorderRadius.circular(14),
                          ),
                              padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Feeding Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Remaining food dispense', style: TextStyle(color: Colors.white70)),
                                  Text('$remainingFoodDispense', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Remaining water dispense', style: TextStyle(color: Colors.white70)),
                                  Text('$remainingWaterDispense', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Feed Now button (manual)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              // show choices for manual dispense
                              final choice = await showModalBottomSheet<String?>(
                                context: context,
                                builder: (context) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.food_bank),
                                        title: const Text('Feed Food'),
                                        onTap: () => Navigator.pop(context, 'food'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.water_drop),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8D6748),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Feed now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE74C3C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Logout',
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

  Widget _buildIconAction({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
            style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF8D6748),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }

  Widget _buildLevelCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
                    padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Container Levels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.food_bank, color: Color(0xFF8D6748)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food — ${(foodLevel * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: foodLevel, minHeight: 8, color: const Color(0xFF8D6748), backgroundColor: Colors.grey[200]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF4BA3E3)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water — ${(waterLevel * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: waterLevel, minHeight: 8, color: const Color(0xFF4BA3E3), backgroundColor: Colors.grey[200]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
