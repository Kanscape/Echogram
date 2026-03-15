import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'components/app_shell.dart';
import 'pages/dashboard_page.dart';
import 'pages/home_page.dart';

// The main component of your application.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen', [
      Router(routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            Route(path: '/', title: 'Echogram Web', builder: (context, state) => const HomePage()),
            Route(path: '/dashboard', title: 'Dashboard', builder: (context, state) => const DashboardPage()),
          ],
        ),
      ]),
    ]);
  }
}
