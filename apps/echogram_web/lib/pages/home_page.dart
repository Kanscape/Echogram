import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../i18n/app_copy.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    final t = AppCopy.current;

    return div(classes: 'space-y-6', [
      div(classes: 'grid gap-4 xl:grid-cols-[1.15fr_0.85fr]', [
        _heroPanel(t),
        _stackPanel(t),
      ]),
      _ctaPanel(t),
      div(classes: 'grid gap-4 xl:grid-cols-3', [
        _reasonCard(
          t.reasonTelegramSharpTitle,
          t.reasonTelegramSharpBody,
        ),
        _reasonCard(
          t.reasonBrowserHeavyTitle,
          t.reasonBrowserHeavyBody,
        ),
        _reasonCard(
          t.reasonSharedCoreTitle,
          t.reasonSharedCoreBody,
        ),
      ]),
      div(classes: 'grid gap-4 xl:grid-cols-[0.95fr_1.05fr]', [
        _splitPanel(t),
        _architectureFlowPanel(t),
      ]),
      _architecturePanel(t),
    ]);
  }
}

Component _heroPanel(AppCopy t) {
  return div(classes: 'shell-glass rounded-[2rem] px-6 py-7 lg:px-8 lg:py-9', [
    div(
      classes:
          'inline-flex items-center gap-2 rounded-full bg-teal-600 px-3 py-1 text-xs font-bold uppercase tracking-[0.24em] text-white',
      [
        span([.text('Echogram')]),
        span(classes: 'opacity-70', [.text('x')]),
        span([.text('Web')]),
      ],
    ),
    h1(classes: 'mt-5 max-w-4xl text-4xl font-bold tracking-tight text-slate-900 dark:text-white lg:text-6xl', [
      .text(t.homeHeroTitle),
    ]),
    p(classes: 'mt-5 max-w-2xl text-base leading-8 text-slate-600 dark:text-slate-300', [
      .text(t.homeHeroBody),
    ]),
    div(classes: 'mt-6 flex flex-wrap gap-2', [
      _metaChip(t.routeLabel, '/dashboard'),
      _metaChip(t.apiLabel, '/api'),
      _metaChip(t.modeLabel, t.clientModeLabel),
    ]),
    div(classes: 'mt-7 flex flex-wrap items-center gap-3', [
      Link(
        to: '/dashboard',
        child: span(
          classes:
              'btn btn-lg min-w-[220px] border-0 bg-slate-900 text-white shadow-xl hover:bg-slate-800 dark:bg-teal-400 dark:text-slate-950 dark:hover:bg-teal-300',
          [
            .text(t.openDashboard),
          ],
        ),
      ),
      div(
        classes:
            'rounded-full bg-white/80 px-4 py-3 text-sm text-slate-600 shadow-md dark:bg-slate-900/80 dark:text-slate-300 dark:shadow-none',
        [
          .text(t.localApiBridge),
        ],
      ),
    ]),
    div(classes: 'mt-7 grid gap-3 md:grid-cols-3', [
      _heroSurfaceCard('01', t.stackTelegramTitle, t.stackTelegramFooter),
      _heroSurfaceCard('02', t.stackWebTitle, t.dashboardCtaSecondary),
      _heroSurfaceCard('03', 'Flutter', t.flowFlutterNodeBody),
    ]),
  ]);
}

Component _stackPanel(AppCopy t) {
  return div(classes: 'shell-glass rounded-[2rem] px-6 py-7 lg:px-8 lg:py-9', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
      .text(t.operatingModel),
    ]),
    h2(classes: 'mt-3 text-2xl font-bold tracking-tight text-slate-900 dark:text-white', [
      .text(t.threeLayersTitle),
    ]),
    div(classes: 'mt-6 space-y-4', [
      _stackCard(
        t.stackTelegramTitle,
        t.stackTelegramBody,
        t.stackTelegramFooter,
      ),
      _stackCard(
        t.stackBackendTitle,
        t.stackBackendBody,
        t.stackBackendFooter,
      ),
      _stackCard(
        t.stackWebTitle,
        t.stackWebBody,
        t.stackWebFooter,
      ),
    ]),
  ]);
}

Component _ctaPanel(AppCopy t) {
  return div(classes: 'shell-glass echo-cta-panel rounded-[2rem] px-6 py-7 lg:px-8 lg:py-8', [
    div(classes: 'relative z-10 grid gap-5 xl:grid-cols-[1.15fr_0.85fr] xl:items-end', [
      div(classes: 'max-w-3xl space-y-3', [
        div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
          .text(t.dashboardCtaEyebrow),
        ]),
        h2(classes: 'text-3xl font-bold tracking-tight text-slate-900 dark:text-white lg:text-4xl', [
          .text(t.dashboardCtaTitle),
        ]),
        p(classes: 'text-sm leading-8 text-slate-600 dark:text-slate-300 lg:text-base', [
          .text(t.dashboardCtaBody),
        ]),
      ]),
      div(
        classes:
            'rounded-[1.75rem] bg-slate-950/92 p-5 text-white shadow-2xl ring-1 ring-white/10 dark:bg-slate-100 dark:text-slate-950 dark:ring-slate-900/8',
        [
          div(classes: 'text-xs font-bold uppercase tracking-[0.22em] text-teal-300 dark:text-teal-600', [
            .text(t.navDashboard),
          ]),
          h3(classes: 'mt-3 text-2xl font-bold tracking-tight', [
            .text(t.dashboardCtaPrimary),
          ]),
          p(classes: 'mt-3 text-sm leading-7 text-slate-200/85 dark:text-slate-700', [
            .text(t.dashboardCtaSecondary),
          ]),
          div(classes: 'mt-4 flex flex-wrap gap-2', [
            _metaChip(t.routeLabel, '/dashboard'),
            _metaChip(t.apiLabel, '/api'),
          ]),
          div(classes: 'mt-5 flex flex-col gap-3 sm:flex-row', [
            Link(
              to: '/dashboard',
              child: span(
                classes:
                    'btn btn-lg border-0 bg-white text-slate-950 shadow-xl hover:bg-slate-100 dark:bg-slate-900 dark:text-white dark:hover:bg-slate-800',
                [
                  .text(t.dashboardCtaPrimary),
                ],
              ),
            ),
            Link(
              to: '/dashboard?api=http://127.0.0.1:8765/api',
              child: span(
                classes:
                    'btn btn-lg border border-white/18 bg-white/8 text-white hover:bg-white/14 dark:border-slate-300/30 dark:bg-slate-950/6 dark:text-slate-900 dark:hover:bg-slate-950/12',
                [
                  .text(t.openDashboard),
                ],
              ),
            ),
          ]),
        ],
      ),
    ]),
  ]);
}

Component _splitPanel(AppCopy t) {
  return div(classes: 'shell-glass rounded-[2rem] px-6 py-7 lg:px-8 lg:py-9', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
      .text(t.splitEyebrow),
    ]),
    h2(classes: 'mt-3 text-2xl font-bold tracking-tight text-slate-900 dark:text-white', [
      .text(t.splitTitle),
    ]),
    div(classes: 'mt-6 grid gap-4 md:grid-cols-2', [
      _splitCard(
        t.keepInTelegram,
        t.telegramItems,
      ),
      _splitCard(
        t.moveIntoDashboard,
        t.dashboardItems,
      ),
    ]),
  ]);
}

Component _architectureFlowPanel(AppCopy t) {
  return div(classes: 'shell-glass rounded-[2rem] px-6 py-7 lg:px-8 lg:py-9', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
      .text(t.architectureFlowEyebrow),
    ]),
    h2(classes: 'mt-3 text-2xl font-bold tracking-tight text-slate-900 dark:text-white', [
      .text(t.architectureFlowTitle),
    ]),
    p(classes: 'mt-4 max-w-3xl text-sm leading-7 text-slate-600 dark:text-slate-300', [
      .text(t.reasonSharedCoreBody),
    ]),
    div(classes: 'echo-flow-grid mt-6', [
      _flowNode('01', t.flowTelegramNodeTitle, t.flowTelegramNodeBody),
      _flowArrow(),
      _flowNode('02', t.flowBackendNodeTitle, t.flowBackendNodeBody),
      _flowArrow(),
      _flowNode('03', t.flowWebNodeTitle, t.flowWebNodeBody),
      _flowArrow(),
      _flowNode('04', t.flowFlutterNodeTitle, t.flowFlutterNodeBody),
    ]),
    div(classes: 'echo-core-strip mt-4 space-y-4', [
      div(classes: 'flex flex-wrap items-center justify-between gap-3', [
        div(classes: 'text-xs font-bold uppercase tracking-[0.2em] text-teal-700 dark:text-teal-300', [
          .text(t.flowCoreTitle),
        ]),
        div(classes: 'flex flex-wrap gap-2', [
          _metaChip('Telegram', 'Shortcuts'),
          _metaChip('Web', 'Heavy ops'),
          _metaChip('Flutter', 'Future client'),
        ]),
      ]),
      p(classes: 'text-sm leading-7 text-slate-700 dark:text-slate-300', [
        .text(t.flowCoreBody),
      ]),
    ]),
  ]);
}

Component _architecturePanel(AppCopy t) {
  return div(classes: 'shell-glass rounded-[2rem] px-6 py-7 lg:px-8 lg:py-9', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [
      .text(t.architectureEyebrow),
    ]),
    h2(classes: 'mt-3 text-2xl font-bold tracking-tight text-slate-900 dark:text-white', [
      .text(t.architectureTitle),
    ]),
    div(classes: 'mt-6 grid gap-4 xl:grid-cols-2', [
      for (var i = 0; i < t.architectureSteps.length; i++) _flowStep('${i + 1}', t.architectureSteps[i]),
    ]),
  ]);
}

Component _reasonCard(String title, String copy) {
  return div(classes: 'shell-glass rounded-[1.75rem] px-5 py-5', [
    h3(classes: 'text-lg font-bold text-slate-900 dark:text-white', [.text(title)]),
    p(classes: 'mt-3 text-sm leading-7 text-slate-600 dark:text-slate-300', [.text(copy)]),
  ]);
}

Component _stackCard(String title, String body, String footer) {
  return div(
    classes:
        'rounded-[1.75rem] border border-slate-200/70 bg-white/80 p-5 dark:border-slate-700/70 dark:bg-slate-900/75',
    [
      div(classes: 'text-xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400', [.text(title)]),
      p(classes: 'mt-2 text-sm leading-7 text-slate-700 dark:text-slate-200', [.text(body)]),
      p(classes: 'mt-3 text-xs font-medium text-teal-700 dark:text-teal-300', [.text(footer)]),
    ],
  );
}

Component _splitCard(String title, List<String> items) {
  return div(
    classes:
        'rounded-[1.75rem] border border-slate-200/70 bg-white/80 p-5 dark:border-slate-700/70 dark:bg-slate-900/75',
    [
      h3(classes: 'text-lg font-bold text-slate-900 dark:text-white', [.text(title)]),
      ul(classes: 'mt-3 space-y-3 text-sm leading-7 text-slate-600 dark:text-slate-300', [
        for (final item in items) li([.text(item)]),
      ]),
    ],
  );
}

Component _flowStep(String index, String text) {
  return div(
    classes:
        'rounded-[1.75rem] border border-slate-200/70 bg-white/80 p-5 dark:border-slate-700/70 dark:bg-slate-900/75',
    [
      div(classes: 'flex items-start gap-3', [
        div(
          classes:
              'flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-slate-900 text-xs font-bold text-white dark:bg-teal-400 dark:text-slate-950',
          [
            .text(index),
          ],
        ),
        p(classes: 'pt-0.5 text-sm leading-7 text-slate-600 dark:text-slate-300', [.text(text)]),
      ]),
    ],
  );
}

Component _flowNode(String index, String title, String body) {
  return div(classes: 'echo-flow-node', [
    div(classes: 'flex items-start justify-between gap-3', [
      div(classes: 'text-xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400', [.text(title)]),
      div(
        classes:
            'inline-flex h-7 w-7 items-center justify-center rounded-full bg-slate-900 text-[11px] font-bold text-white dark:bg-teal-400 dark:text-slate-950',
        [
          .text(index),
        ],
      ),
    ]),
    p(classes: 'mt-3 text-sm leading-7 text-slate-700 dark:text-slate-200', [.text(body)]),
  ]);
}

Component _flowArrow() {
  return div(classes: 'echo-flow-arrow', [
    span([.text('->')]),
  ]);
}

Component _metaChip(String label, String value) {
  return div(
    classes:
        'rounded-full border border-slate-200/70 bg-white/82 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm dark:border-slate-700/70 dark:bg-slate-900/80 dark:text-slate-300 dark:shadow-none',
    [
      .text('$label: $value'),
    ],
  );
}

Component _heroSurfaceCard(String index, String title, String copy) {
  return div(
    classes:
        'rounded-[1.5rem] border border-slate-200/70 bg-white/80 p-4 shadow-sm dark:border-slate-700/70 dark:bg-slate-900/75 dark:shadow-none',
    [
      div(classes: 'flex items-center justify-between gap-3', [
        div(classes: 'text-xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400', [
          .text(title),
        ]),
        div(
          classes:
              'inline-flex h-7 w-7 items-center justify-center rounded-full bg-slate-900 text-[11px] font-bold text-white dark:bg-teal-400 dark:text-slate-950',
          [
            .text(index),
          ],
        ),
      ]),
      p(classes: 'mt-3 text-sm leading-7 text-slate-700 dark:text-slate-200', [
        .text(copy),
      ]),
    ],
  );
}
