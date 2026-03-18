import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../i18n/app_copy.dart';

class AppShell extends StatefulComponent {
  const AppShell({required this.child, super.key});

  final Component child;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  bool _isCollapsed = false;

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Component build(BuildContext context) {
    final location = RouteState.of(context).location;
    final t = AppCopy.current;

    // Background color: Geek Black (#0a0a0a) / Off-white (#faf9f6)
    return div(
      classes:
          'relative flex min-h-screen bg-[#faf9f6] text-slate-800 transition-colors duration-200 dark:bg-[#0a0a0a] dark:text-slate-200 font-sans',
      [
        _buildSidebar(location, t),
        // Main Content
        div(classes: 'flex-1 min-w-0 flex flex-col h-screen overflow-hidden relative', [
          div(classes: 'flex-1 min-w-0 p-4 lg:p-8 overflow-y-auto', [
            div(classes: 'w-full max-w-[1400px] mx-auto', [
              component.child,
            ]),
          ]),
        ]),
      ],
    );
  }

  Component _buildSidebar(String location, AppCopy t) {
    return div(
      classes:
          'shrink-0 transition-all duration-300 border-r border-slate-200/60 bg-[#fcfbf9] dark:border-slate-800/60 dark:bg-[#121212] flex flex-col ${_isCollapsed ? 'w-[#5rem]' : 'w-64'}',
      [
        // Header
        div(
          classes:
              'h-[72px] flex items-center ${_isCollapsed ? 'justify-center' : 'justify-between px-6'} border-b border-transparent bg-transparent',
          [
             div(classes: 'flex items-center gap-3', [
               div(
                 classes:
                     'inline-flex h-[38px] w-[38px] items-center justify-center rounded-[12px] bg-slate-900 text-sm font-bold uppercase tracking-widest text-white shadow-sm dark:bg-white dark:text-slate-950',
                 [.text('EG')],
               ),
               if (!_isCollapsed)
                 span(
                   classes:
                       'font-bold text-[15px] tracking-[0.15em] uppercase text-slate-800 dark:text-slate-100',
                   [.text(t.brandLabel)],
                 ),
             ]),
          ],
        ),
        // Nav Links
        div(classes: 'flex-1 overflow-y-auto py-5 flex flex-col gap-2 px-4', [
          _navItem(location, '/', t.navHome, _iconHome()),
          _navItem(location, '/dashboard', t.navDashboard, _iconDashboard()),
        ]),
        // Collapse Button
        div(classes: 'p-4', [
          button(
            classes:
                'w-full flex items-center ${_isCollapsed ? 'justify-center' : 'justify-start px-4'} h-11 rounded-[12px] hover:bg-slate-200/50 dark:hover:bg-slate-800/50 text-slate-500 transition-colors',
            onClick: _toggleSidebar,
            [
              _isCollapsed ? _iconExpand() : _iconCollapse(),
              if (!_isCollapsed)
                span(classes: 'ml-3 text-[14px] font-medium', [.text('折叠面板')]),
            ],
          ),
        ]),
      ],
    );
  }

  Component _navItem(String location, String path, String label, String svgPath) {
    final selected = path == '/' ? location == path : location.startsWith(path);
    final linkClass = selected
        ? 'flex items-center rounded-[12px] bg-indigo-600/10 text-indigo-700 font-semibold dark:bg-teal-400/10 dark:text-teal-300'
        : 'flex items-center rounded-[12px] text-slate-500 hover:bg-slate-200/50 hover:text-slate-800 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white transition-colors';

    return Link(
      to: path,
      child: div(
          classes: '$linkClass ${_isCollapsed ? 'justify-center h-11 w-11 mx-auto' : 'px-4 h-11 w-full'}',
          [
            _rawSvg(svgPath),
            if (!_isCollapsed)
              span(classes: 'ml-3 text-[14px]', [.text(label)]),
          ],
      ),
    );
  }

  Component _rawSvg(String pathData) {
    return raw('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$pathData</svg>');
  }

  String _iconHome() => '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>';
  String _iconDashboard() => '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>';
  Component _iconCollapse() {
    return _rawSvg('<path d="m15 18-6-6 6-6"/>');
  }
  Component _iconExpand() {
    return _rawSvg('<path d="m9 18 6-6-6-6"/>');
  }
}
