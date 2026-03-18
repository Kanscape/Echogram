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
  String get navTelegramHint => isZh ? 'Telegram 保留会话级快捷操作' : 'Telegram keeps quick in-chat actions';
  String get shellDescription =>
      isZh ? '面向 Prompt、RAG、日志与运维的本地优先控制台。' : 'Local-first control surface for prompts, RAG, logs, and operations.';
  String get autoLanguageBadge => isZh ? '自动：中文' : 'Auto: English';

  String get homeHeroTitle => isZh
      ? '一个以 Telegram 为原生入口、以浏览器为控制面的 Bot 框架。'
      : 'A Telegram-native bot framework with a browser-grade control surface.';
  String get homeHeroBody => isZh
      ? 'Echogram 将会话级快捷操作保留在 Telegram 中，同时把更重的查看、诊断与运维能力提升到本地 Web 面板。'
      : 'Echogram keeps conversation-native actions inside Telegram, then lifts operational depth into a local dashboard built for visibility, diagnostics, and future productization.';
  String get openDashboard => isZh ? '进入 Dashboard' : 'Open Dashboard';
  String get localApiBridge => isZh ? 'Python 与 Dart 之间的本地 API 桥' : 'Local API bridge between Python and Dart';
  String get dashboardCtaEyebrow => isZh ? '下一步' : 'Next step';
  String get dashboardCtaTitle => isZh ? '真正的操作面在 Dashboard。' : 'The real operating surface lives in Dashboard.';
  String get dashboardCtaBody => isZh
      ? '首页负责展示 Echogram 的气质、边界和架构，真正的日志、Prompt、RAG 与订阅状态都进入独立的 Dashboard 页面。'
      : 'Home is the face of Echogram. Logs, prompt inspection, RAG records, and subscription health all move into a dedicated Dashboard page.';
  String get dashboardCtaPrimary => isZh ? '现在打开 Dashboard' : 'Open Dashboard now';
  String get dashboardCtaSecondary =>
      isZh ? '即使后端未连接，也会先展示完整 UI' : 'Dashboard skeleton renders even before the backend connects';
  String get operatingModel => isZh ? '运行结构' : 'Operating model';
  String get threeLayersTitle => isZh ? '三层结构，一条控制链。' : 'Three layers, one control loop.';
  String get stackTelegramTitle => 'Telegram';
  String get stackTelegramBody =>
      isZh ? '快速的会话级快捷操作、直接编辑、贴近消息流的控制。' : 'Fast in-chat shortcuts, direct edits, conversation-native control.';
  String get stackTelegramFooter => isZh ? '快操作留在消息发生的地方。' : 'Keep fast actions where the messages already live.';
  String get stackBackendTitle => isZh ? '本地 Python 后端' : 'Local Python backend';
  String get stackBackendBody =>
      isZh ? '持久化、RAG、定时任务、日志与 Telegram 投递。' : 'Persistence, RAG, schedulers, logs, and Telegram delivery.';
  String get stackBackendFooter => isZh ? '这里仍然是系统真相来源。' : 'This stays the source of truth.';
  String get stackWebTitle => 'Echogram Web';
  String get stackWebBody => isZh
      ? 'Prompt 检查、运行面板、RAG 记录与运维视图。'
      : 'Prompt inspection, runtime panels, RAG records, and operational dashboards.';
  String get stackWebFooter => isZh ? '这是未来可以继续长大的浏览器层。' : 'This is the browser layer users can grow with.';
  String get reasonTelegramSharpTitle => isZh ? 'Telegram 保持轻快' : 'Telegram stays sharp';
  String get reasonTelegramSharpBody => isZh
      ? '像 /edit、/preview 这样的短操作继续留在 Telegram 内部，速度快，也最贴近对话上下文。'
      : 'Short, conversational operations like /edit and /preview stay inside Telegram where they are fastest and most natural.';
  String get reasonBrowserHeavyTitle => isZh ? '浏览器承担重操作' : 'Browser takes the heavy load';
  String get reasonBrowserHeavyBody => isZh
      ? 'Prompt、日志、RAG 审计和订阅健康度迁移到更适合观察和诊断的界面。'
      : 'Prompt inspection, logs, RAG audits, and subscription health move to a richer visual environment with tables, panes, and history context.';
  String get reasonSharedCoreTitle => isZh ? '一个 Dart Core，多种前端' : 'One Dart core, many surfaces';
  String get reasonSharedCoreBody => isZh
      ? 'Jaspr 现在复用它，未来 Flutter 也可以直接复用同一套类型和协议。'
      : 'Jaspr uses the shared Dart client today, and Flutter can reuse the same contracts later if Echogram grows into a standalone product.';
  String get splitEyebrow => isZh ? '边界拆分' : 'Surface split';
  String get splitTitle => isZh ? '哪些能力留在 Telegram，哪些迁到 Dashboard。' : 'What belongs in Telegram versus the dashboard.';
  String get keepInTelegram => isZh ? '保留在 Telegram' : 'Keep in Telegram';
  String get moveIntoDashboard => isZh ? '迁移到 Dashboard' : 'Move into Dashboard';
  List<String> get telegramItems => isZh
      ? const [
          '/edit 与 /preview',
          '删除或修正消息级别的快速操作',
          '直接嵌在会话流里的短反馈与控制',
        ]
      : const [
          '/edit and /preview',
          'Delete or fix fast message-level issues',
          'Short operational nudges embedded in the conversation',
        ];
  List<String> get dashboardItems => isZh
      ? const [
          'Prompt 组合与记忆可视化',
          'RAG 审计与重建操作',
          '日志、订阅与运行状态',
        ]
      : const [
          'Prompt composition and memory visibility',
          'RAG audits and rebuild actions',
          'Logs, subscriptions, and runtime health',
        ];
  String get architectureEyebrow => isZh ? '长期架构' : 'Long-term architecture';
  String get architectureTitle => isZh ? '为什么 Jaspr + Flutter 是更长线的选择。' : 'Why Jaspr + Flutter is the right long game.';
  String get architectureFlowEyebrow => isZh ? '架构流程图' : 'Architecture flow';
  String get architectureFlowTitle =>
      isZh ? '从 Telegram 到独立 App 的演进路径。' : 'The path from Telegram bot to standalone app.';
  String get flowTelegramNodeTitle => isZh ? 'Telegram 会话面' : 'Telegram session surface';
  String get flowTelegramNodeBody =>
      isZh ? '保留 edit、preview 等贴近对话流的快捷操作。' : 'Keeps edit, preview, and other chat-native shortcuts.';
  String get flowBackendNodeTitle => isZh ? 'Python 核心后端' : 'Python core backend';
  String get flowBackendNodeBody =>
      isZh ? '统一持久化、RAG、日志、定时任务与 Telegram 编排。' : 'Owns persistence, RAG, logs, schedulers, and Telegram orchestration.';
  String get flowWebNodeTitle => 'Echogram Web';
  String get flowWebNodeBody =>
      isZh ? '浏览器控制台，承接诊断、可视化和重操作。' : 'Browser control surface for diagnostics, visibility, and heavier operations.';
  String get flowFlutterNodeTitle => isZh ? '未来 Flutter Client' : 'Future Flutter client';
  String get flowFlutterNodeBody => isZh
      ? '当 Echogram 脱离 Telegram 独立发布时复用同一 Dart Core。'
      : 'Reuses the same Dart core when Echogram becomes a standalone product.';
  String get flowCoreTitle => isZh ? 'Shared Dart Core' : 'Shared Dart Core';
  String get flowCoreBody => isZh
      ? '模型、API 客户端与共享逻辑只写一次，同时服务 Jaspr 与未来 Flutter。'
      : 'Models, API clients, and shared logic are written once for Jaspr now and Flutter later.';
  List<String> get architectureSteps => isZh
      ? const [
          'Pure Dart core 负责统一 API 类型与共享逻辑。',
          'Jaspr 输出真实 HTML/CSS，天然适合 Web 运维面板。',
          '未来 Flutter 可以直接复用相同的 Dart Core 构建桌面或移动客户端。',
          '本地 API 边界让 Python 与 UI 可以独立演进。',
        ]
      : const [
          'Pure Dart core holds typed API contracts and shared orchestration.',
          'Jaspr renders real HTML and CSS, so Echogram Web feels native to browser tooling and operational UIs.',
          'Flutter can later reuse the same Dart core for desktop or mobile clients without redoing data contracts.',
          'The local API seam lets Python evolve independently while the UI becomes portable.',
        ];

  String get dashboardEyebrow => isZh ? 'Dashboard' : 'Dashboard';
  String get dashboardConnectedTitle => isZh ? '已连接到本地 Echogram API。' : 'Connected to the local Echogram API.';
  String get dashboardOfflineTitle =>
      isZh ? '即使后端未连接，Dashboard UI 也会先展示。' : 'Dashboard UI is ready before the backend connects.';
  String get dashboardConnectedBody => isZh
      ? 'Python 负责持久化、RAG、日志与 Telegram 编排。Echogram Web 只通过本地 HTTP API 拉取和触发能力。'
      : 'The Python bot owns persistence, RAG, logs, and Telegram orchestration. Echogram Web stays thin and typed, pulling everything through a local HTTP boundary.';
  String get dashboardOfflineBody => isZh
      ? '你现在看到的是完整 Dashboard 结构。等本地 API 可用后，所有数据区会原地完成加载。'
      : 'You can inspect the layout, navigation, and operations surface even while the backend is offline. When the local API becomes reachable, these panels hydrate in place.';
  String get stateConnected => isZh ? '已连接' : 'Connected';
  String get stateConnecting => isZh ? '连接中' : 'Connecting';
  String get stateOfflineUi => isZh ? '离线预览' : 'Offline UI';
  String get authAttached => isZh ? '已附带 Token' : 'Token attached';
  String get recentChatsMetric => isZh ? '最近会话' : 'Recent chats';
  String get recentChatsMetricHint => isZh ? '当前浏览器可见的活动会话' : 'Active conversations visible to the browser';
  String get subscriptionsMetric => isZh ? '订阅源' : 'Subscriptions';
  String subscriptionMetricHint(int errorCount) => isZh ? '$errorCount 个错误状态' : '$errorCount in error state';
  String get historyWindowMetric => isZh ? '历史窗口' : 'History window';
  String get historyWindowMetricHint =>
      isZh ? '与 Telegram 及未来 Flutter 客户端共享' : 'Shared with Telegram and future Flutter clients';
  String get chatsEyebrow => isZh ? '会话' : 'Chats';
  String get chatsTitle => isZh ? '选择一个会话进行检查。' : 'Pick a conversation to inspect.';
  String get chatsEmpty => isZh
      ? '当前还没有加载到任何会话。启动 Python bot，或把 ?api= 指向可访问的本地 API。'
      : 'No conversations are loaded yet. Start the Python bot or point ?api= to a reachable local API.';
  String messagesCount(int count) => isZh ? '消息 $count' : 'Messages $count';
  String get subscriptionsEyebrow => isZh ? '订阅' : 'Subscriptions';
  String get subscriptionsTitle => isZh ? '主动分发状态' : 'Agentic distribution status';
  String get subscriptionsEmpty =>
      isZh ? '连接成功后，订阅源健康度会显示在这里。' : 'Subscription health will appear here after the dashboard connects.';
  String targetsCount(int count) => isZh ? '目标 $count' : 'Targets $count';
  String errorsCount(int count) => isZh ? '错误 $count' : 'Errors $count';
  String get loadingEyebrow => isZh ? '加载中' : 'Loading';
  String get loadingFocusTitle => isZh ? '正在获取 Prompt、RAG 和摘要数据' : 'Fetching prompt preview, RAG records, and summary';
  String get loadingFocusBody => isZh ? '当前选中会话正在加载。' : 'The selected conversation is being hydrated.';
  String get focusEyebrow => isZh ? '主视图' : 'Focus';
  String get focusOnlineTitle => isZh ? '选择一个会话来查看重操作信息。' : 'Select a chat to inspect heavy operations.';
  String get focusOfflineTitle => isZh ? '离线时也保留完整 Dashboard 骨架。' : 'Dashboard skeleton stays visible while offline.';
  String get focusOnlineBody => isZh
      ? '这里会显示会话统计、Prompt 组合、RAG 记录和最近消息预览。'
      : 'You will see session stats, prompt composition, RAG records, and recent message previews here.';
  String get focusOfflineBody => isZh
      ? '等本地 API 可用后，这块区域会原地加载会话统计、Prompt 预览和 RAG 数据。'
      : 'Once the local API is reachable, this area will hydrate with chat stats, prompt previews, and RAG records.';
  String get selectedChatEyebrow => isZh ? '当前会话' : 'Selected chat';
  String get typeLabel => isZh ? '类型' : 'Type';
  String get timezoneLabel => isZh ? '时区' : 'Timezone';
  String get whitelistLabel => isZh ? '白名单' : 'Whitelist';
  String get whitelistEnabled => isZh ? '启用' : 'Enabled';
  String get whitelistDisabled => isZh ? '未启用' : 'No';
  String get activeTokensMetric => isZh ? '活跃 Tokens' : 'Active tokens';
  String get activeTokensHint => isZh ? '热上下文窗口' : 'Hot context window';
  String get bufferTokensMetric => isZh ? '缓冲 Tokens' : 'Buffer tokens';
  String get bufferTokensHint => isZh ? '等待进入摘要归档' : 'Awaiting summary rollover';
  String get ragIndexedMetric => isZh ? 'RAG 已索引' : 'RAG indexed';
  String ragIndexedHint(int pending) => isZh ? '$pending 个待处理' : '$pending pending';
  String get messagesMetric => isZh ? '消息总量' : 'Messages';
  String messagesMetricHint(int startId) => isZh ? '窗口起点 $startId' : 'Window starts at $startId';
  String get refreshAll => isZh ? '刷新全部' : 'Refresh all';
  String get rebuildRag => isZh ? '重建 RAG' : 'Rebuild RAG';
  String rebuildingRagNotice(int chatId) =>
      isZh ? '正在为会话 $chatId 重建 RAG 索引...' : 'Rebuilding the RAG index for chat $chatId...';
  String get rebuiltRagNotice => isZh ? '已发出 RAG 重建请求。' : 'RAG rebuild requested.';
  String get summaryEyebrow => isZh ? '摘要' : 'Summary';
  String get summaryTitle => isZh ? '归档记忆快照' : 'Archived memory snapshot';
  String get summaryEmpty => isZh ? '当前还没有归档摘要。' : 'No archived summary yet.';
  String lastSummarizedId(int id) => isZh ? '最后摘要 ID $id' : 'Last summarized id $id';
  String get recentMessagesEyebrow => isZh ? '最近消息' : 'Recent messages';
  String get recentMessagesTitle => isZh ? '活跃窗口消息' : 'Active window messages';
  String get promptEyebrow => isZh ? 'Prompt 预览' : 'Prompt preview';
  String get promptFallbackTitle => isZh ? 'Prompt 组合' : 'Prompt composition';
  String get systemProtocol => isZh ? '系统协议' : 'System protocol';
  String get dynamicMemory => isZh ? '动态记忆与上下文' : 'Dynamic memory and context';
  String get noPromptYet => isZh ? '当前还没有 Prompt 预览。' : 'No prompt preview yet.';
  String get noMemoryYet => isZh ? '当前还没有记忆上下文。' : 'No memory context yet.';
  String get ragEyebrow => 'RAG';
  String get ragTitle => isZh ? '已降噪并已索引的记录' : 'What has been denoised and indexed';
  String get ragEmpty => isZh ? '这个会话还没有 RAG 记录。' : 'No RAG records yet for this chat.';
  String get denoisedFact => isZh ? '降噪结果' : 'Denoised fact';
  String get sourcePreview => isZh ? '源消息原文' : 'Source content';
  String get emptyLabel => isZh ? '空' : '(empty)';
  String get messagesEmpty => isZh ? '这个会话当前没有可展示的消息记录。' : 'No messages are available for this chat yet.';
  String get messagesLoading => isZh ? '正在读取消息分页数据...' : 'Loading message records...';
  String get ragLoading => isZh ? '正在读取 RAG 分页数据...' : 'Loading RAG records...';
  String get rawDataNotice => isZh
      ? '这里展示数据库原始内容，不再做预览截断；记录过多时改用分页。'
      : 'These panels show raw database content without preview clipping. Large result sets are paginated instead.';
  String get logsEyebrow => isZh ? '日志' : 'Logs';
  String get logsTitle => isZh ? '运行日志应该属于 Dashboard 的一部分。' : 'Runtime visibility belongs inside the dashboard.';
  String get refreshLogs => isZh ? '刷新日志' : 'Refresh logs';
  String get logTailTruncated => isZh ? '已截断以保证浏览器流畅' : 'Truncated for browser speed';
  String get logsWaiting => isZh ? '正在等待后端日志接口...' : 'Waiting for the backend log endpoint...';
  String get logsUnavailable => isZh ? '还没有可显示的日志输出。' : 'No log output available yet.';
  String get logEmpty => isZh ? '日志文件为空。' : '(log file is empty)';
  String get nA => isZh ? '暂无' : 'n/a';
  String get botLabel => isZh ? '机器人' : 'Bot';
  String get apiLabel => 'API';
  String get routeLabel => isZh ? '路由' : 'Route';
  String get authLabel => isZh ? '认证' : 'Auth';
  String get pathLabel => isZh ? '路径' : 'Path';
  String get modeLabel => isZh ? '模式' : 'Mode';
  String get databaseModeLabel => isZh ? '数据库原文' : 'Database raw';
  String get clientModeLabel => isZh ? '客户端' : 'Client';
  String get pageLabel => isZh ? '分页' : 'Page';
  String pageRange(int start, int end, int total) => '$start-$end / $total';
  String get prevPage => isZh ? '上一页' : 'Prev';
  String get nextPage => isZh ? '下一页' : 'Next';
  String get stateLabel => isZh ? '状态' : 'State';
  String get typeGroup => isZh ? '群组' : 'group';
  String get typePrivate => isZh ? '私聊' : 'private';
  String get subscriptionError => isZh ? '错误' : 'error';
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
      final normalized = language.toLowerCase();
      if (normalized.startsWith('zh')) {
        return AppCopy._(AppLanguage.zh);
      }
    }

    return AppCopy._(AppLanguage.en);
  }
}
