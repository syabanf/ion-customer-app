import 'package:flutter/material.dart';

import 'package:ion_customer_app/shared.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/portal_auth.dart';
import 'router.dart';

/// Root widget — wires the customer router into a MaterialApp.router.
/// PortalAuthApi + PortalAuthState are injected via constructor so
/// main.dart can bootstrap them on app start.
class IonCustomerApp extends StatefulWidget {
  const IonCustomerApp({super.key, required this.api, required this.authState});
  final PortalAuthApi api;
  final PortalAuthState authState;

  @override
  State<IonCustomerApp> createState() => _IonCustomerAppState();
}

class _IonCustomerAppState extends State<IonCustomerApp> {
  late final CustomerRouter _router =
      CustomerRouter(api: widget.api, authState: widget.authState);

  @override
  Widget build(BuildContext context) {
    // Wave 23 — wrap in ValueListenableBuilder so flipping themeMode
    // anywhere (e.g. profile toggle) instantly rebuilds the whole app.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp.router(
        title: 'ION Customer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: _router.router,
        // Wave 25 — wrap every route in IonOfflineBanner so the user
        // sees a thin pill at the top of the screen the moment
        // connectivity drops, instead of failing API calls silently.
        builder: (context, child) =>
            IonOfflineBanner.wrap(child ?? const SizedBox.shrink()),
      ),
    );
  }
}
