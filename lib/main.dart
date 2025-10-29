import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Disupensa());
}

class Disupensa extends StatelessWidget {
  const Disupensa({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // background image (with opacity)
            Opacity(
              opacity: 0.5,
              child: Image.asset('assets/dogbg.jpg', fit: BoxFit.cover),
            ),

            // logo in the upper-left corner
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 60.0,
                    width: 60.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50.0),
                      child: Image.asset('assets/logo.jpg', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),

            // centered content (texts + textfield)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/disupensalogo.jpg',
                    height: 100,
                    width: 100,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Disupensa\n"
                    "Easy monitoring\nand maintaining\ngood eating habits\nof your pet dog",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Start Feeding button
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Builder(
                      builder: (innerContext) => ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(innerContext).showSnackBar(
                            const SnackBar(content: Text('Entering Login/Register Screen...')),
                          );
                          Navigator.push(
                            innerContext,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF987554),
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        child: const Text(
                          "Start Feeding",
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
