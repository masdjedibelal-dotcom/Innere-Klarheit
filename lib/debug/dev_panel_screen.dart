import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'smoke_test_runner.dart';

class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});

  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  late Future<List<SmokeTestResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<List<SmokeTestResult>> _run() async {
    final client = Supabase.instance.client;
    final runner = SmokeTestRunner(client: client);
    return runner.run();
  }

  void _refresh() {
    setState(() {
      _future = _run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabaseUrl = dotenv.get('SUPABASE_URL', fallback: 'MISSING');
    final anonKeyLength =
        dotenv.get('SUPABASE_ANON_KEY', fallback: '').length;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Panel'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'Environment',
            children: [
              _RowLabel(label: 'SUPABASE_URL', value: supabaseUrl),
              _RowLabel(label: 'Anon key length', value: '$anonKeyLength'),
            ],
          ),
          _Section(
            title: 'Auth',
            children: [
              _RowLabel(
                label: 'Session',
                value: session == null ? 'no' : 'yes',
              ),
              _RowLabel(label: 'User ID', value: userId ?? '—'),
            ],
          ),
          _Section(
            title: 'Smoke Tests',
            children: [
              FutureBuilder<List<SmokeTestResult>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorBox(
                        text: 'Smoke tests failed: ${snapshot.error}');
                  }
                  final results = snapshot.data ?? const [];
                  if (results.isEmpty) {
                    return const _EmptyBox(text: 'Keine Ergebnisse.');
                  }
                  return Column(
                    children: results.map(_SmokeRow.new).toList(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmokeRow extends StatelessWidget {
  const _SmokeRow(this.result);

  final SmokeTestResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.isSuccess) {
      return _ErrorBox(
        text: '${result.table}: ${result.error}',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result.table,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${result.count}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              result.firstTitle ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
      ),
    );
  }
}

