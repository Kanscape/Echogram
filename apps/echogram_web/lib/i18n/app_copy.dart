// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

enum AppLanguage {
  zh,
  en,
}

class AppCopy {
  AppCopy._(this.language);

  final AppLanguage language;

  static final AppCopy current = _resolve();

  bool get isZh => language == AppLanguage.zh;

  String get brandLabel => 'Echogram Web';
  String get navHome => isZh ? '首页' : 'Home';
  String get navDashboard => 'Dashboard';
  String get navTelegramHint => isZh ? 'Telegram 快捷操作' : 'Telegram actions';
  String get shellDescription =>
      isZh ? '支持日志管理与系统配置的 Bot 控制台。' : 'Observability and configuration dashboard for conversational bots.';
  String get autoLanguageBadge => isZh ? '语言：自动' : 'Language: Auto';

  String get homeHeroTitle => isZh
      ? '集成浏览器面板的本地优先 Telegram Bot'
      : 'A local-first Telegram bot with an integrated browser dashboard';
  String get homeHeroBody => isZh
      ? '基于 Telegram 提供消息交互功能，通过本地 Web 仪表盘提供详尽的系统日志采集、RAG 测试纠错及核心系统参数配置。'
      : 'Provides essential messaging in Telegram, while supporting system logs, RAG audits, and global configurations through a local dashboard.';
  String get openDashboard => isZh ? '打开 Dashboard' : 'Open Dashboard';
  String get localApiBridge => isZh ? '基于本地 API 通信' : 'Local API Bridge';

  String get dashboardCtaEyebrow => isZh ? '核心特性' : 'Core features';
  String get dashboardCtaTitle => isZh ? 'Dashboard 面板' : 'Dashboard Panel';
  String get dashboardCtaBody => isZh
      ? '提供独立的控制页面。支持查询服务异常报错日志、翻阅历史 Prompt 调用明细，以及调节系统长效运作所需的各类设定。'
      : 'Access independent controls. Supports querying error logs, tracing historical prompt structures, and tuning variables for extended operations.';
  String get dashboardCtaPrimary => isZh ? '进入 Dashboard' : 'Enter Dashboard';
  String get dashboardCtaSecondary =>
      isZh ? '支持离线场景下的 UI 骨架加载' : 'Supports fallback offline UI loading';

  String get operatingModel => isZh ? '系统架构' : 'System architecture';
  String get threeLayersTitle => isZh ? '三端分离设计' : 'Decoupled triple-layer design';

  String get stackTelegramTitle => 'Telegram';
  String get stackTelegramBody =>
      isZh ? '提供主会话流程交互及即时性轻量请求处理。' : 'Handles primary chat flows and immediate lightweight requests.';
  String get stackTelegramFooter => isZh ? '主要的会话视图' : 'Main session view';

  String get stackBackendTitle => 'Python 服务端';
  String get stackBackendBody =>
      isZh ? '实现数据持久化同步、文档检索生成引擎及后台计划任务管理。' : 'Implements persistence sync, retrieval engines, and task schedules.';
  String get stackBackendFooter => isZh ? '核心处理节点' : 'Core processing node';

  String get stackWebTitle => 'Web 控制台';
  String get stackWebBody =>
      isZh ? '适配桌面及移动端大尺寸视口，实现可视化图表及运行态调试。' : 'Adapts to larger viewports for data visualization and runtime debugging.';
  String get stackWebFooter => isZh ? '可视化面板' : 'Visual admin panel';

  String get reasonTelegramSharpTitle => isZh ? '即时短反馈流' : 'Immediate short feedbacks';
  String get reasonTelegramSharpBody => isZh
      ? '支持将动态评级修正和运行模式覆写指令嵌入会话上下文，降低交互损耗。'
      : 'Supports embedding dynamic ratings and modifications directly in context, reducing interaction costs.';

  String get reasonBrowserHeavyTitle => isZh ? '全场景大范围监控' : 'Full-scope observability';
  String get reasonBrowserHeavyBody => isZh
      ? '由于涉及多表联查与深层文本结构，建议在拥有充分横向屏幕空间的客户端上处理审查任务。'
      : 'Due to multi-table relations and deep text constraints, log audits are better served on wide desktop surfaces.';

  String get reasonSharedCoreTitle => isZh ? '跨端组件兼容' : 'Cross-platform compatibility';
  String get reasonSharedCoreBody => isZh
      ? '内部共享 Dart SDK 解析结构。允许当前 Web 服务与未来多平台客户端共享模型状态。'
      : 'Shares Dart SDK internals. Enables the web codebase and future mobile apps to share data models safely.';

  String get splitEyebrow => isZh ? '功能流向' : 'Feature flow';
  String get splitTitle =>
      isZh ? '操作层级边界说明' : 'Operation boundary specifications';
  String get keepInTelegram => isZh ? 'Telegram 端控制' : 'Telegram scopes';
  String get moveIntoDashboard => isZh ? 'Dashboard 端管理' : 'Dashboard scopes';

  List<String> get telegramItems => isZh
      ? const [
          '行内短指令解析 (/edit, /preview)',
          '基于触发器的动作执行',
          '当前节点预设参数覆写',
        ]
      : const [
          'Inline short commands (/edit, /preview)',
          'Trigger-based executions',
          'Current node parameter overrides',
        ];

  List<String> get dashboardItems => isZh
      ? const [
          'Prompt 构成明细及回放校验',
          'RAG 内部索引与召回结果审计',
          '全局配置修改与异常情况排查',
        ]
      : const [
          'Prompt composition and replay checks',
          'RAG index and retrieval audits',
          'Global config tuning and anomaly checks',
        ];

  String get architectureEyebrow => isZh ? '代码结构' : 'Repository structure';
  String get architectureTitle => isZh ? '模块化解耦模式' : 'Modular decoupling patterns';
  String get architectureFlowEyebrow => isZh ? '运行拓扑' : 'Runtime topology';
  String get architectureFlowTitle =>
      isZh ? '多节点功能拆解' : 'Multi-node feature isolation';

  String get flowTelegramNodeTitle => 'Telegram UI';
  String get flowTelegramNodeBody =>
      isZh ? '即时消息通道前端' : 'Instant message frontend channel';
  String get flowBackendNodeTitle => 'Python 执行后台';
  String get flowBackendNodeBody =>
      isZh ? '应用引擎与数据库宿主' : 'Engine core and database host';
  String get flowWebNodeTitle => 'Web 控制应用';
  String get flowWebNodeBody =>
      isZh ? '运行态状态观测工具' : 'Runtime observability tooling';
  String get flowFlutterNodeTitle => '支持前端拓展';
  String get flowFlutterNodeBody => isZh
      ? '提供多端部署一致性可能' : 'Provides options for platform parity';
  String get flowCoreTitle => '公共 Dart SDK';
  String get flowCoreBody => isZh
      ? '通信解析格式及类型系统' : 'API parsing formats and type bounds';

  List<String> get architectureSteps => isZh
      ? const [
          '提取基础网络处理及请求反推导为独立的 Core 服务，减少跨项目重复实现损耗。',
          '渲染中心目前基于 Jaspr 构建，生成对搜索引擎与爬虫友好的语义化静态树。',
          '如果开启移动端需求分流，现有处理逻辑层无需改动即可在 Flutter 中直接编译。',
          '前后端分工明确，前端页面迭代速度完全脱离后端应用逻辑周期绑定。',
        ]
      : const [
          'Extracts fundamental networking and parsing into a standalone Core service to avoid rewrites.',
          'Renders UI heavily via Jaspr, yielding semantic static trees that are lightweight and standards-compliant.',
          'If mobile scaling starts, existing processing layers compile seamlessly on Flutter with no friction.',
          'Hard front/back separation prevents lifecycle blockages during frontend iterations.',
        ];

  String get nA => isZh ? '暂无' : 'n/a';
  String get apiLabel => 'API';
  String get routeLabel => isZh ? '路由' : 'Route';
  String get modeLabel => isZh ? '模式' : 'Mode';
  String get clientModeLabel => isZh ? '客户端' : 'Client';

  String get typeGroup => isZh ? '群组' : 'group';
  String get typePrivate => isZh ? '私聊' : 'private';
  String get subscriptionError => isZh ? '异常' : 'error';
  String get subscriptionNormal => isZh ? '正常' : 'normal';
  String get subscriptionUnknown => isZh ? '未知' : 'unknown';
  String get ragHead => isZh ? '主记录' : 'HEAD';
  String get ragTail => isZh ? '尾记录' : 'TAIL';
  String get ragSkipped => isZh ? '跳过' : 'SKIPPED';

  String localizedChatType(String raw) {
    if (raw == 'group') {
      return typeGroup;
    }
    if (raw == 'private') {
      return typePrivate;
    }
    return raw;
  }

  String localizedSubscriptionStatus(String raw) {
    switch (raw) {
      case 'error':
        return subscriptionError;
      case 'normal':
        return subscriptionNormal;
      default:
        return subscriptionUnknown;
    }
  }

  String localizedRagStatus(String raw) {
    switch (raw) {
      case 'HEAD':
        return ragHead;
      case 'TAIL':
        return ragTail;
      case 'SKIPPED':
        return ragSkipped;
      default:
        return raw;
    }
  }

  static AppCopy _resolve() {
    final queryLang = (Uri.base.queryParameters['lang'] ?? '').toLowerCase();
    if (queryLang.startsWith('zh')) {
      return AppCopy._(AppLanguage.zh);
    }
    if (queryLang.startsWith('en')) {
      return AppCopy._(AppLanguage.en);
    }

    final browserLanguages = <String>[];
    try {
      browserLanguages.addAll(List<String>.from(html.window.navigator.languages ?? const []));
    } catch (_) {}

    final fallback = html.window.navigator.language;
    if (fallback.isNotEmpty) {
      browserLanguages.add(fallback);
    }

    for (final language in browserLanguages) {
      if (language.toLowerCase().startsWith('zh')) {
        return AppCopy._(AppLanguage.zh);
      }
    }

    return AppCopy._(AppLanguage.en);
  }
}
