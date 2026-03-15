import 'package:echogram_core/echogram_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../i18n/app_copy.dart';

class DashboardPage extends StatefulComponent {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  late final DashboardConnection _connection;
  late final DashboardApiClient _client;
  int? _requestedChatId;

  DashboardOverview? _overview;
  List<ChatSummary> _chats = const [];
  List<SubscriptionRecord> _subscriptions = const [];
  ChatDetail? _chatDetail;
  PromptPreview? _promptPreview;
  List<RagRecord> _ragRecords = const [];
  LogSnapshot? _logs;

  int? _selectedChatId;
  bool _loading = true;
  bool _loadingChat = false;
  bool _loadingLogs = true;
  String? _error;
  String? _logsError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _connection = DashboardConnection.fromUri(Uri.base);
    _client = DashboardApiClient(connection: _connection);
    _requestedChatId = int.tryParse(Uri.base.queryParameters['chat'] ?? '');
    _loadDashboard();
    _loadLogs();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final overview = await _client.getOverview();
      final chats = await _client.getChats();
      final subscriptions = await _client.getSubscriptions();

      setState(() {
        _overview = overview;
        _chats = chats;
        _subscriptions = subscriptions;
        _loading = false;
      });

      final seedChatId = _requestedChatId ?? (chats.isNotEmpty ? chats.first.chatId : null);
      if (seedChatId != null) {
        await _selectChat(seedChatId, quiet: true);
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectChat(int chatId, {bool quiet = false}) async {
    setState(() {
      _selectedChatId = chatId;
      _loadingChat = true;
      if (!quiet) {
        _notice = null;
      }
    });

    try {
      final detail = await _client.getChat(chatId);
      final promptPreview = await _client.getPromptPreview(chatId);
      final ragRecords = await _client.getRagRecords(chatId);

      setState(() {
        _chatDetail = detail;
        _promptPreview = promptPreview;
        _ragRecords = ragRecords;
        _loadingChat = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loadingChat = false;
      });
    }
  }

  Future<void> _rebuildRag() async {
    final chatId = _selectedChatId;
    if (chatId == null) {
      return;
    }

    setState(() {
      _notice = AppCopy.current.rebuildingRagNotice(chatId);
    });

    try {
      await _client.rebuildRag(chatId);
      await _selectChat(chatId, quiet: true);
      setState(() {
        _notice = AppCopy.current.rebuiltRagNotice;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
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
        _logsError = error.toString();
        _loadingLogs = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final overview = _overview;
    final connected = overview != null;
    final t = AppCopy.current;

    return div(classes: 'space-y-6', [
      if (_error != null)
        div(classes: 'alert alert-error shell-glass', [
          span([.text(_error!)]),
        ]),
      if (_notice != null)
        div(classes: 'alert alert-info shell-glass', [
          span([.text(_notice!)]),
        ]),
      div(classes: 'grid gap-4 xl:grid-cols-[1.4fr_1fr]', [
        _panel(
          eyebrow: t.dashboardEyebrow,
          title: connected ? t.dashboardConnectedTitle : t.dashboardOfflineTitle,
          body: [
            p(classes: 'text-sm leading-7 text-slate-600 dark:text-slate-300', [
              .text(connected ? t.dashboardConnectedBody : t.dashboardOfflineBody),
            ]),
            div(classes: 'mt-5 flex flex-wrap gap-3', [
              _pill(t.apiLabel, _connection.apiBaseUrl),
              _pill(t.stateLabel, connected ? t.stateConnected : (_loading ? t.stateConnecting : t.stateOfflineUi)),
              if (overview != null) _pill(t.botLabel, overview.meta.botName),
              if (_connection.token != null) _pill(t.authLabel, t.authAttached),
            ]),
          ],
        ),
        div(classes: 'grid gap-4 md:grid-cols-3 xl:grid-cols-1', [
          _metricCard(t.recentChatsMetric, '${_chats.length}', t.recentChatsMetricHint),
          _metricCard(
            t.subscriptionsMetric,
            '${overview?.subscriptions.active ?? 0}/${overview?.subscriptions.total ?? 0}',
            t.subscriptionMetricHint(overview?.subscriptions.error ?? 0),
          ),
          _metricCard(
            t.historyWindowMetric,
            '${overview?.settings.historyTokens ?? 0}',
            t.historyWindowMetricHint,
          ),
        ]),
      ]),
      div(classes: 'echo-grid', [
        div(classes: 'space-y-4', [
          _panel(
            eyebrow: t.chatsEyebrow,
            title: t.chatsTitle,
            body: [
              if (_chats.isEmpty)
                _emptyCard(t.chatsEmpty)
              else
                div(classes: 'mt-1 flex flex-col gap-2', [
                  for (final chat in _chats)
                    button(
                      classes: _selectedChatId == chat.chatId
                          ? 'btn h-auto justify-start rounded-2xl border-0 bg-slate-900 px-4 py-4 text-left text-white shadow-lg hover:bg-slate-800 dark:bg-teal-400 dark:text-slate-950 dark:hover:bg-teal-300'
                          : 'btn h-auto justify-start rounded-2xl border-0 bg-white/85 px-4 py-4 text-left text-slate-700 shadow-md hover:bg-white dark:bg-slate-900/75 dark:text-slate-200 dark:shadow-none dark:hover:bg-slate-800',
                      onClick: () => _selectChat(chat.chatId),
                      [
                        div(classes: 'flex w-full flex-col gap-2', [
                          div(classes: 'flex items-center justify-between gap-3', [
                            span(classes: 'font-semibold', [.text(chat.label)]),
                            span(
                              classes: chat.whitelisted
                                  ? 'badge badge-success badge-sm'
                                  : 'badge badge-outline badge-sm',
                              [.text(t.localizedChatType(chat.chatType))],
                            ),
                          ]),
                          div(classes: 'flex items-center justify-between text-xs opacity-80', [
                            span([.text(t.messagesCount(chat.totalMessages))]),
                            span([.text(_timeLabel(chat.lastMessageAt))]),
                          ]),
                        ]),
                      ],
                    ),
                ]),
            ],
          ),
          _panel(
            eyebrow: t.subscriptionsEyebrow,
            title: t.subscriptionsTitle,
            body: [
              if (_subscriptions.isEmpty)
                _emptyCard(t.subscriptionsEmpty)
              else
                div(classes: 'mt-2 space-y-3', [
                  for (final subscription in _subscriptions.take(6))
                    div(
                      classes:
                          'rounded-2xl border border-slate-200/70 bg-white/75 p-4 dark:border-slate-700/70 dark:bg-slate-900/75',
                      [
                        div(classes: 'flex items-start justify-between gap-3', [
                          div(classes: 'space-y-1', [
                            div(classes: 'font-semibold text-slate-900 dark:text-white', [.text(subscription.name)]),
                            div(classes: 'text-xs text-slate-500 dark:text-slate-400', [.text(subscription.route)]),
                          ]),
                          span(
                            classes: _subscriptionBadge(subscription.status),
                            [.text(t.localizedSubscriptionStatus(subscription.status))],
                          ),
                        ]),
                        div(classes: 'mt-3 flex flex-wrap gap-3 text-xs text-slate-500 dark:text-slate-400', [
                          span([.text(t.targetsCount(subscription.targetCount))]),
                          span([.text(t.errorsCount(subscription.errorCount))]),
                        ]),
                        if (subscription.lastError != null && subscription.lastError!.isNotEmpty)
                          p(classes: 'mt-3 text-sm leading-6 text-amber-700 dark:text-amber-300', [
                            .text(subscription.lastError!),
                          ]),
                      ],
                    ),
                ]),
            ],
          ),
        ]),
        div(classes: 'space-y-4', [
          if (_loadingChat)
            _panel(
              eyebrow: t.loadingEyebrow,
              title: t.loadingFocusTitle,
              body: [
                div(classes: 'mt-3 flex items-center gap-3 text-sm text-slate-600 dark:text-slate-300', [
                  span(classes: 'loading loading-spinner loading-sm', const []),
                  span([.text(t.loadingFocusBody)]),
                ]),
              ],
            )
          else if (_chatDetail == null)
            _panel(
              eyebrow: t.focusEyebrow,
              title: connected ? t.focusOnlineTitle : t.focusOfflineTitle,
              body: [
                p(classes: 'text-sm leading-7 text-slate-600 dark:text-slate-300', [
                  .text(connected ? t.focusOnlineBody : t.focusOfflineBody),
                ]),
              ],
            )
          else
            _buildChatFocus(_chatDetail!),
        ]),
      ]),
      _panel(
        eyebrow: t.logsEyebrow,
        title: t.logsTitle,
        body: [
          div(classes: 'mt-3 flex flex-wrap items-center gap-3', [
            button(
              classes:
                  'btn btn-sm border-0 bg-slate-900 text-white shadow-lg hover:bg-slate-800 dark:bg-teal-400 dark:text-slate-950 dark:shadow-none dark:hover:bg-teal-300',
              onClick: _loadLogs,
              [
                if (_loadingLogs) span(classes: 'loading loading-spinner loading-xs', const []),
                span([.text(t.refreshLogs)]),
              ],
            ),
            if (_logs?.truncated == true) _pill(t.stateLabel, t.logTailTruncated),
            if (_logs != null && _logs!.path.isNotEmpty) _pill(t.pathLabel, _logs!.path),
          ]),
          if (_logsError != null)
            div(classes: 'alert alert-warning mt-4 shell-glass', [
              span([.text(_logsError!)]),
            ]),
          if (_loadingLogs && _logs == null)
            _emptyCard(t.logsWaiting)
          else
            pre(classes: 'shell-code mt-4 overflow-x-auto rounded-[1.75rem] p-5 text-[12px] leading-6 shadow-xl', [
              .text(_logs?.content.isEmpty == true ? t.logEmpty : _logs?.content ?? t.logsUnavailable),
            ]),
        ],
      ),
    ]);
  }

  Component _buildChatFocus(ChatDetail detail) {
    final t = AppCopy.current;

    return div(classes: 'space-y-4', [
      _panel(
        eyebrow: t.selectedChatEyebrow,
        title: detail.label,
        body: [
          div(classes: 'mt-1 flex flex-wrap gap-3 text-sm text-slate-600 dark:text-slate-300', [
            _pill(t.typeLabel, t.localizedChatType(detail.chatType)),
            _pill(t.timezoneLabel, detail.timezone),
            _pill(t.whitelistLabel, detail.whitelisted ? t.whitelistEnabled : t.whitelistDisabled),
          ]),
          div(classes: 'mt-5 grid gap-4 md:grid-cols-4', [
            _metricCard(t.activeTokensMetric, '${detail.sessionStats.activeTokens}', t.activeTokensHint),
            _metricCard(t.bufferTokensMetric, '${detail.sessionStats.bufferTokens}', t.bufferTokensHint),
            _metricCard(t.ragIndexedMetric, '${detail.ragStats.indexed}', t.ragIndexedHint(detail.ragStats.pending)),
            _metricCard(
              t.messagesMetric,
              '${detail.sessionStats.totalMessages}',
              t.messagesMetricHint(detail.sessionStats.winStartId),
            ),
          ]),
          div(classes: 'mt-5 flex flex-wrap gap-2', [
            button(
              classes:
                  'btn btn-sm border-0 bg-slate-900 text-white shadow-lg hover:bg-slate-800 dark:bg-teal-400 dark:text-slate-950 dark:shadow-none dark:hover:bg-teal-300',
              onClick: _loadDashboard,
              [
                .text(t.refreshAll),
              ],
            ),
            button(
              classes:
                  'btn btn-sm border-0 bg-orange-500 text-white shadow-lg hover:bg-orange-600 dark:bg-orange-400 dark:text-slate-950 dark:shadow-none dark:hover:bg-orange-300',
              onClick: _rebuildRag,
              [
                .text(t.rebuildRag),
              ],
            ),
          ]),
        ],
      ),
      div(classes: 'grid gap-4 xl:grid-cols-[0.95fr_1.05fr]', [
        _panel(
          eyebrow: t.summaryEyebrow,
          title: t.summaryTitle,
          body: [
            div(
              classes:
                  'mt-2 rounded-[1.5rem] bg-white/75 p-4 text-sm leading-7 text-slate-700 dark:bg-slate-900/75 dark:text-slate-200',
              [
                .text(detail.summary.content.isEmpty ? t.summaryEmpty : detail.summary.content),
              ],
            ),
            div(classes: 'mt-3 flex flex-wrap gap-3 text-xs text-slate-500 dark:text-slate-400', [
              span([.text(t.lastSummarizedId(detail.summary.lastSummarizedId))]),
              span([.text(_timeLabel(detail.summary.updatedAt))]),
            ]),
          ],
        ),
        _panel(
          eyebrow: t.recentMessagesEyebrow,
          title: t.recentMessagesTitle,
          body: [
            if (detail.recentMessages.isEmpty)
              _emptyCard(t.logsUnavailable)
            else
              div(classes: 'mt-2 space-y-3', [
                for (final message in detail.recentMessages.take(8))
                  div(
                    classes:
                        'rounded-[1.5rem] border border-slate-200/70 bg-white/80 p-4 dark:border-slate-700/70 dark:bg-slate-900/75',
                    [
                      div(
                        classes:
                            'flex items-center justify-between gap-3 text-xs uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400',
                        [
                          span([.text('${message.role} / ${message.messageType}')]),
                          span([.text(_timeLabel(message.timestamp))]),
                        ],
                      ),
                      p(classes: 'mt-3 text-sm leading-7 text-slate-700 dark:text-slate-200', [
                        .text(message.contentPreview),
                      ]),
                    ],
                  ),
              ]),
          ],
        ),
      ]),
      _panel(
        eyebrow: t.promptEyebrow,
        title: _promptPreview?.chatLabel ?? t.promptFallbackTitle,
        body: [
          div(classes: 'mt-2 grid gap-4 xl:grid-cols-2', [
            _codeCard(t.systemProtocol, _promptPreview?.systemProtocol ?? t.noPromptYet),
            _codeCard(t.dynamicMemory, _promptPreview?.memoryContext ?? t.noMemoryYet),
          ]),
        ],
      ),
      _panel(
        eyebrow: t.ragEyebrow,
        title: t.ragTitle,
        body: [
          div(classes: 'mt-2 space-y-3', [
            if (_ragRecords.isEmpty) _emptyCard(t.ragEmpty),
            for (final record in _ragRecords.take(10))
              div(
                classes:
                    'rounded-[1.5rem] border border-slate-200/70 bg-white/80 p-4 dark:border-slate-700/70 dark:bg-slate-900/75',
                [
                  div(classes: 'flex flex-wrap items-center gap-2', [
                    span(classes: 'badge badge-outline badge-sm', [.text('MSG ${record.msgId}')]),
                    span(classes: _ragBadge(record.status), [.text(t.localizedRagStatus(record.status))]),
                    span(classes: 'text-xs text-slate-500 dark:text-slate-400', [
                      .text(_timeLabel(record.processedAt)),
                    ]),
                  ]),
                  div(classes: 'mt-3 grid gap-4 xl:grid-cols-2', [
                    div(classes: 'space-y-2', [
                      div(
                        classes: 'text-xs font-semibold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400',
                        [.text(t.denoisedFact)],
                      ),
                      p(classes: 'text-sm leading-7 text-slate-700 dark:text-slate-200', [
                        .text(record.denoisedContent.isEmpty ? t.emptyLabel : record.denoisedContent),
                      ]),
                    ]),
                    div(classes: 'space-y-2', [
                      div(
                        classes: 'text-xs font-semibold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400',
                        [.text(t.sourcePreview)],
                      ),
                      p(classes: 'text-sm leading-7 text-slate-700 dark:text-slate-200', [
                        .text(record.sourcePreview),
                      ]),
                    ]),
                  ]),
                ],
              ),
          ]),
        ],
      ),
    ]);
  }
}

Component _panel({
  required String eyebrow,
  required String title,
  required List<Component> body,
}) {
  return div(classes: 'shell-glass rounded-[2rem] px-5 py-5 lg:px-6 lg:py-6', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.24em] text-teal-700 dark:text-teal-300', [.text(eyebrow)]),
    h2(classes: 'mt-3 text-xl font-bold tracking-tight text-slate-900 dark:text-white lg:text-2xl', [.text(title)]),
    ...body,
  ]);
}

Component _metricCard(String label, String value, String detail) {
  return div(classes: 'shell-glass rounded-[1.75rem] px-5 py-5', [
    div(classes: 'text-xs font-bold uppercase tracking-[0.20em] text-slate-500 dark:text-slate-400', [.text(label)]),
    div(classes: 'mt-2 text-3xl font-bold tracking-tight text-slate-900 dark:text-white', [.text(value)]),
    p(classes: 'mt-2 text-sm leading-6 text-slate-600 dark:text-slate-300', [.text(detail)]),
  ]);
}

Component _pill(String label, String value) {
  return div(
    classes:
        'rounded-full bg-slate-900 px-3 py-1 text-xs font-medium text-white shadow-lg dark:bg-white dark:text-slate-950 dark:shadow-none',
    [
      .text('$label: $value'),
    ],
  );
}

Component _codeCard(String title, String content) {
  return div(classes: 'space-y-2', [
    div(classes: 'text-xs font-semibold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400', [
      .text(title),
    ]),
    pre(classes: 'shell-code overflow-x-auto rounded-[1.5rem] p-4 text-[12px] leading-6 shadow-xl', [
      .text(content),
    ]),
  ]);
}

Component _emptyCard(String copy) {
  return div(
    classes:
        'mt-3 rounded-[1.5rem] bg-white/80 p-4 text-sm leading-7 text-slate-600 dark:bg-slate-900/75 dark:text-slate-300',
    [
      .text(copy),
    ],
  );
}

String _timeLabel(String? raw) {
  final t = AppCopy.current;
  if (raw == null || raw.isEmpty) {
    return t.nA;
  }
  final normalized = raw.replaceFirst('T', ' ');
  return normalized.length > 19 ? normalized.substring(0, 19) : normalized;
}

String _subscriptionBadge(String status) {
  switch (status) {
    case 'error':
      return 'badge badge-error badge-sm';
    case 'normal':
      return 'badge badge-success badge-sm';
    default:
      return 'badge badge-outline badge-sm';
  }
}

String _ragBadge(String status) {
  switch (status) {
    case 'HEAD':
      return 'badge badge-success badge-sm';
    case 'TAIL':
      return 'badge badge-warning badge-sm';
    case 'SKIPPED':
      return 'badge badge-neutral badge-sm';
    default:
      return 'badge badge-outline badge-sm';
  }
}
