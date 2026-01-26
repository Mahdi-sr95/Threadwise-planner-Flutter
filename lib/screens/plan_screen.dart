import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/plan_provider.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planProv = context.watch<PlanProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Plan (${planProv.strategy.label})')),
      body: SafeArea(
        child: Center(
          child: planProv.loading
              ? const CircularProgressIndicator()
              : planProv.error != null
              ? Text(planProv.error!)
              : Text('Tasks in plan: ${planProv.tasks.length}'),
        ),
      ),
    );
  }
}
