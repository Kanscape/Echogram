import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../i18n/app_copy.dart';

class AppShell extends StatelessComponent {
  const AppShell({required this.child, super.key});

  final Component child;

  @override
  Component build(BuildContext context) {
    final location = RouteState.of(context).location;
    if (location.startsWith('/dashboard')) {
      return div(classes: 'dashboard-route-shell', [child]);
    }

    final t = AppCopy.current;

    return div(classes: 'relative min-h-screen overflow-x-clip text-slate-900 dark:text-slate-100', [
      div(classes: 'echo-backdrop pointer-events-none fixed inset-0 opacity-70', []),
      div(classes: 'relative mx-auto flex min-h-screen w-full max-w-[1500px] min-w-0 flex-col gap-6 px-4 py-6 lg:px-8', [
        div(classes: 'shell-glass overflow-hidden rounded-[2rem] px-6 py-5', [
          div(classes: 'flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between', [
            div(classes: 'flex min-w-0 items-center gap-4', [
              div(
                classes:
                    'inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-900 text-sm font-bold uppercase tracking-[0.24em] text-white shadow-lg dark:bg-white dark:text-slate-950',
                [
                  .text('EG'),
                ],
              ),
              div(classes: 'min-w-0 space-y-1', [
                div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
                  .text(t.brandLabel),
                ]),
                p(classes: 'break-words text-sm text-slate-600 dark:text-slate-300', [
                  .text(t.shellDescription),
                ]),
              ]),
            ]),
            div(classes: 'flex w-full flex-wrap items-start gap-2 lg:w-auto lg:justify-end', [
              _navLink(location, '/', t.navHome),
              _navLink(location, '/dashboard', t.navDashboard),
              div(classes: 'shrink-0 rounded-full bg-teal-600 px-3 py-1 text-xs font-semibold text-white shadow-md', [
                .text(t.autoLanguageBadge),
              ]),
              div(
                classes:
                    'w-full max-w-full rounded-2xl bg-white/80 px-3 py-2 text-xs font-medium leading-5 text-slate-600 shadow-md dark:bg-slate-900/85 dark:text-slate-300 dark:shadow-none sm:w-auto sm:rounded-full sm:py-1',
                [
                  .text(t.navTelegramHint),
                ],
              ),
            ]),
          ]),
        ]),
        child,
      ]),
    ]);
  }

  Component _navLink(String location, String path, String label) {
    final selected = path == '/' ? location == path : location.startsWith(path);
    final classes = selected
        ? 'btn btn-sm border-0 bg-slate-900 text-white shadow-lg hover:bg-slate-800 dark:bg-teal-400 dark:text-slate-950 dark:hover:bg-teal-300'
        : 'btn btn-sm border-0 bg-white/80 text-slate-700 shadow-md hover:bg-white dark:bg-slate-900/85 dark:text-slate-200 dark:shadow-none dark:hover:bg-slate-800';

    return Link(
      to: path,
      child: span(classes: classes, [.text(label)]),
    );
  }
}
