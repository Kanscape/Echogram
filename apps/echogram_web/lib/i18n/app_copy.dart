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
  String get navDashboard => isZh ? 'Dashboard' : 'Dashboard';
  String get navTelegramHint => isZh ? 'Telegram 保留会话内快捷操作' : 'Telegram keeps quick in-chat actions';
  String get shellDescription =>
      isZh ? '面向 Prompt、RAG、日志与运维的本地优先控制台。' : 'Local-first control surface for prompts, RAG, logs, and operations.';
  String get autoLanguageBadge => isZh ? '自动：中文' : 'Auto: English';

  String get homeHeroTitle => isZh
      ? '一个以 Telegram 为入口、以浏览器为控制面的本地优先 Bot 工作台。'
      : 'A Telegram-native bot stack with a browser-grade control surface.';
  String get homeHeroBody => isZh
      ? 'Echogram 把快操作保留在 Telegram 里，把更重的检查、诊断与运维搬到本地浏览器面板。'
      : 'Echogram keeps fast actions inside Telegram, then moves visibility, diagnostics, and heavier operations into a local browser dashboard.';
  String get openDashboard => isZh ? '打开 Dashboard' : 'Open Dashboard';
  String get localApiBridge => isZh ? 'Python 与 Dart 之间的本地 API 边界' : 'Local API bridge between Python and Dart';

  String get dashboardCtaEyebrow => isZh ? '下一步' : 'Next step';
  String get dashboardCtaTitle => isZh ? '真正的工作台在 Dashboard。' : 'The real operating surface lives in Dashboard.';
  String get dashboardCtaBody => isZh
      ? '首页负责传达 Echogram 的边界与架构；日志、Prompt 检查、RAG 审计和配置操作都应该进入独立的 Dashboard 页面。'
      : 'Home introduces the product boundary. Logs, prompt inspection, RAG audits, and configuration belong in a dedicated dashboard.';
  String get dashboardCtaPrimary => isZh ? '进入 Dashboard' : 'Open Dashboard';
  String get dashboardCtaSecondary =>
      isZh ? '即使后端还没连上，也会先渲染完整界面骨架' : 'The dashboard skeleton renders before the backend connects';

  String get operatingModel => isZh ? '运行结构' : 'Operating model';
  String get threeLayersTitle => isZh ? '三层结构，一条控制链。' : 'Three layers, one control loop.';

  String get stackTelegramTitle => 'Telegram';
  String get stackTelegramBody =>
      isZh ? '保留 edit、preview 一类贴近对话的即时操作。' : 'Keeps fast, conversational actions like edit and preview.';
  String get stackTelegramFooter => isZh ? '快操作留在消息发生的地方。' : 'Keep fast actions where the messages already live.';

  String get stackBackendTitle => isZh ? '本地 Python 后端' : 'Local Python backend';
  String get stackBackendBody =>
      isZh ? '负责持久化、RAG、日志、定时任务与 Telegram 编排。' : 'Owns persistence, RAG, logs, schedulers, and Telegram orchestration.';
  String get stackBackendFooter => isZh ? '这里仍然是系统真相来源。' : 'This stays the source of truth.';

  String get stackWebTitle => 'Echogram Web';
  String get stackWebBody =>
      isZh ? '负责可视化、诊断、审计与更重的配置流程。' : 'Handles visibility, diagnostics, audits, and heavier configuration flows.';
  String get stackWebFooter => isZh ? '这是未来可以继续扩展的浏览器层。' : 'This is the browser layer users can grow with.';

  String get reasonTelegramSharpTitle => isZh ? 'Telegram 保持锋利' : 'Telegram stays sharp';
  String get reasonTelegramSharpBody => isZh
      ? '短、快、贴近上下文的操作继续留在会话里，速度最快，也最自然。'
      : 'Short, contextual actions stay in the conversation where they are fastest and most natural.';

  String get reasonBrowserHeavyTitle => isZh ? '浏览器承接重操作' : 'Browser takes the heavy load';
  String get reasonBrowserHeavyBody => isZh
      ? 'Prompt 检查、日志、RAG 审计和订阅健康度更适合放在多面板、可滚动、可比较的桌面界面里。'
      : 'Prompt inspection, logs, RAG audits, and subscription health fit better in a richer desktop browser surface.';

  String get reasonSharedCoreTitle => isZh ? '一套 Dart Core，多种前端' : 'One Dart core, many surfaces';
  String get reasonSharedCoreBody => isZh
      ? 'Jaspr 现在复用它，未来 Flutter 也可以直接复用同一套数据契约与共享逻辑。'
      : 'Jaspr uses the shared Dart core today, and Flutter can reuse the same contracts later.';

  String get splitEyebrow => isZh ? '职责边界' : 'Surface split';
  String get splitTitle =>
      isZh ? '哪些操作留在 Telegram，哪些进入 Dashboard。' : 'What stays in Telegram versus what moves into the dashboard.';
  String get keepInTelegram => isZh ? '保留在 Telegram' : 'Keep in Telegram';
  String get moveIntoDashboard => isZh ? '进入 Dashboard' : 'Move into Dashboard';

  List<String> get telegramItems => isZh
      ? const [
          '/edit 与 /preview',
          '消息级修正和快速删除',
          '贴着会话流的即时反馈与控制',
        ]
      : const [
          '/edit and /preview',
          'Fast message-level fixes and deletes',
          'Immediate controls that live inside the chat flow',
        ];

  List<String> get dashboardItems => isZh
      ? const [
          'Prompt 组合与记忆可视化',
          'RAG 审计与重建操作',
          '日志、配置与运行健康度',
        ]
      : const [
          'Prompt composition and memory visibility',
          'RAG audits and rebuild actions',
          'Logs, configuration, and runtime health',
        ];

  String get architectureEyebrow => isZh ? '长期架构' : 'Long-term architecture';
  String get architectureTitle => isZh ? '为什么 Jaspr + Flutter 是更长线的选择。' : 'Why Jaspr + Flutter is the right long game.';
  String get architectureFlowEyebrow => isZh ? '架构流' : 'Architecture flow';
  String get architectureFlowTitle =>
      isZh ? '从 Telegram Bot 到独立客户端的演进路径。' : 'The path from Telegram bot to standalone client.';

  String get flowTelegramNodeTitle => isZh ? 'Telegram 会话面' : 'Telegram session surface';
  String get flowTelegramNodeBody =>
      isZh ? '保留 edit、preview 等贴近对话流的快捷操作。' : 'Keeps edit, preview, and other chat-native shortcuts.';
  String get flowBackendNodeTitle => isZh ? 'Python 核心后端' : 'Python core backend';
  String get flowBackendNodeBody =>
      isZh ? '统一负责持久化、RAG、日志、调度与 Telegram 编排。' : 'Owns persistence, RAG, logs, schedulers, and Telegram orchestration.';
  String get flowWebNodeTitle => 'Echogram Web';
  String get flowWebNodeBody =>
      isZh ? '浏览器控制台，承接诊断、可视化与重操作。' : 'Browser control surface for diagnostics, visibility, and heavier operations.';
  String get flowFlutterNodeTitle => isZh ? '未来 Flutter 客户端' : 'Future Flutter client';
  String get flowFlutterNodeBody => isZh
      ? '当 Echogram 变成独立产品时，可以直接复用同一套 Dart Core。'
      : 'Reuses the same Dart core when Echogram grows into a standalone product.';
  String get flowCoreTitle => isZh ? '共享 Dart Core' : 'Shared Dart Core';
  String get flowCoreBody => isZh
      ? '模型、API 客户端与共享逻辑写一次，同时服务 Jaspr 与未来 Flutter。'
      : 'Models, API clients, and shared logic are written once for Jaspr now and Flutter later.';

  List<String> get architectureSteps => isZh
      ? const [
          'Pure Dart Core 负责统一的数据契约与共享逻辑。',
          'Jaspr 输出真实 HTML/CSS，很适合桌面浏览器运维界面。',
          '未来 Flutter 可以直接复用同一套数据模型与 API 客户端。',
          '本地 API 边界让 Python 与 UI 可以独立演进。',
        ]
      : const [
          'Pure Dart core holds typed API contracts and shared orchestration.',
          'Jaspr renders real HTML and CSS, which fits browser-native operational UIs.',
          'Flutter can later reuse the same models and API client without redoing contracts.',
          'The local API seam lets Python and the UI evolve independently.',
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
