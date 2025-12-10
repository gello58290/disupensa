import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'homepage.dart';
import 'pet_profile.dart';

class SchedulePage extends StatefulWidget {
  final String petName;
  final String petBreed;
  final String petGender;
  final String petAge;
  final String petWeight;
  final String petHabit;

  const SchedulePage({
    super.key,
    required this.petName,
    required this.petBreed,
    required this.petGender,
    required this.petAge,
    required this.petWeight,
    required this.petHabit,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int currentTab = 1; // 0: Home, 1: Schedule, 2: Profile
  List<Map<String, dynamic>> schedules = [];
  bool isLoading = true;

  String scheduleType = 'Food';

  // Feeding History
  List<Map<String, dynamic>> feedingHistory = [];

  // Notifications
  List<Map<String, dynamic>> notifications = [
    {'id': 1, 'title': 'Feeding time', 'message': 'Food feeding scheduled at 8:00 AM', 'timestamp': DateTime.now().subtract(const Duration(minutes: 30)), 'read': false, 'page': 'home'},
    {'id': 2, 'title': 'Water low', 'message': 'Water level is below 25%', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)), 'read': false, 'page': 'home'},
    {'id': 3, 'title': 'Schedule reminder', 'message': 'You have 3 schedules for today', 'timestamp': DateTime.now().subtract(const Duration(hours: 5)), 'read': true, 'page': 'schedule'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
    _fetchFeedingHistory();
  }

  Future<void> _fetchSchedules() async {
  try {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final schedulesSnapshot = await _firestore
        .collection('user')
        .doc(uid)
        .collection('schedules')
        .orderBy('createdAt', descending: false)
        .get();

    if (!mounted) return; // <-- IMPORTANT FIX

    setState(() {
      schedules = schedulesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'mealName': data['mealName'] ?? '',
          'mealTime': data['mealTime'] ?? '',
          'isFedToday': data['isFedToday'] ?? false,
          'createdAt': data['createdAt'],
          'type': data['type'] ?? 'Food',
        };
      }).toList();
      isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;  // <-- prevent setState after dispose
    setState(() => isLoading = false);
  }
}

  Future<void> _fetchFeedingHistory() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final historySnapshot = await _firestore
          .collection('user')
          .doc(uid)
          .collection('feedingHistory')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (!mounted) return;

      setState(() {
        feedingHistory = historySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'mealName': data['mealName'] ?? '',
            'mealTime': data['mealTime'] ?? '',
            'type': data['type'] ?? 'Food',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
            'notes': data['notes'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching feeding history: $e');
    }
  }

  Future<void> _logFeedingHistory(Map<String, dynamic> schedule) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore
          .collection('user')
          .doc(uid)
          .collection('feedingHistory')
          .add({
        'mealName': schedule['mealName'],
        'mealTime': schedule['mealTime'],
        'type': schedule['type'],
        'timestamp': Timestamp.now(),
        'notes': 'Fed at ${DateTime.now().toString()}',
      });

      _fetchFeedingHistory();
    } catch (e) {
      print('Error logging feeding history: $e');
    }
  }

  // Opens a modal to create one or more schedules for a selected date.
  Future<void> _showAddScheduleModal() async {
    DateTime selectedDate = DateTime.now();
    int quantity = 1;
    List<TimeOfDay?> times = [TimeOfDay.now()];
    String localType = scheduleType;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          void pickDate() async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) {
              setModalState(() => selectedDate = picked);
            }
          }

          void pickTime(int index) async {
            final t = await showTimePicker(
              context: context,
              initialTime: times[index] ?? TimeOfDay.now(),
            );
            if (t != null) setModalState(() => times[index] = t);
          }

          void updateQuantity(String v) {
            final q = int.tryParse(v) ?? 0;
            if (q <= 0) return;
            setModalState(() {
              quantity = q;
              // Resize times list
              if (times.length < quantity) {
                times.addAll(List.generate(quantity - times.length, (_) => TimeOfDay.now()));
              } else if (times.length > quantity) {
                times = times.sublist(0, quantity);
              }
            });
          }

          return AlertDialog(
            title: const Text('Create Schedules'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date: ${selectedDate.toLocal().toIso8601String().split('T')[0]}'),
                      ),
                      TextButton(onPressed: pickDate, child: const Text('Pick')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Type:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: localType,
                        items: const [
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(value: 'Water', child: Text('Water')),
                        ],
                        onChanged: (v) => setModalState(() => localType = v ?? 'Food'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Quantity:'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '1'),
                          onChanged: updateQuantity,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Times:'),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(times.length, (i) {
                      final t = times[i];
                      final label = t == null ? 'Not set' : t.format(context);
                      return Row(
                        children: [
                          Expanded(child: Text('Meal ${i + 1}: $label')),
                          TextButton(onPressed: () => pickTime(i), child: const Text('Pick')),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Preview:'),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(times.length, (i) {
                      final t = times[i];
                      final timeLabel = t == null ? 'Not set' : t.format(context);
                      final dateLabel = selectedDate.toLocal().toIso8601String().split('T')[0];
                      return Text('Meal ${i + 1} — $dateLabel · $timeLabel');
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  // Validate
                  if (quantity <= 0 || times.any((t) => t == null)) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set quantity and all times')));
                    return;
                  }

                  final uid = _auth.currentUser?.uid;
                  if (uid == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not signed in')));
                    return;
                  }

                  try {
                    for (int i = 0; i < quantity; i++) {
                      final tod = times[i]!;
                      final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, tod.hour, tod.minute);
                      await _firestore.collection('user').doc(uid).collection('schedules').add({
                        'mealName': 'Meal ${i + 1}',
                        'mealTime': dt.toIso8601String(),
                        'type': localType,
                        'isFedToday': false,
                        'createdAt': Timestamp.now(),
                      });
                    }

                    scheduleType = localType; // persist selection
                    _fetchSchedules();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedules created')));
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _toggleFedToday(String scheduleId, bool currentValue) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // If marking as fed (changing from false to true), log to history
      if (!currentValue) {
        final schedule = schedules.firstWhere((s) => s['id'] == scheduleId);
        await _logFeedingHistory(schedule);
      }

      await _firestore
          .collection('user')
          .doc(uid)
          .collection('schedules')
          .doc(scheduleId)
          .update({'isFedToday': !currentValue});

      _fetchSchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showEditScheduleModal(Map<String, dynamic> schedule) async {
    String name = schedule['mealName'] ?? '';
    String type = schedule['type'] ?? 'Food';
    DateTime? dt;
    // Try parse existing mealTime
    try {
      final parsed = DateTime.tryParse(schedule['mealTime'] ?? '');
      if (parsed != null) dt = parsed;
    } catch (_) {}

    DateTime selectedDate = dt ?? DateTime.now();
    TimeOfDay selectedTime = dt != null ? TimeOfDay(hour: dt.hour, minute: dt.minute) : TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          void pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked != null) setModalState(() => selectedDate = picked);
          }

          void pickTime() async {
            final t = await showTimePicker(context: context, initialTime: selectedTime);
            if (t != null) setModalState(() => selectedTime = t);
          }

          return AlertDialog(
            title: const Text('Edit Schedule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: name),
                  decoration: const InputDecoration(labelText: 'Meal name'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${selectedDate.toLocal().toIso8601String().split('T')[0]}')),
                    TextButton(onPressed: pickDate, child: const Text('Pick')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Time: ${selectedTime.format(context)}')),
                    TextButton(onPressed: pickTime, child: const Text('Pick')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Type:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(value: type, items: const [
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(value: 'Water', child: Text('Water')),
                    ], onChanged: (v) => setModalState(() => type = v ?? 'Food')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                final uid = _auth.currentUser?.uid;
                if (uid == null) return;
                try {
                  final newDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  await _firestore.collection('user').doc(uid).collection('schedules').doc(schedule['id']).update({
                    'mealName': name,
                    'mealTime': newDt.toIso8601String(),
                    'type': type,
                  });
                  _fetchSchedules();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule updated')));
                  Navigator.of(context).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, child: const Text('Save')),
            ],
          );
        });
      }
    );
  }

  String _formatMealTime(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = months[parsed.month - 1];
    final d = parsed.day;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$m $d · $hh:$mm';
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatHistoryTime(DateTime timestamp) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = months[timestamp.month - 1];
    final d = timestamp.day;
    final y = timestamp.year;
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$m $d, $y · $hh:$mm';
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore
          .collection('user')
          .doc(uid)
          .collection('schedules')
          .doc(scheduleId)
          .delete();

      _fetchSchedules();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void onTabSelected(int idx) {
    setState(() => currentTab = idx);

    if (idx == 0) {
      // Home tab - navigate back to HomePage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (idx == 2) {
      // Profile tab - navigate to PetProfile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PetProfile(
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildDashboardTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                            'Schedule Management 📅',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Feeding for ${widget.petName}',
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
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Add New Schedule Row
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
                                    const Expanded(
                                      child: Text(
                                        'Create Schedule',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _showAddScheduleModal,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 76, 175, 80),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text('+ New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Meal Preparation', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (isLoading)
                                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                                else if (schedules.isEmpty)
                                  const Padding(padding: EdgeInsets.all(12.0), child: Text('No schedules yet. Add one to get started!', style: TextStyle(color: Colors.black54)))
                                else
                                  Column(
                                    children: schedules.map((schedule) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(schedule['mealName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(color: schedule['type'] == 'Food' ? const Color(0xFF8D6748) : const Color(0xFF4BA3E3), borderRadius: BorderRadius.circular(12)),
                                                          child: Text(schedule['type'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(_formatMealTime(schedule['mealTime'] ?? ''), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                  ],
                                                ),
                                              ),
                                              IconButton(onPressed: () => _toggleFedToday(schedule['id'], schedule['isFedToday']), icon: Icon(schedule['isFedToday'] ? Icons.check_circle : Icons.radio_button_unchecked, color: schedule['isFedToday'] ? Colors.green : Colors.grey, size: 22)),
                                              IconButton(onPressed: () => _showEditScheduleModal(schedule), icon: const Icon(Icons.edit, color: Colors.blue, size: 20)),
                                              IconButton(onPressed: () => _deleteSchedule(schedule['id']), icon: const Icon(Icons.delete, color: Colors.red, size: 20)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Feeding History Section
                    Text(
                      'Feeding History',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: feedingHistory.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No feeding history yet',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : Column(
                                    children: feedingHistory.map((record) {
                                      final timestamp = record['timestamp'] is Timestamp
                                          ? (record['timestamp'] as Timestamp).toDate()
                                          : DateTime.tryParse(record['timestamp'].toString()) ?? DateTime.now();
                                      final mealName = record['mealName'] as String;
                                      final type = record['type'] as String;
                                      final formattedTime = _formatHistoryTime(timestamp);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              mealName,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                                color: Colors.black87,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: type == 'Food' ? Colors.orange.shade100 : Colors.blue.shade100,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              type,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: type == 'Food' ? Colors.orange.shade900 : Colors.blue.shade900,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        formattedTime,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  type == 'Food' ? Icons.restaurant : Icons.local_drink,
                                                  color: type == 'Food' ? Colors.orange : Colors.blue,
                                                  size: 24,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Divider(height: 1),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    _auth.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PetProfile(
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

  @override
  void dispose() {
    super.dispose();
  }
}
