import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import 'subscription_screen.dart';
import '../services/cgm_integration_service.dart';

/// Ultra: link LibreView (email/password sheet).
class CgmSettingsScreen extends StatelessWidget {
  const CgmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        if (!sub.canAccessCGMIntegration) {
          return Scaffold(
            appBar: AppBar(title: const Text('CGM integrations')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'CGM account linking is included with Ultra.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: const Text('View plans'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          return const Scaffold(
            body: Center(child: Text('Sign in to manage CGM accounts.')),
          );
        }

        return _CgmSettingsBody(userId: uid);
      },
    );
  }
}

class _CgmSettingsBody extends StatelessWidget {
  const _CgmSettingsBody({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CGM integrations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Connect your FreeStyle Libre sensor for live glucose context in the Health Agent. '
            'LibreView uses a secure HTTPS sign-in.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          _LibreCard(userId: userId),
        ],
      ),
    );
  }
}

class _LibreCard extends StatelessWidget {
  const _LibreCard({required this.userId});

  final String userId;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LibreConnectSheet(userId: userId),
    );
  }

  Future<void> _disconnect() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('integrations')
        .doc('libreview')
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('integrations')
          .doc('libreview')
          .snapshots(),
      builder: (context, snap) {
        final connected =
            snap.hasData && snap.data != null && snap.data!.exists;
        final email = snap.data?.data()?['email'] as String?;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bloodtype_outlined,
                        color: Color(0xFF0EA5E9)),
                    const SizedBox(width: 8),
                    Text(
                      'FreeStyle Libre (LibreView)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    if (connected)
                      Text(
                        'Linked',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Password is kept only in memory for the sign-in request and is not stored.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _openSheet(context),
                      child: const Text('Sign in to LibreView'),
                    ),
                    if (connected) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          await _disconnect();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('LibreView unlinked.')),
                            );
                          }
                        },
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LibreConnectSheet extends StatefulWidget {
  const _LibreConnectSheet({required this.userId});

  final String userId;

  @override
  State<_LibreConnectSheet> createState() => _LibreConnectSheetState();
}

class _LibreConnectSheetState extends State<_LibreConnectSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter email and password.')),
        );
      }
      return;
    }

    _password.clear();
    setState(() => _busy = true);

    try {
      final ok = await CGMIntegrationService()
          .connectLibreViewAccount(widget.userId, email, password);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LibreView connected.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'LibreView sign-in failed. Check credentials or try again later.',
            ),
          ),
        );
      }
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: inset + 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LibreView',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Uses HTTPS (api.libreview.io) only. Password is cleared after this request.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
