import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Not assessed';

  Future<void> runAssessment() async {
    try {
      final assessment = await DeviceSecurityGuard.assess();
      final decision = Circular77Policy.evaluate(assessment);
      if (!mounted) return;
      setState(() => _status = decision.action.name);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Assessment failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Device Security Guard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: runAssessment,
                child: const Text('Run assessment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
