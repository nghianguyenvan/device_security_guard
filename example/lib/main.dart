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
  String _status = 'Chưa kiểm tra';
  List<String> _details = const [];

  Future<void> runAssessment() async {
    try {
      final assessment = await DeviceSecurityGuard.assess();
      final decision = Circular77Policy.evaluate(assessment);
      if (!mounted) return;
      setState(() {
        _status = 'Khuyến nghị: ${decision.action.name}';
        _details = assessment.signals.values
            .map(
              (result) =>
                  '${result.signal.name}: ${result.status.name} '
                  '(${result.reasonCode})',
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Không thể hoàn tất kiểm tra';
        _details = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Device Security Guard')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: runAssessment,
              child: const Text('Kiểm tra thiết bị'),
            ),
            const SizedBox(height: 24),
            for (final detail in _details)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(detail),
              ),
          ],
        ),
      ),
    );
  }
}
