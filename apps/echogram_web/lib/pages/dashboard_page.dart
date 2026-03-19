// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:math' as math;

import 'package:echogram_core/echogram_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/lucide_icon.dart';
import '../i18n/app_copy.dart';

enum _DashboardSection {
  overview,
  configuration,
  logs,
}

enum _LogPane {
  conversations,
  rag,
  system,
}

enum _DashboardTheme {
  dark,
  light,
}

enum _SettingFieldKind {
  text,
  multiline,
  toggle,
}

class _SettingField {
  const _SettingField({
    required this.key,
    required this.label,
    required this.help,
    this.placeholder = '',
    this.kind = _SettingFieldKind.text,
    this.secret = false,
    this.rows = 6,
  });

  final String key;
  final String label;
  final String help;
  final String placeholder;
  final _SettingFieldKind kind;
  final bool secret;
  final int rows;
}

class _SettingGroup {
  const _SettingGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
  });

  final String id;
  final String title;
  final String description;
  final List<_SettingField> fields;
}

class DashboardPage extends StatefulComponent {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  static const int _messagesPageSize = 12;
  static const int _ragPageSize = 12;
  static const String _themeStorageKey = 'echogram.dashboard.theme';

  late final DashboardConnection _connection;
  late final DashboardApiClient _client;
  int? _requestedChatId;

  DashboardOverview? _overview;
  List<ChatSummary> _chats = const [];
  List<SubscriptionRecord> _subscriptions = const [];
  ChatDetail? _chatDetail;
  PromptPreview? _promptPreview;
  RecentMessagePage? _messagePage;
  RagRecordPage? _ragPage;
  LogSnapshot? _logs;

  Map<String, String> _settings = const {};
  Map<String, String> _draftSettings = const {};

  int? _selectedChatId;
  bool _loading = true;
  bool _loadingChat = false;
  bool _loadingMessages = false;
  bool _loadingRag = false;
  bool _loadingLogs = true;
  bool _loadingSettings = true;
  String? _error;
  String? _logsError;
  String? _settingsError;
  String? _notice;
  String? _savingGroupId;
  String _chatQuery = '';

  _DashboardSection _activeSection = _DashboardSection.overview;
  _LogPane _activeLogPane = _LogPane.conversations;
  _DashboardTheme _theme = _DashboardTheme.dark;
  bool _statusPopoverOpen = false;

  AppCopy get _t => AppCopy.current;

  String _tr(String zh, String en) => _t.isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    _connection = DashboardConnection.fromUri(Uri.base);
    _client = DashboardApiClient(connection: _connection);
    _requestedChatId = int.tryParse(Uri.base.queryParameters['chat'] ?? '');
    _restoreUiPreferences();
    _loadDashboard();
    _loadSettings();
    _loadLogs();
  }

  void _restoreUiPreferences() {
    try {
      final rawTheme = html.window.localStorage[_themeStorageKey];
      if (rawTheme == 'light') {
        _theme = _DashboardTheme.light;
      } else if (rawTheme == 'dark') {
        _theme = _DashboardTheme.dark;
      }
    } catch (_) {}
  }

  void _persistUiPreferences() {
    try {
      html.window.localStorage[_themeStorageKey] = _theme == _DashboardTheme.dark ? 'dark' : 'light';
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await Future.wait<dynamic>([
        _client.getOverview(),
        _client.getChats(),
        _client.getSubscriptions(),
      ]);

      final overview = payload[0] as DashboardOverview;
      final chats = payload[1] as List<ChatSummary>;
      final subscriptions = payload[2] as List<SubscriptionRecord>;
      final preferredChatId = _selectedChatId ?? _requestedChatId ?? (chats.isNotEmpty ? chats.first.chatId : null);

      setState(() {
        _overview = overview;
        _chats = chats;
        _subscriptions = subscriptions;
        _loading = false;
      });

      if (preferredChatId != null) {
        await _selectChat(preferredChatId, quiet: true);
      }
    } catch (error) {
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loadingSettings = true;
      _settingsError = null;
    });

    try {
      final settings = await _client.getSettings();
      setState(() {
        _settings = settings;
        _draftSettings = Map<String, String>.from(settings);
        _loadingSettings = false;
      });
    } catch (error) {
      setState(() {
        _settingsError = _friendlyError(error);
        _loadingSettings = false;
      });
    }
  }

  Future<void> _selectChat(int chatId, {bool quiet = false}) async {
    setState(() {
      _selectedChatId = chatId;
      _loadingChat = true;
      _chatDetail = null;
      _promptPreview = null;
      _messagePage = null;
      _ragPage = null;
      if (!quiet) {
        _notice = null;
      }
    });

    try {
      final payload = await Future.wait<dynamic>([
        _client.getChat(chatId),
        _client.getPromptPreview(chatId),
        _client.getRecentMessages(chatId, limit: _messagesPageSize),
        _client.getRagRecords(chatId, limit: _ragPageSize),
      ]);

      setState(() {
        _chatDetail = payload[0] as ChatDetail;
        _promptPreview = payload[1] as PromptPreview;
        _messagePage = payload[2] as RecentMessagePage;
        _ragPage = payload[3] as RagRecordPage;
        _loadingChat = false;
      });
    } catch (error) {
      setState(() {
        _error = _friendlyError(error);
        _loadingChat = false;
      });
    }
  }

  Future<void> _loadMessagePage(int offset) async {
    final chatId = _selectedChatId;
    if (chatId == null) {
      return;
    }

    setState(() {
      _loadingMessages = true;
    });

    try {
      final page = await _client.getRecentMessages(chatId, limit: _messagesPageSize, offset: offset);
      setState(() {
        _messagePage = page;
        _loadingMessages = false;
      });
    } catch (error) {
      setState(() {
        _error = _friendlyError(error);
        _loadingMessages = false;
      });
    }
  }

  Future<void> _loadRagPage(int offset) async {
    final chatId = _selectedChatId;
    if (chatId == null) {
      return;
    }

    setState(() {
      _loadingRag = true;
    });

    try {
      final page = await _client.getRagRecords(chatId, limit: _ragPageSize, offset: offset);
      setState(() {
        _ragPage = page;
        _loadingRag = false;
      });
    } catch (error) {
      setState(() {
        _error = _friendlyError(error);
        _loadingRag = false;
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });

    try {
      final logs = await _client.getLogs();
      setState(() {
        _logs = logs;
        _loadingLogs = false;
      });
    } catch (error) {
      setState(() {
        _logsError = _friendlyError(error);
        _loadingLogs = false;
      });
    }
  }

  Future<void> _rebuildRag() async {
    final chatId = _selectedChatId;
    if (chatId == null) {
      return;
    }

    setState(() {
      _notice = _tr('开始构建当前会话的 RAG 索引...', 'Initiating RAG index build for the current session...');
    });

    try {
      await _client.rebuildRag(chatId);
      await _selectChat(chatId, quiet: true);
      setState(() {
        _notice = _tr('RAG 构建任务已提交。', 'RAG build task submitted.');
      });
    } catch (error) {
      setState(() {
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _refreshActiveSurface() async {
    await _loadDashboard();
    if (_activeSection == _DashboardSection.configuration) {
      await _loadSettings();
    }
    if (_activeSection == _DashboardSection.logs && _activeLogPane == _LogPane.system) {
      await _loadLogs();
    }
  }

  void _toggleTheme() {
    setState(() {
      _theme = _theme == _DashboardTheme.dark ? _DashboardTheme.light : _DashboardTheme.dark;
      _statusPopoverOpen = false;
    });
    _persistUiPreferences();
  }

  void _toggleStatusPopover() {
    final compactLayout = html.window.matchMedia('(max-width: 1100px)').matches;
    if (!compactLayout) {
      return;
    }

    setState(() {
      _statusPopoverOpen = !_statusPopoverOpen;
    });
  }

  void _changeSection(_DashboardSection section) {
    setState(() {
      _activeSection = section;
      _statusPopoverOpen = false;
    });
    html.window.scrollTo(0, 0);
  }

  void _changeLogPane(_LogPane pane) {
    setState(() {
      _activeLogPane = pane;
    });
    if (pane == _LogPane.system) {
      _loadLogs();
    }
  }

  void _updateDraft(String key, String value) {
    setState(() {
      _draftSettings = Map<String, String>.from(_draftSettings)..[key] = value;
    });
  }

  void _resetGroup(_SettingGroup group) {
    final nextDraft = Map<String, String>.from(_draftSettings);
    for (final field in group.fields) {
      final currentValue = _settings[field.key];
      if (currentValue == null) {
        nextDraft.remove(field.key);
      } else {
        nextDraft[field.key] = currentValue;
      }
    }
    setState(() {
      _draftSettings = nextDraft;
    });
  }

  Future<void> _saveGroup(_SettingGroup group) async {
    final changes = _groupChanges(group);
    if (changes.isEmpty) {
      setState(() {
        _notice = _tr('当前配置组暂无未保存项。', 'No unsaved changes in the current group.');
      });
      return;
    }

    setState(() {
      _savingGroupId = group.id;
      _settingsError = null;
      _notice = null;
    });

    try {
      final updated = await _client.patchSettings(changes);
      final merged = Map<String, String>.from(_settings)..addAll(updated.isEmpty ? changes : updated);
      setState(() {
        _settings = merged;
        _draftSettings = Map<String, String>.from(merged);
        _savingGroupId = null;
        _notice = _tr('${group.title} 配置已保存。', '${group.title} configuration saved.');
      });
      await _loadDashboard();
    } catch (error) {
      setState(() {
        _settingsError = _friendlyError(error);
        _savingGroupId = null;
      });
    }
  }

  List<_SettingGroup> get _settingGroups {
    return [
      _SettingGroup(
        id: 'models',
        title: _tr('API 与模型', 'API and Models'),
        description: _tr(
          '配置上游推理端点与基础模型调用链路。',
          'Configure upstream inference endpoints and core model pipelines.',
        ),
        fields: [
          _SettingField(
            key: 'api_base_url',
            label: _tr('API Base URL', 'API Base URL'),
            help: _tr('推理服务端点地址。', 'Inference endpoint address.'),
            placeholder: 'https://api.openai.com/v1',
          ),
          _SettingField(
            key: 'api_key',
            label: _tr('API Key', 'API Key'),
            help: _tr('服务鉴权密钥。', 'Authentication key.'),
            placeholder: 'sk-...',
            secret: true,
          ),
          _SettingField(
            key: 'model_name',
            label: _tr('主模型', 'Main Model'),
            help: _tr('用于常规对话链路的模型。', 'Model used for regular conversations.'),
            placeholder: 'gpt-5.4',
          ),
          _SettingField(
            key: 'summary_model_name',
            label: _tr('摘要模型', 'Summary Model'),
            help: _tr('留空则默认沿用主模型。', 'Leave empty to fall back to the main model.'),
            placeholder: 'Leave empty to follow main model',
          ),
          _SettingField(
            key: 'vector_model_name',
            label: _tr('向量模型', 'Vector Model'),
            help: _tr('用于 Embeddings 生成与 RAG 检索模型。', 'Model for embeddings generation and RAG retrieval.'),
            placeholder: 'text-embedding-3-small',
          ),
          _SettingField(
            key: 'media_model',
            label: _tr('多模态模型', 'Multimodal Model'),
            help: _tr('负责视觉与语音等媒体文件处理链路。', 'Handles visual, audio, and multimedia processing pipelines.'),
            placeholder: 'gpt-4.1-mini',
          ),
        ],
      ),
      _SettingGroup(
        id: 'behavior',
        title: _tr('行为与上下文', 'Behavior & Context'),
        description: _tr(
          '调节生成参数与记忆范围控制。',
          'Adjust generation parameters and memory scope limits.',
        ),
        fields: [
          _SettingField(
            key: 'timezone',
            label: _tr('系统时区', 'System Timezone'),
            help: _tr('影响日志记录格式及基于时间的调度任务。', 'Affects log timestamp formatting and time-restricted tasks.'),
            placeholder: 'Asia/Hong_Kong',
          ),
          _SettingField(
            key: 'temperature',
            label: _tr('Temperature', 'Temperature'),
            help: _tr('控制文本生成随机性，数值越大随机性越强（0.0 - 1.0）。', 'Controls generation randomness (0.0 to 1.0).'),
            placeholder: '0.7',
          ),
          _SettingField(
            key: 'history_tokens',
            label: _tr('历史 Token 限制', 'History Token Limit'),
            help: _tr('热上下文中允许携带的历史记录最大阈值。', 'Maximum token allocation for hot context histories.'),
            placeholder: '4000',
          ),
          _SettingField(
            key: 'aggregation_latency',
            label: _tr('聚合延迟 (秒)', 'Aggregation Latency (s)'),
            help: _tr('上游消息聚合及防抖动触发等待时间。', 'Wait duration for debounce and upstream message aggregation.'),
            placeholder: '10.0',
          ),
          _SettingField(
            key: 'system_prompt',
            label: _tr('System Prompt', 'System Prompt'),
            help: _tr('用于框定生成内容的基础规则及响应模式预设。', 'Base rules and behavioral presets for generated content.'),
            kind: _SettingFieldKind.multiline,
            rows: 10,
          ),
        ],
      ),
      _SettingGroup(
        id: 'rag',
        title: _tr('RAG 配置', 'RAG Settings'),
        description: _tr(
          '设定索引同步间隔与检索宽容度。',
          'Set synchronization intervals and retrieval tolerances.',
        ),
        fields: [
          _SettingField(
            key: 'rag_sync_cooldown',
            label: _tr('全量同步间隔 (秒)', 'Sync Interval (s)'),
            help: _tr('后台构建 RAG 索引队列的最小触发频率。', 'Minimum trigger frequency for RAG background workers.'),
            placeholder: '180',
          ),
          _SettingField(
            key: 'rag_similarity_threshold',
            label: _tr('最小分数阈值', 'Minimum Similarity Score'),
            help: _tr('余弦相似度召回限制。', 'Baseline limitation for cosine similarity retrieval.'),
            placeholder: '0.6',
          ),
          _SettingField(
            key: 'rag_context_padding',
            label: _tr('段落扩展间距', 'Context Margin'),
            help: _tr('在源节点前后延伸加载的附加消息条数。', 'Number of surrounding messages attached to a target node.'),
            placeholder: '3',
          ),
        ],
      ),
      _SettingGroup(
        id: 'agentic',
        title: _tr('守护进程规则', 'Daemon Rules'),
        description: _tr(
          '设定后台闲时任务的活跃时段与唤醒判定条件。',
          'Configure active period rules and trigger parameters for idle polling tasks.',
        ),
        fields: [
          _SettingField(
            key: 'agentic_active_start',
            label: _tr('活跃起始时间', 'Active Window Start'),
            help: _tr('24 小时制表示的有效服务起点（如 08:00）。', '24-hour timestamp indicating service availability start.'),
            placeholder: '08:00',
          ),
          _SettingField(
            key: 'agentic_active_end',
            label: _tr('活跃结束时间', 'Active Window End'),
            help: _tr('24 小时制表示的服务暂停节点（如 23:00）。', '24-hour timestamp for daily service suspensions.'),
            placeholder: '23:00',
          ),
          _SettingField(
            key: 'agentic_idle_threshold',
            label: _tr('静默容忍度 (分钟)', 'Idle Threshold (m)'),
            help: _tr(
              '通信静默超过该时限后解除闲时任务调度限制。',
              'Time to wait after last transmission before unblocking idle schedulers.',
            ),
            placeholder: '30',
          ),
        ],
      ),
      _SettingGroup(
        id: 'voice',
        title: _tr('TTS 配置', 'TTS Config'),
        description: _tr(
          '设定语音合成相关的服务端接口与参考样例。',
          'Configure synthesis endpoints and reference media samples.',
        ),
        fields: [
          _SettingField(
            key: 'tts_enabled',
            label: _tr('启用 TTS', 'Enable TTS'),
            help: _tr('控制系统是否调用指定的外部语音旁路。', 'Controls whether the system delegates to an external voice bypass.'),
            kind: _SettingFieldKind.toggle,
          ),
          _SettingField(
            key: 'tts_api_url',
            label: _tr('目标端点服务器', 'Target Endpoint URL'),
            help: _tr('执行语音合成与生成的服务地址。', 'Service address executing synthesis queries.'),
            placeholder: 'http://127.0.0.1:9880',
          ),
          _SettingField(
            key: 'tts_ref_audio_path',
            label: _tr('基准音源路径', 'Baseline Audio Track'),
            help: _tr('载入用以复制音色的参考本地环境全路径 (WAV)。', 'Full local path referencing target voice templates.'),
            placeholder: '/path/to/reference.wav',
          ),
          _SettingField(
            key: 'tts_text_lang',
            label: _tr('输出目标语意', 'Output Language Target'),
            help: _tr('指示文本转语音的目标包封语种代码。', 'Language code directing final audio generations.'),
            placeholder: 'zh',
          ),
          _SettingField(
            key: 'tts_prompt_lang',
            label: _tr('语种分析标识', 'Prompt Locale Tag'),
            help: _tr('用以辅助目标端点分析参考轨的语种类别。', 'Assists the endpoint in analyzing the reference media context.'),
            placeholder: 'zh',
          ),
          _SettingField(
            key: 'tts_speed_factor',
            label: _tr('渲染速率系数', 'Render Speed Factor'),
            help: _tr('基础值为 1.0 (等宽同步)。', 'Default baseline is 1.0.'),
            placeholder: '1.0',
          ),
          _SettingField(
            key: 'tts_ref_text',
            label: _tr('参考提示词样本', 'Reference Transcript'),
            help: _tr('供网络端点校准基础发音规律及停顿的引用文字。', 'Guiding strings used to profile tempo limits on target references.'),
            kind: _SettingFieldKind.multiline,
            rows: 5,
          ),
        ],
      ),
    ];
  }

  List<ChatSummary> get _filteredChats {
    final query = _chatQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _chats;
    }
    return _chats.where((chat) {
      return chat.label.toLowerCase().contains(query) || chat.chatId.toString().contains(query);
    }).toList();
  }

  ChatSummary? get _selectedChatSummary {
    for (final chat in _chats) {
      if (chat.chatId == _selectedChatId) {
        return chat;
      }
    }
    return null;
  }

  String get _themeClass => _theme == _DashboardTheme.dark ? 'theme-dark' : 'theme-light';

  bool get _hasStatusIssue => _error != null || _settingsError != null || _logsError != null;

  String get _statusTitle => _hasStatusIssue ? _tr('连接异常', 'Connection Error') : _tr('连接正常', 'Connection Normal');

  List<String> get _statusDetails {
    final details = <String>[];
    if (_error != null) {
      details.add(_error!);
    }
    if (_settingsError != null) {
      details.add(_settingsError!);
    }
    if (_logsError != null) {
      details.add(_logsError!);
    }
    if (details.isEmpty) {
      details.add(
        _overview != null
            ? _tr('Dashboard API 连通性测试通过。', 'Dashboard API connection tests passed.')
            : _tr(' Dashboard API 连接中...', 'Connecting to Dashboard API...'),
      );
    }
    return details;
  }

  String _friendlyError(Object error) {
    if (error is DashboardApiException) {
      return error.message;
    }
    final raw = error.toString();
    if (raw.contains('<!DOCTYPE') || raw.contains('Unexpected token')) {
      return _tr(
        '接口返回了非预期的 HTML 格式响应。',
        'Endpoint returned unexpected HTML formatted response.',
      );
    }
    return raw;
  }

  Map<String, String> get _dirtySettings {
    final keys = <String>{..._settings.keys, ..._draftSettings.keys};
    final dirty = <String, String>{};
    for (final key in keys) {
      final current = _settings[key] ?? '';
      final draft = _draftSettings[key] ?? '';
      if (current != draft) {
        dirty[key] = draft;
      }
    }
    return dirty;
  }

  Map<String, String> _groupChanges(_SettingGroup group) {
    final changes = <String, String>{};
    for (final field in group.fields) {
      final current = _settings[field.key] ?? '';
      final draft = _draftSettings[field.key] ?? '';
      if (current != draft) {
        changes[field.key] = draft;
      }
    }
    return changes;
  }

  String _fieldValue(_SettingField field) => _draftSettings[field.key] ?? _settings[field.key] ?? '';

  String _labelForSettingKey(String key) {
    for (final group in _settingGroups) {
      for (final field in group.fields) {
        if (field.key == key) {
          return field.label;
        }
      }
    }
    return key;
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'jaspr-panel $_themeClass', [
      div(classes: 'jaspr-shell', [
        _buildSidebar(),
        div(classes: 'jaspr-main', [
          _buildTopbar(),
          if (_notice != null) _banner(_notice!, error: false),
          _buildActiveSection(),
        ]),
      ]),
    ]);
  }

  Component _buildSidebar() {
    return aside(classes: 'jaspr-sidebar', [
      div(classes: 'jaspr-brand', [
        div(classes: 'jaspr-brand__mark', [
          const LucideIcon('send-horizontal', classes: 'jaspr-rail-button__icon'),
        ]),
      ]),
      div(classes: 'jaspr-sidebar__nav', [
        _sideNavItem(
          icon: const LucideIcon('layout-dashboard', classes: 'jaspr-rail-button__icon'),
          label: _tr('概览', 'Overview'),
          active: _activeSection == _DashboardSection.overview,
          onClick: () => _changeSection(_DashboardSection.overview),
        ),
        _sideNavItem(
          icon: const LucideIcon('settings', classes: 'jaspr-rail-button__icon'),
          label: _tr('配置', 'Configure'),
          active: _activeSection == _DashboardSection.configuration,
          onClick: () => _changeSection(_DashboardSection.configuration),
        ),
        _sideNavItem(
          icon: const LucideIcon('logs', classes: 'jaspr-rail-button__icon'),
          label: _tr('日志', 'Logs'),
          active: _activeSection == _DashboardSection.logs,
          onClick: () => _changeSection(_DashboardSection.logs),
        ),
      ]),
      div(classes: 'jaspr-sidebar__footer', [
        _buildStatusIndicator(),
        button(
          classes: 'jaspr-theme-toggle',
          onClick: _toggleTheme,
          [
            const LucideIcon('sun-moon', classes: 'jaspr-rail-button__icon'),
            span(
              classes: 'sr-only',
              [
                .text(
                  _theme == _DashboardTheme.dark
                      ? _tr('切换到浅色', 'Switch to light mode')
                      : _tr('切换到深色', 'Switch to dark mode'),
                ),
              ],
            ),
          ],
        ),
      ]),
    ]);
  }

  Component _buildStatusIndicator() {
    return div(classes: 'jaspr-status-indicator${_statusPopoverOpen ? ' is-open' : ''}', [
      button(
        classes: 'jaspr-status-toggle${_hasStatusIssue ? ' is-error' : ' is-ok'}',
        attributes: {'type': 'button'},
        onClick: _toggleStatusPopover,
        [
          const LucideIcon('circle-dot', classes: 'jaspr-rail-button__icon'),
          span(classes: 'sr-only', [.text(_statusTitle)]),
        ],
      ),
      div(classes: 'jaspr-status-indicator__popover', [
        h3(classes: 'jaspr-status-indicator__title', [.text(_statusTitle)]),
        div(classes: 'jaspr-status-indicator__list', [
          for (final detail in _statusDetails)
            p(classes: 'jaspr-status-indicator__item', [
              .text(detail),
            ]),
        ]),
      ]),
      if (_statusPopoverOpen) ...[
        button(
          classes: 'jaspr-status-modal__backdrop',
          attributes: {'type': 'button'},
          onClick: _toggleStatusPopover,
          [],
        ),
        div(classes: 'jaspr-status-modal', [
          div(classes: 'jaspr-status-modal__header', [
            h3(classes: 'jaspr-status-modal__title', [.text(_statusTitle)]),
            button(
              classes: 'jaspr-status-modal__close',
              attributes: {'type': 'button'},
              onClick: _toggleStatusPopover,
              [
                const LucideIcon('x'),
                span(classes: 'sr-only', [.text(_tr('关闭', 'Close'))]),
              ],
            ),
          ]),
          div(classes: 'jaspr-status-indicator__list', [
            for (final detail in _statusDetails)
              p(classes: 'jaspr-status-indicator__item', [
                .text(detail),
              ]),
          ]),
        ]),
      ],
    ]);
  }

  Component _buildTopbar() {
    final sectionLabel = switch (_activeSection) {
      _DashboardSection.overview => _tr('概览', 'Overview'),
      _DashboardSection.configuration => _tr('配置', 'Configuration'),
      _DashboardSection.logs => _tr('日志', 'Logs'),
    };
    final crumb = _selectedChatSummary != null ? '$sectionLabel / ${_selectedChatSummary!.label}' : sectionLabel;
    final centerLabel = _overview?.meta.botName ?? 'Jaspr Panel';

    return div(classes: 'studio-topbar', [
      div(classes: 'studio-topbar__crumb', [.text(crumb)]),
      div(classes: 'studio-topbar__center', [.text(centerLabel)]),
      div(classes: 'studio-topbar__actions', [
        button(
          classes: 'studio-btn studio-btn--ghost studio-btn--icon studio-toolbar-btn',
          onClick: _refreshActiveSurface,
          [
            const LucideIcon('refresh-cw'),
            span(classes: 'sr-only', [.text(_tr('刷新数据', 'Refresh'))]),
          ],
        ),
      ]),
    ]);
  }

  Component _buildActiveSection() {
    switch (_activeSection) {
      case _DashboardSection.overview:
        return _buildOverviewSection();
      case _DashboardSection.configuration:
        return _buildConfigurationSection();
      case _DashboardSection.logs:
        return _buildLogsSection();
    }
  }

  Component _buildOverviewSection() {
    final overview = _overview;
    final detail = _chatDetail;

    return div(classes: 'dashboard-grid', [
      div(classes: 'dashboard-column', [
        _surface(
          eyebrow: _tr('概览面板', 'Overview'),
          title: _tr('状态总览', 'Status Overview'),
          copy: _tr(
            '支持高维度数据及健康度确认，全局系统配置与详细参数调节可通独立页签访问。',
            'Supports high-level status checks and health confirmations. Configurations and logs are accessed via tabbed panels.',
          ),
          children: [
            div(classes: 'studio-actions', [
              button(
                classes: 'studio-btn studio-btn--primary',
                onClick: () => _changeSection(_DashboardSection.configuration),
                [
                  .text(_tr('前往配置管理', 'Manage Configurations')),
                ],
              ),
              button(
                classes: 'studio-btn studio-btn--ghost',
                onClick: () => _changeSection(_DashboardSection.logs),
                [
                  .text(_tr('深入排查日志', 'Inspect System Logs')),
                ],
              ),
            ]),
          ],
        ),
        div(classes: 'dashboard-metrics', [
          _statCard(
            _tr('活动会话总数', 'Active Sessions'),
            '${_chats.length}',
            _tr('Dashboard 当前已载入的会话总数。', 'Chat instances currently loaded into the interface.'),
          ),
          _statCard(
            _tr('下发任务异常', 'Distribution Errors'),
            '${overview?.subscriptions.active ?? 0}/${overview?.subscriptions.total ?? 0}',
            _tr(
              '${overview?.subscriptions.error ?? 0} 项投递任务返回异常',
              '${overview?.subscriptions.error ?? 0} remote tasks returned exceptions',
            ),
          ),
          _statCard(
            _tr('上下文缓冲上限', 'Tokens Limit'),
            '${overview?.settings.historyTokens ?? 0}',
            _tr('在单次完整交互循环内设定的最大历史参考文本长度。', 'Maximum contextual token budget designated for dialogue memories.'),
          ),
          _statCard(
            _tr('系统首选时区', 'Base Timezone'),
            overview?.settings.timezone ?? _t.nA,
            _tr('作为计划任务队列和自动化流程等后台事件的日期校准面。', 'Running timeline reference for internal backend event schedules.'),
          ),
        ]),
        div(classes: 'dashboard-split', [
          _buildChatNavigator(
            title: _tr('运行实例选择器', 'Instance Navigator'),
            copy: _tr('定位具体会话实体或运行历史检索详细细节。', 'Target specific entity records to inspect context references.'),
          ),
          _buildSubscriptionsPanel(),
        ]),
        if (_loadingChat)
          _loadingSurface(
            _tr('获取指定会话中...', 'Synchronizing details'),
            _tr(
              '从本地核心节点提取缓存的历史事件列表及参数...',
              'Extracting persisted events and parameters from the local backend...',
            ),
          )
        else if (detail == null)
          _emptySurface(
            _tr('尚未指定对象', 'No object selected'),
            _tr(
              '请从左侧栏选择目标容器，获取其参数及控制台。',
              'Please select an object from the left list. The panel will render specific endpoints.',
            ),
          )
        else
          _buildOverviewFocus(detail),
      ]),
      div(classes: 'dashboard-rail', [
        _buildConnectionRail(),
        if (detail != null) _buildSessionRail(detail),
        _buildQuickActionsRail(),
      ]),
    ]);
  }

  Component _buildOverviewFocus(ChatDetail detail) {
    return div(classes: 'dashboard-column', [
      _surface(
        eyebrow: _tr('当前会话', 'Current Session'),
        title: detail.label,
        copy: _tr(
          '列出当前选中对象的会话属性与核心运行数据。',
          'Lists dialogue properties and core runtime metrics for the selected object.',
        ),
        children: [
          div(classes: 'studio-chip-row', [
            _chip(_tr('类型', 'Type'), _t.localizedChatType(detail.chatType)),
            _chip(_tr('时区', 'Timezone'), detail.timezone),
            _chip(_tr('白名单', 'Whitelist'), detail.whitelisted ? _tr('已启用', 'Enabled') : _tr('未启用', 'Disabled')),
          ]),
          div(classes: 'dashboard-metrics dashboard-metrics--compact', [
            _statCard(
              _tr('活跃 Tokens', 'Active tokens'),
              '${detail.sessionStats.activeTokens}',
              _tr('热上下文窗口', 'Hot context window'),
              compact: true,
            ),
            _statCard(
              _tr('缓冲 Tokens', 'Buffer tokens'),
              '${detail.sessionStats.bufferTokens}',
              _tr('等待进入摘要归档', 'Waiting to roll into summary'),
              compact: true,
            ),
            _statCard(
              _tr('RAG 已索引', 'RAG indexed'),
              '${detail.ragStats.indexed}',
              _tr('${detail.ragStats.pending} 条待处理', '${detail.ragStats.pending} pending'),
              compact: true,
            ),
            _statCard(
              _tr('总消息数', 'Total messages'),
              '${detail.sessionStats.totalMessages}',
              _tr('窗口起点 ${detail.sessionStats.winStartId}', 'Window starts at ${detail.sessionStats.winStartId}'),
              compact: true,
            ),
          ]),
          div(classes: 'studio-actions', [
            button(
              classes: 'studio-btn studio-btn--ghost',
              onClick: () => _selectChat(detail.chatId),
              [
                .text(_tr('重新读取缓存', 'Reload Cache')),
              ],
            ),
            button(
              classes: 'studio-btn studio-btn--danger',
              onClick: _rebuildRag,
              [
                .text(_tr('重建 RAG', 'Rebuild RAG')),
              ],
            ),
            button(
              classes: 'studio-btn studio-btn--ghost',
              onClick: () => _changeSection(_DashboardSection.logs),
              [
                .text(_tr('检视底层日志', 'Inspect Logs')),
              ],
            ),
          ]),
        ],
      ),
      div(classes: 'dashboard-split', [
        _surface(
          eyebrow: _tr('信息归档', 'Summary Archive'),
          title: _tr('长期记忆状态', 'Long-term Memory State'),
          copy: _tr(
            '展示由引擎后台自动生成的对话压缩快照。',
            'Displays the dialogue compression snapshot automatically generated by the background engine.',
          ),
          children: [
            _copyBlock(
              detail.summary.content.isEmpty
                  ? _tr('当前对象尚无压缩记录。', 'No compressed records exist yet.')
                  : detail.summary.content,
            ),
            div(classes: 'studio-kv-list', [
              _kvRow(_tr('最后摘要 ID', 'Last summarized id'), '${detail.summary.lastSummarizedId}'),
              _kvRow(_tr('更新时间', 'Updated'), _timeLabel(detail.summary.updatedAt)),
            ]),
          ],
        ),
        _surface(
          eyebrow: _tr('推理组装', 'Prompt Formulation'),
          title: _tr('运行时组装示例', 'Runtime Composition Example'),
          copy: _tr(
            '撷取部分发往上游模型的提示词边界样本。',
            'Excerpts a partial boundary sample of the prompt payload sent upstream.',
          ),
          children: [
            _codeBlock(
              _tr('硬编码系统级指引', 'Hardcoded system protocol'),
              _clipText(_promptPreview?.systemProtocol ?? _tr('未检测到预览负载。', 'No preview payload detected.'), 700),
            ),
            _codeBlock(
              _tr('短时记忆队列注入', 'Short-term memory hook'),
              _clipText(_promptPreview?.memoryContext ?? _tr('短时记忆上下文为空。', 'Short-term context is empty.'), 520),
            ),
          ],
        ),
      ]),
    ]);
  }

  Component _buildConfigurationSection() {
    return div(classes: 'dashboard-grid', [
      div(classes: 'dashboard-column', [
        _surface(
          eyebrow: _tr('参数配置', 'Configuration'),
          title: _tr('全量环境设置', 'Global Settings'),
          copy: _tr(
            '提供应用运行所需的核心参数修改。包含服务路由、上下文选项及定时调度模块。',
            'Supports core parameter overrides, providing access to routing, context, and schedule settings.',
          ),
          children: [
            div(classes: 'studio-chip-row', [
              _chip(_tr('未保存改动', 'Unsaved changes'), '${_dirtySettings.length}'),
              _chip(_tr('配置分组', 'Config groups'), '${_settingGroups.length}'),
              _chip(_tr('接口', 'API'), 'PATCH /api/settings'),
            ]),
          ],
        ),
        if (_loadingSettings)
          _loadingSurface(
            _tr('正在加载配置', 'Loading settings'),
            _tr('所有可写设置项会在这里恢复成可编辑状态。', 'Editable settings are being restored into the dashboard.'),
          )
        else if (_settingsError != null && _settings.isEmpty)
          _emptySurface(
            _tr('配置暂不可读取', 'Settings unavailable'),
            _tr('查看侧栏底部的状态指示器获取接口详情。', 'Use the sidebar status indicator for API details.'),
          )
        else
          div(classes: 'dashboard-column', [
            for (final group in _settingGroups) _buildSettingGroup(group),
          ]),
      ]),
      div(classes: 'dashboard-rail', [
        _buildConfigSummaryRail(),
        _buildConfigTipsRail(),
      ]),
    ]);
  }

  Component _buildSettingGroup(_SettingGroup group) {
    final changes = _groupChanges(group);
    final saving = _savingGroupId == group.id;

    return _surface(
      eyebrow: _tr('配置分组', 'Config group'),
      title: group.title,
      copy: group.description,
      children: [
        div(classes: 'studio-chip-row', [
          _chip(_tr('改动数', 'Changes'), '${changes.length}'),
          _chip(_tr('字段数', 'Fields'), '${group.fields.length}'),
        ]),
        div(classes: 'settings-grid', [
          for (final field in group.fields) _buildField(field),
        ]),
        div(classes: 'studio-actions studio-actions--between', [
          p(classes: 'studio-copy studio-copy--sm', [
            .text(
              changes.isEmpty
                  ? _tr('这一组目前没有未保存改动。', 'No unsaved changes in this group.')
                  : _tr('这组有 ${changes.length} 个字段待保存。', '${changes.length} fields are ready to save in this group.'),
            ),
          ]),
          div(classes: 'studio-actions', [
            button(
              classes: 'studio-btn studio-btn--ghost',
              onClick: changes.isEmpty || saving ? null : () => _resetGroup(group),
              [
                .text(_tr('撤回这组改动', 'Reset group')),
              ],
            ),
            button(
              classes: 'studio-btn studio-btn--primary',
              onClick: changes.isEmpty || saving ? null : () => _saveGroup(group),
              [
                .text(saving ? _tr('保存中...', 'Saving...') : _tr('保存这组配置', 'Save group')),
              ],
            ),
          ]),
        ]),
      ],
    );
  }

  Component _buildField(_SettingField field) {
    final value = _fieldValue(field);
    final dirty = (_settings[field.key] ?? '') != value;

    Component control;
    switch (field.kind) {
      case _SettingFieldKind.toggle:
        final enabled = _isTruthy(value);
        control = div(classes: 'studio-toggle', [
          button(
            classes: 'studio-btn ${enabled ? 'studio-btn--primary' : 'studio-btn--ghost'}',
            onClick: enabled ? null : () => _updateDraft(field.key, 'true'),
            [
              .text(_tr('开启', 'On')),
            ],
          ),
          button(
            classes: 'studio-btn ${enabled ? 'studio-btn--ghost' : 'studio-btn--primary'}',
            onClick: enabled ? () => _updateDraft(field.key, 'false') : null,
            [
              .text(_tr('关闭', 'Off')),
            ],
          ),
        ]);
      case _SettingFieldKind.multiline:
        control = textarea(
          [.text(value)],
          rows: field.rows,
          classes: 'studio-textarea',
          placeholder: field.placeholder.isEmpty ? null : field.placeholder,
          onInput: (next) => _updateDraft(field.key, next),
        );
      case _SettingFieldKind.text:
        control = input(
          type: field.secret ? InputType.password : InputType.text,
          value: value,
          classes: 'studio-input',
          attributes: field.placeholder.isEmpty ? null : {'placeholder': field.placeholder},
          onInput: (String next) => _updateDraft(field.key, next),
        );
    }

    return div(classes: 'studio-field${field.kind == _SettingFieldKind.multiline ? ' is-wide' : ''}', [
      div(classes: 'studio-field__head', [
        div(classes: 'studio-field__label', [.text(field.label)]),
        if (dirty) span(classes: 'studio-field__badge', [.text(_tr('未保存', 'Unsaved'))]),
      ]),
      p(classes: 'studio-field__help', [.text(field.help)]),
      control,
    ]);
  }

  Component _buildLogsSection() {
    return div(classes: 'dashboard-log-grid', [
      _buildChatNavigator(
        title: _tr('日志对象', 'Log scope'),
        copy: _tr('各面板将按选中实例过滤对应记录。', 'Log panels will filter records based on the selected instance.'),
      ),
      div(classes: 'dashboard-column', [
        _surface(
          eyebrow: _tr('全链路日志', 'System Logs'),
          title: _tr('分层审计视图', 'Layered Auditing Views'),
          copy: _tr(
            '应用日志由系统引擎层、业务消息及 RAG 索引构成，使用不同页签进行分类查阅。',
            'Logs consist of the engine layer, business queues, and RAG indexing. Select tabs to audit separately.',
          ),
          children: [
            div(classes: 'studio-segments', [
              _segmentButton(
                label: _tr('消息队列', 'Message Queue'),
                active: _activeLogPane == _LogPane.conversations,
                onClick: () => _changeLogPane(_LogPane.conversations),
              ),
              _segmentButton(
                label: _tr('RAG 索引', 'RAG Index'),
                active: _activeLogPane == _LogPane.rag,
                onClick: () => _changeLogPane(_LogPane.rag),
              ),
              _segmentButton(
                label: _tr('系统引擎', 'Engine Service'),
                active: _activeLogPane == _LogPane.system,
                onClick: () => _changeLogPane(_LogPane.system),
              ),
            ]),
          ],
        ),
        _buildLogPaneSurface(),
      ]),
      div(classes: 'dashboard-rail', [
        _buildLogRail(),
      ]),
    ]);
  }

  Component _buildLogPaneSurface() {
    if (_activeLogPane == _LogPane.system) {
      return _surface(
        eyebrow: _tr('系统引擎', 'Engine'),
        title: _tr('进程输出流', 'Standard Streams'),
        copy: _tr('引擎主进程相关的标准错误与调试输出。', 'Standard output and error streams originating from the host engine process.'),
        children: [
          div(classes: 'studio-actions', [
            button(
              classes: 'studio-btn studio-btn--ghost',
              onClick: _loadLogs,
              [
                .text(_loadingLogs ? _tr('刷新中...', 'Refreshing...') : _tr('刷新日志', 'Refresh log')),
              ],
            ),
            if (_logs?.truncated == true) _chip(_tr('状态', 'State'), _tr('已截断', 'Truncated')),
            if (_logs != null && _logs!.path.isNotEmpty) _chip(_tr('路径', 'Path'), _logs!.path),
          ]),
          if (_logsError != null)
            _emptySurface(
              _tr('系统日志暂不可读取', 'System log unavailable'),
              _tr('查看侧栏底部的状态指示器获取接口详情。', 'Use the sidebar status indicator for API details.'),
              compact: true,
            )
          else if (_loadingLogs && _logs == null)
            _loadingSurface(
              _tr('等待日志接口', 'Waiting for log endpoint'),
              _tr('系统日志会原地加载到这个区域。', 'System logs will hydrate in place here.'),
            )
          else
            pre(classes: 'studio-log-pre', [
              .text(
                _logs?.content.isEmpty == true
                    ? _tr('(日志文件为空)', '(log file is empty)')
                    : _logs?.content ?? _tr('还没有日志输出。', 'No log output yet.'),
              ),
            ]),
        ],
      );
    }

    if (_loadingChat) {
      return _loadingSurface(
        _tr('正在加载会话日志', 'Loading session logs'),
        _tr('选中的会话正在同步最近消息与 RAG 记录。', 'The selected session is hydrating recent messages and RAG records.'),
      );
    }

    final detail = _chatDetail;
    if (detail == null) {
      return _emptySurface(
        _tr('还没有选中会话', 'No session selected'),
        _tr(
          '先从左侧列表选择会话，再查看最近对话记录或 RAG 记录。',
          'Choose a session from the left rail before inspecting conversation or RAG logs.',
        ),
      );
    }

    return switch (_activeLogPane) {
      _LogPane.conversations => _buildConversationLogSurface(detail),
      _LogPane.rag => _buildRagLogSurface(detail),
      _LogPane.system => _emptySurface('', ''),
    };
  }

  Component _buildConversationLogSurface(ChatDetail detail) {
    final page = _messagePage;
    return _surface(
      eyebrow: _tr('消息队列', 'Message Queue'),
      title: detail.label,
      copy: _tr(
        '展示当前实例上报的所有历史交互报文，支持分页检视与跟踪。',
        'Displays raw interaction sequences connected to this instance, enabling payload tracing and pagination.',
      ),
      children: [
        _pager(
          total: page?.total ?? detail.sessionStats.totalMessages,
          offset: page?.offset ?? 0,
          itemCount: page?.items.length ?? 0,
          hasPrev: page?.hasPrev ?? false,
          hasNext: page?.hasNext ?? false,
          loading: _loadingMessages,
          onPrev: page?.prevOffset == null ? null : () => _loadMessagePage(page!.prevOffset!),
          onNext: page?.nextOffset == null ? null : () => _loadMessagePage(page!.nextOffset!),
        ),
        if (_loadingMessages && page == null)
          _loadingSurface(
            _tr('正在读取分页消息', 'Loading message page'),
            _tr('消息列表会按分页展开。', 'The message list is being expanded by page.'),
          )
        else if (page == null || page.items.isEmpty)
          _emptySurface(
            _tr('暂无消息记录', 'No message records'),
            _tr('这个会话还没有可展示的消息。', 'This session does not have message records to display yet.'),
          )
        else
          div(classes: 'dashboard-column', [
            for (final message in page.items) _messageCard(message),
          ]),
      ],
    );
  }

  Component _buildRagLogSurface(ChatDetail detail) {
    final page = _ragPage;
    return _surface(
      eyebrow: _tr('RAG 索引', 'RAG Index'),
      title: detail.label,
      copy: _tr(
        '此视图关联当前对话的知识库匹配状态与被引用的源切片信息。',
        'Links to retrieved knowledge vector states and text excerpts referenced by this dialogue context.',
      ),
      children: [
        div(classes: 'studio-actions', [
          button(
            classes: 'studio-btn studio-btn--danger',
            onClick: _rebuildRag,
            [
              .text(_tr('重建这个会话的 RAG', 'Rebuild RAG for this chat')),
            ],
          ),
        ]),
        _pager(
          total: page?.total ?? detail.ragStats.indexed,
          offset: page?.offset ?? 0,
          itemCount: page?.items.length ?? 0,
          hasPrev: page?.hasPrev ?? false,
          hasNext: page?.hasNext ?? false,
          loading: _loadingRag,
          onPrev: page?.prevOffset == null ? null : () => _loadRagPage(page!.prevOffset!),
          onNext: page?.nextOffset == null ? null : () => _loadRagPage(page!.nextOffset!),
        ),
        if (_loadingRag && page == null)
          _loadingSurface(
            _tr('正在读取 RAG 分页', 'Loading RAG page'),
            _tr('索引记录会按分页加载。', 'Indexed records are being loaded by page.'),
          )
        else if (page == null || page.items.isEmpty)
          _emptySurface(
            _tr('暂无 RAG 记录', 'No RAG records'),
            _tr('这个会话还没有被索引的 RAG 记录。', 'There are no indexed RAG records for this session yet.'),
          )
        else
          div(classes: 'dashboard-column', [
            for (final record in page.items) _ragCard(record),
          ]),
      ],
    );
  }

  Component _buildChatNavigator({
    required String title,
    required String copy,
  }) {
    final chats = _filteredChats;

    return _surface(
      eyebrow: _tr('会话', 'Chats'),
      title: title,
      copy: copy,
      children: [
        input(
          value: _chatQuery,
          classes: 'studio-input studio-input--search',
          attributes: {'placeholder': _tr('搜索会话 / chat id', 'Search chats / chat id')},
          onInput: (String value) {
            setState(() {
              _chatQuery = value;
            });
          },
        ),
        if (chats.isEmpty)
          _emptySurface(
            _tr('没有命中结果', 'No matches'),
            _tr('试试换一个关键词，或者等后端同步更多会话。', 'Try another keyword or wait for more chats to sync in.'),
            compact: true,
          )
        else
          div(classes: 'chat-list', [
            for (final chat in chats)
              button(
                classes: 'chat-list__item${_selectedChatId == chat.chatId ? ' is-active' : ''}',
                onClick: () => _selectChat(chat.chatId),
                [
                  div(classes: 'chat-list__head', [
                    span(classes: 'chat-list__title', [.text(chat.label)]),
                    span(classes: 'studio-status ${chat.whitelisted ? 'status-ok' : 'status-muted'}', [
                      .text(_t.localizedChatType(chat.chatType)),
                    ]),
                  ]),
                  div(classes: 'chat-list__meta', [
                    span([.text(_tr('消息 ${chat.totalMessages}', 'Messages ${chat.totalMessages}'))]),
                    span([.text(_timeLabel(chat.lastMessageAt))]),
                  ]),
                ],
              ),
          ]),
      ],
    );
  }

  Component _buildSubscriptionsPanel() {
    return _surface(
      eyebrow: _tr('订阅', 'Subscriptions'),
      title: _tr('分发健康度', 'Distribution health'),
      copy: _tr(
        '概览里只看状态、错误和最近检查，不在这里做深层排查。',
        'Overview keeps subscription health lightweight; deeper investigation belongs elsewhere.',
      ),
      children: [
        if (_subscriptions.isEmpty)
          _emptySurface(
            _tr('暂时没有订阅数据', 'No subscription data yet'),
            _tr('当后端可用后，这里会显示订阅源与分发状态。', 'Subscription health appears here once the backend is reachable.'),
            compact: true,
          )
        else
          div(classes: 'dashboard-column', [
            for (final subscription in _subscriptions.take(5))
              div(classes: 'subscription-card', [
                div(classes: 'subscription-card__head', [
                  div(classes: 'subscription-card__copy', [
                    h3(classes: 'subscription-card__title', [.text(subscription.name)]),
                    p(classes: 'subscription-card__route', [.text(subscription.route)]),
                  ]),
                  span(classes: 'studio-status ${_subscriptionStatusClass(subscription.status)}', [
                    .text(_t.localizedSubscriptionStatus(subscription.status)),
                  ]),
                ]),
                div(classes: 'studio-chip-row', [
                  _chip(_tr('目标', 'Targets'), '${subscription.targetCount}'),
                  _chip(_tr('错误', 'Errors'), '${subscription.errorCount}'),
                ]),
                if (subscription.lastError != null && subscription.lastError!.isNotEmpty)
                  p(classes: 'subscription-card__error', [.text(subscription.lastError!)]),
              ]),
          ]),
      ],
    );
  }

  Component _buildConnectionRail() {
    final overview = _overview;

    return _surface(
      eyebrow: _tr('连接', 'Connection'),
      title: _tr('当前运行边界', 'Current runtime boundary'),
      copy: _tr(
        '先告诉你界面是否真的连上本地 API，再决定后续动作。',
        'Start by confirming whether the UI is actually connected to the local API.',
      ),
      children: [
        div(classes: 'studio-kv-list', [
          _kvRow(
            _tr('状态', 'State'),
            overview != null
                ? _tr('已连接', 'Connected')
                : (_loading ? _tr('连接中', 'Connecting') : _tr('离线骨架', 'Offline shell')),
          ),
          _kvRow('API', _connection.apiBaseUrl),
          if (overview != null) _kvRow(_tr('Bot', 'Bot'), overview.meta.botName),
          _kvRow(
            _tr('认证', 'Auth'),
            _connection.token == null ? _tr('未附带 Token', 'No token attached') : _tr('已附带 Token', 'Token attached'),
          ),
        ]),
      ],
    );
  }

  Component _buildSessionRail(ChatDetail detail) {
    return _surface(
      eyebrow: _tr('会话焦点', 'Session focus'),
      title: detail.label,
      copy: _tr(
        '右侧轨道只放真正需要盯住的会话信息。',
        'The right rail keeps only the session details worth monitoring continuously.',
      ),
      children: [
        div(classes: 'studio-kv-list', [
          _kvRow(_tr('Chat ID', 'Chat ID'), '${detail.chatId}'),
          _kvRow(_tr('类型', 'Type'), _t.localizedChatType(detail.chatType)),
          _kvRow(_tr('时区', 'Timezone'), detail.timezone),
          _kvRow(_tr('消息总量', 'Messages'), '${detail.sessionStats.totalMessages}'),
          _kvRow(_tr('RAG 待处理', 'RAG pending'), '${detail.ragStats.pending}'),
          _kvRow(_tr('冷却剩余', 'Cooldown left'), '${detail.ragStats.cooldownLeft}s'),
        ]),
      ],
    );
  }

  Component _buildQuickActionsRail() {
    return _surface(
      eyebrow: _tr('快速指令', 'Quick Actions'),
      title: _tr('操作项', 'Operations'),
      copy: _tr(
        '提供常用的页面跳转及数据刷新入口。',
        'Provides quick access to primary views and data refreshes.',
      ),
      children: [
        div(classes: 'dashboard-column', [
          button(
            classes: 'studio-btn studio-btn--primary studio-btn--block',
            onClick: () => _changeSection(_DashboardSection.configuration),
            [
              .text(_tr('打开配置中心', 'Open configuration center')),
            ],
          ),
          button(
            classes: 'studio-btn studio-btn--ghost studio-btn--block',
            onClick: () => _changeSection(_DashboardSection.logs),
            [
              .text(_tr('去日志页追踪', 'Open logs')),
            ],
          ),
          button(
            classes: 'studio-btn studio-btn--ghost studio-btn--block',
            onClick: _refreshActiveSurface,
            [
              .text(_tr('刷新当前页面数据', 'Refresh current data')),
            ],
          ),
        ]),
      ],
    );
  }

  Component _buildConfigSummaryRail() {
    final dirty = _dirtySettings.entries.toList();

    return _surface(
      eyebrow: _tr('配置状态', 'Configuration State'),
      title: _tr('未保存项提要', 'Pending Changes'),
      copy: _tr(
        '列出当前未提交的系统级参数变更快照。',
        'Lists uncommitted changes to system-level configuration parameters.',
      ),
      children: [
        div(classes: 'studio-kv-list', [
          _kvRow(_tr('未保存字段', 'Unsaved fields'), '${dirty.length}'),
          _kvRow(_tr('可写分组', 'Editable groups'), '${_settingGroups.length}'),
          _kvRow(
            _tr('当前主题', 'Theme'),
            _theme == _DashboardTheme.dark ? _tr('极客深黑', 'Geek black') : _tr('米白浅色', 'Warm ivory'),
          ),
        ]),
        if (dirty.isEmpty)
          _emptySurface(
            _tr('当前没有待保存改动', 'No unsaved changes'),
            _tr('每组设置都可以独立保存。', 'Each configuration group can be saved independently.'),
            compact: true,
          )
        else
          div(classes: 'dashboard-column', [
            for (final entry in dirty.take(8))
              div(classes: 'studio-kv-row', [
                span(classes: 'studio-kv-row__key', [.text(_labelForSettingKey(entry.key))]),
                span(classes: 'studio-kv-row__value studio-kv-row__value--wrap', [
                  .text(entry.value.isEmpty ? _tr('(清空)', '(cleared)') : entry.value),
                ]),
              ]),
          ]),
      ],
    );
  }

  Component _buildConfigTipsRail() {
    return _surface(
      eyebrow: _tr('帮助说明', 'Documentation'),
      title: _tr('参数存储机制', 'Storage Mechanisms'),
      copy: _tr(
        '提示不同类目下的配置保存及应用生效范围。',
        'Details the scope and lifecycle of configuration persistence.',
      ),
      children: [
        div(classes: 'dashboard-column', [
          _tipCard(
            _tr('独立提交流程', 'Independent Commits'),
            _tr(
              '各项配置采用分组提交机制，提交时仅影响当前视图所在的应用组。',
              'Configurations commit independently by group, isolating changes to their specific context.',
            ),
          ),
          _tipCard(
            _tr('无缝重载', 'Seamless Reloads'),
            _tr(
              '参数覆写成功后将实时更新至主控节点内存池。',
              'Successful parameter overrides automatically rehydrate into the engine memory pool.',
            ),
          ),
          _tipCard(
            _tr('后验校验', 'Post-validation'),
            _tr(
              '所有字段受服务端配置结构规约，异常输入将被接口拒绝。',
              'Inputs map directly to the backend settings schema; illegal values will be rejected upstream.',
            ),
          ),
        ]),
      ],
    );
  }

  Component _buildLogRail() {
    if (_activeLogPane == _LogPane.system) {
      return _surface(
        eyebrow: _tr('运行态', 'Runtime'),
        title: _tr('系统日志上下文', 'System log context'),
        copy: _tr(
          '系统 log 不依赖具体会话，所以右侧只保留运行态提示。',
          'System logs are not tied to a single session, so the right rail stays focused on runtime context.',
        ),
        children: [
          div(classes: 'studio-kv-list', [
            _kvRow(_tr('状态', 'State'), _logsError == null ? _tr('可读取', 'Readable') : _tr('异常', 'Error')),
            _kvRow(_tr('路径', 'Path'), _logs?.path.isNotEmpty == true ? _logs!.path : _t.nA),
            _kvRow(_tr('截断', 'Truncated'), _logs?.truncated == true ? _tr('是', 'Yes') : _tr('否', 'No')),
          ]),
        ],
      );
    }

    final detail = _chatDetail;
    if (detail == null) {
      return _emptySurface(
        _tr('右侧详情暂时为空', 'No rail details yet'),
        _tr('选择会话后，这里会显示会话级上下文。', 'Pick a chat to reveal session-level context here.'),
      );
    }

    return _surface(
      eyebrow: _tr('会话详情', 'Session detail'),
      title: detail.label,
      copy: _tr(
        '日志页的右侧只服务排查，不再塞配置表单或总览说明。',
        'The logs rail is dedicated to debugging, without configuration forms or overview copy.',
      ),
      children: [
        div(classes: 'studio-kv-list', [
          _kvRow(_tr('Chat ID', 'Chat ID'), '${detail.chatId}'),
          _kvRow(_tr('类型', 'Type'), _t.localizedChatType(detail.chatType)),
          _kvRow(_tr('窗口消息', 'Window messages'), '${detail.sessionStats.totalMessages}'),
          _kvRow(_tr('RAG 已索引', 'RAG indexed'), '${detail.ragStats.indexed}'),
          _kvRow(_tr('RAG 待处理', 'RAG pending'), '${detail.ragStats.pending}'),
        ]),
        _copyBlock(
          _clipText(
            detail.summary.content.isEmpty ? _tr('还没有摘要内容。', 'No archived summary yet.') : detail.summary.content,
            280,
          ),
        ),
      ],
    );
  }

  Component _surface({
    required String eyebrow,
    required String title,
    required String copy,
    required List<Component> children,
  }) {
    return div(classes: 'studio-panel', [
      div(classes: 'studio-eyebrow', [.text(eyebrow)]),
      h2(classes: 'studio-title', [.text(title)]),
      if (copy.isNotEmpty) p(classes: 'studio-copy', [.text(copy)]),
      if (children.isNotEmpty) ...[
        div(classes: 'studio-surface__body', children),
      ],
    ]);
  }

  Component _statCard(String label, String value, String detail, {bool compact = false}) {
    return div(classes: 'studio-stat${compact ? ' is-compact' : ''}', [
      div(classes: 'studio-stat__label', [.text(label)]),
      div(classes: 'studio-stat__value', [.text(value)]),
      p(classes: 'studio-stat__detail', [.text(detail)]),
    ]);
  }

  Component _chip(String label, String value) {
    return div(classes: 'studio-chip', [
      .text('$label · $value'),
    ]);
  }

  Component _kvRow(String label, String value) {
    return div(classes: 'studio-kv-row', [
      span(classes: 'studio-kv-row__key', [.text(label)]),
      span(classes: 'studio-kv-row__value', [.text(value)]),
    ]);
  }

  Component _copyBlock(String content) {
    return div(classes: 'studio-copy-block', [
      pre(classes: 'studio-copy-block__pre', [
        .text(content),
      ]),
    ]);
  }

  Component _codeBlock(String title, String content) {
    return div(classes: 'studio-code', [
      div(classes: 'studio-code__label', [.text(title)]),
      pre(classes: 'studio-code__pre', [.text(content)]),
    ]);
  }

  Component _banner(String text, {required bool error}) {
    return div(classes: 'studio-banner ${error ? 'is-error' : 'is-info'}', [
      .text(text),
    ]);
  }

  Component _loadingSurface(String title, String copy, {bool compact = false}) {
    return div(classes: 'studio-panel${compact ? ' studio-panel--compact' : ''}', [
      div(classes: 'studio-eyebrow', [.text(_tr('加载中', 'Loading'))]),
      h2(classes: 'studio-title', [.text(title)]),
      p(classes: 'studio-copy', [.text(copy)]),
    ]);
  }

  Component _emptySurface(String title, String copy, {bool compact = false}) {
    return div(classes: 'studio-panel studio-panel--empty${compact ? ' studio-panel--compact' : ''}', [
      if (title.isNotEmpty) h2(classes: 'studio-title', [.text(title)]),
      if (copy.isNotEmpty) p(classes: 'studio-copy', [.text(copy)]),
    ]);
  }

  Component _tipCard(String title, String body) {
    return div(classes: 'studio-tip', [
      h3(classes: 'studio-tip__title', [.text(title)]),
      p(classes: 'studio-tip__body', [.text(body)]),
    ]);
  }

  Component _sideNavItem({
    required Component icon,
    required String label,
    required bool active,
    required VoidCallback onClick,
  }) {
    return button(
      classes: 'jaspr-nav-item${active ? ' is-active' : ''}',
      onClick: onClick,
      [
        icon,
        span(classes: 'sr-only', [.text(label)]),
      ],
    );
  }

  Component _segmentButton({
    required String label,
    required bool active,
    required VoidCallback onClick,
  }) {
    return button(
      classes: 'studio-segment${active ? ' is-active' : ''}',
      onClick: onClick,
      [
        .text(label),
      ],
    );
  }

  Component _pager({
    required int total,
    required int offset,
    required int itemCount,
    required bool hasPrev,
    required bool hasNext,
    required bool loading,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    final start = total == 0 ? 0 : offset + 1;
    final end = total == 0 ? 0 : math.min(offset + itemCount, total);

    return div(classes: 'studio-pager', [
      div(classes: 'studio-chip-row', [
        _chip(_tr('状态', 'State'), loading ? _tr('读取中', 'Loading') : _tr('就绪', 'Ready')),
        _chip(_tr('分页', 'Page'), '$start-$end / $total'),
        _chip(_tr('视图', 'View'), _tr('原始数据', 'Raw data')),
      ]),
      div(classes: 'studio-actions', [
        button(
          classes: 'studio-btn studio-btn--ghost',
          onClick: hasPrev ? onPrev : null,
          [
            .text(_tr('上一页', 'Prev')),
          ],
        ),
        button(
          classes: 'studio-btn studio-btn--primary',
          onClick: hasNext ? onNext : null,
          [
            .text(_tr('下一页', 'Next')),
          ],
        ),
      ]),
    ]);
  }

  Component _messageCard(RecentMessage message) {
    return div(classes: 'record-card', [
      div(classes: 'record-card__head', [
        span(classes: 'studio-status status-muted', [
          .text('DB ${message.dbId} / MSG ${message.messageId ?? '?'}'),
        ]),
        span(classes: 'studio-status status-muted', [
          .text('${message.role} / ${message.messageType}'),
        ]),
        span(classes: 'record-card__time', [.text(_timeLabel(message.timestamp))]),
      ]),
      _copyBlock(message.content.isEmpty ? _tr('(空内容)', '(empty)') : message.content),
    ]);
  }

  Component _ragCard(RagRecord record) {
    return div(classes: 'record-card', [
      div(classes: 'record-card__head', [
        span(classes: 'studio-status ${_ragStatusClass(record.status)}', [
          .text(_t.localizedRagStatus(record.status)),
        ]),
        span(classes: 'studio-status status-muted', [
          .text('MSG ${record.msgId}'),
        ]),
        span(classes: 'studio-status status-muted', [
          .text('${record.role} / ${record.messageType}'),
        ]),
        span(classes: 'record-card__time', [.text(_timeLabel(record.processedAt))]),
      ]),
      div(classes: 'dashboard-split', [
        _surface(
          eyebrow: _tr('结果', 'Result'),
          title: _tr('降噪事实', 'Denoised fact'),
          copy: '',
          children: [
            _copyBlock(record.denoisedContent.isEmpty ? _tr('(空内容)', '(empty)') : record.denoisedContent),
          ],
        ),
        _surface(
          eyebrow: _tr('来源', 'Source'),
          title: _tr('源消息', 'Source content'),
          copy: '',
          children: [
            _copyBlock(record.sourceContent.isEmpty ? _tr('(空内容)', '(empty)') : record.sourceContent),
          ],
        ),
      ]),
    ]);
  }
}

String _timeLabel(String? raw) {
  if (raw == null || raw.isEmpty) {
    return AppCopy.current.nA;
  }
  final normalized = raw.replaceFirst('T', ' ');
  return normalized.length > 19 ? normalized.substring(0, 19) : normalized;
}

String _clipText(String content, int maxLength) {
  if (content.length <= maxLength) {
    return content;
  }
  return '${content.substring(0, maxLength - 3)}...';
}

bool _isTruthy(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes' || normalized == 'on';
}

String _subscriptionStatusClass(String status) {
  switch (status) {
    case 'error':
      return 'status-danger';
    case 'normal':
      return 'status-ok';
    default:
      return 'status-muted';
  }
}

String _ragStatusClass(String status) {
  switch (status) {
    case 'HEAD':
      return 'status-ok';
    case 'TAIL':
      return 'status-warn';
    case 'SKIPPED':
      return 'status-muted';
    default:
      return 'status-muted';
  }
}
