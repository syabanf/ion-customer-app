import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

/// Post-auth landing page. Shows the session, roles, and permissions —
/// useful while we're still building feature surfaces, and as a sanity
/// check that the auth flow round-trips correctly end-to-end.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ION Core'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final s = state.session;
          if (s == null) {
            return const Center(child: Text('Not signed in'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome, ${s.user.fullName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: IonColors.ink,
                ),
              ),
              Text(s.user.email, style: const TextStyle(color: IonColors.inkMuted)),
              const SizedBox(height: 24),
              _Section(title: 'Roles', body: s.roles.join(', ')),
              const SizedBox(height: 16),
              const Text(
                'Permissions',
                style: TextStyle(fontWeight: FontWeight.w600, color: IonColors.inkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: s.permissions
                    .map(
                      (k) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: IonColors.ion50,
                          border: Border.all(color: IonColors.ion200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 11,
                            color: IonColors.ion700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: IonColors.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: IonColors.ink)),
      ],
    );
  }
}
