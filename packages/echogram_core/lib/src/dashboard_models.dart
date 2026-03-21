class DashboardConnection {
  const DashboardConnection({required this.apiBaseUrl, this.token});

  final String apiBaseUrl;
  final String? token;

  factory DashboardConnection.fromUri(
    Uri uri, {
    String defaultApiBaseUrl = 'http://127.0.0.1:8765/api',
  }) {
    final api =
        uri.queryParameters['api'] ??
        _resolveDefaultApiBaseUrl(uri, fallback: defaultApiBaseUrl);
    final token = uri.queryParameters['token'];
    return DashboardConnection(
      apiBaseUrl: _normalizeUrl(api),
      token: token == null || token.isEmpty ? null : token,
    );
  }

  Map<String, String> headers() {
    if (token == null || token!.isEmpty) {
      return const {};
    }
    return {'X-Echogram-Token': token!};
  }
}

String _resolveDefaultApiBaseUrl(Uri uri, {required String fallback}) {
  final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
  if (!isHttp || uri.host.isEmpty) {
    return fallback;
  }

  return '${uri.origin}/api';
}

class DashboardMeta {
  const DashboardMeta({
    required this.name,
    required this.botName,
    required this.apiBase,
    required this.uiUrl,
    required this.telegramRetainedCommands,
    required this.webFocusAreas,
  });

  final String name;
  final String botName;
  final String apiBase;
  final String? uiUrl;
  final List<String> telegramRetainedCommands;
  final List<String> webFocusAreas;

  factory DashboardMeta.fromJson(Map<String, dynamic> json) {
    return DashboardMeta(
      name: readString(json['name']),
      botName: readString(json['bot_name']),
      apiBase: readString(json['api_base']),
      uiUrl: readNullableString(json['ui_url']),
      telegramRetainedCommands: readStringList(
        json['telegram_retained_commands'],
      ),
      webFocusAreas: readStringList(json['web_focus_areas']),
    );
  }
}

class DashboardSettingsSnapshot {
  const DashboardSettingsSnapshot({
    required this.apiBaseUrl,
    required this.modelName,
    required this.summaryModelName,
    required this.vectorModelName,
    required this.mediaModel,
    required this.timezone,
    required this.historyTokens,
    required this.aggregationLatency,
    required this.activeStart,
    required this.activeEnd,
    required this.idleThresholdMinutes,
  });

  final String? apiBaseUrl;
  final String? modelName;
  final String? summaryModelName;
  final String? vectorModelName;
  final String? mediaModel;
  final String timezone;
  final int historyTokens;
  final String aggregationLatency;
  final String activeStart;
  final String activeEnd;
  final int idleThresholdMinutes;

  factory DashboardSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final activeHours = readMap(json['active_hours']);
    return DashboardSettingsSnapshot(
      apiBaseUrl: readNullableString(json['api_base_url']),
      modelName: readNullableString(json['model_name']),
      summaryModelName: readNullableString(json['summary_model_name']),
      vectorModelName: readNullableString(json['vector_model_name']),
      mediaModel: readNullableString(json['media_model']),
      timezone: readString(json['timezone'], fallback: 'UTC'),
      historyTokens: readInt(json['history_tokens']),
      aggregationLatency: readString(
        json['aggregation_latency'],
        fallback: '10.0',
      ),
      activeStart: readString(activeHours['start'], fallback: '08:00'),
      activeEnd: readString(activeHours['end'], fallback: '23:00'),
      idleThresholdMinutes: readInt(json['idle_threshold_minutes']),
    );
  }
}

class DashboardSubscriptionSnapshot {
  const DashboardSubscriptionSnapshot({
    required this.total,
    required this.active,
    required this.error,
  });

  final int total;
  final int active;
  final int error;

  factory DashboardSubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSubscriptionSnapshot(
      total: readInt(json['total']),
      active: readInt(json['active']),
      error: readInt(json['error']),
    );
  }
}

class ChatSummary {
  const ChatSummary({
    required this.chatId,
    required this.label,
    required this.chatType,
    required this.whitelisted,
    required this.lastMessageAt,
    required this.totalMessages,
    required this.summaryUpdatedAt,
  });

  final int chatId;
  final String label;
  final String chatType;
  final bool whitelisted;
  final String? lastMessageAt;
  final int totalMessages;
  final String? summaryUpdatedAt;

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      chatId: readInt(json['chat_id']),
      label: readString(json['label']),
      chatType: readString(json['chat_type']),
      whitelisted: readBool(json['whitelisted']),
      lastMessageAt: readNullableString(json['last_message_at']),
      totalMessages: readInt(json['total_messages']),
      summaryUpdatedAt: readNullableString(json['summary_updated_at']),
    );
  }
}

class DashboardOverview {
  const DashboardOverview({
    required this.meta,
    required this.settings,
    required this.subscriptions,
    required this.recentChats,
  });

  final DashboardMeta meta;
  final DashboardSettingsSnapshot settings;
  final DashboardSubscriptionSnapshot subscriptions;
  final List<ChatSummary> recentChats;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      meta: DashboardMeta.fromJson(readMap(json['meta'])),
      settings: DashboardSettingsSnapshot.fromJson(readMap(json['settings'])),
      subscriptions: DashboardSubscriptionSnapshot.fromJson(
        readMap(json['subscriptions']),
      ),
      recentChats: readList(
        json['recent_chats'],
      ).map((item) => ChatSummary.fromJson(readMap(item))).toList(),
    );
  }
}

class SessionStats {
  const SessionStats({
    required this.activeTokens,
    required this.bufferTokens,
    required this.winStartId,
    required this.totalMessages,
  });

  final int activeTokens;
  final int bufferTokens;
  final int winStartId;
  final int totalMessages;

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      activeTokens: readInt(json['active_tokens']),
      bufferTokens: readInt(json['buffer_tokens']),
      winStartId: readInt(json['win_start_id']),
      totalMessages: readInt(json['total_messages']),
    );
  }
}

class SummarySnapshot {
  const SummarySnapshot({
    required this.content,
    required this.lastSummarizedId,
    required this.updatedAt,
  });

  final String content;
  final int lastSummarizedId;
  final String? updatedAt;

  factory SummarySnapshot.fromJson(Map<String, dynamic> json) {
    return SummarySnapshot(
      content: readString(json['content'], fallback: ''),
      lastSummarizedId: readInt(json['last_summarized_id']),
      updatedAt: readNullableString(json['updated_at']),
    );
  }
}

class RagStats {
  const RagStats({
    required this.indexed,
    required this.pending,
    required this.activeWindowSize,
    required this.cooldownLeft,
  });

  final int indexed;
  final int pending;
  final int activeWindowSize;
  final int cooldownLeft;

  factory RagStats.fromJson(Map<String, dynamic> json) {
    return RagStats(
      indexed: readInt(json['indexed']),
      pending: readInt(json['pending']),
      activeWindowSize: readInt(json['active_window_size']),
      cooldownLeft: readInt(json['cooldown_left']),
    );
  }
}

class RecentMessage {
  const RecentMessage({
    required this.dbId,
    required this.messageId,
    required this.role,
    required this.messageType,
    required this.timestamp,
    required this.content,
  });

  final int dbId;
  final int? messageId;
  final String role;
  final String messageType;
  final String? timestamp;
  final String content;

  factory RecentMessage.fromJson(Map<String, dynamic> json) {
    return RecentMessage(
      dbId: readInt(json['db_id']),
      messageId: readNullableInt(json['message_id']),
      role: readString(json['role']),
      messageType: readString(json['message_type'], fallback: 'text'),
      timestamp: readNullableString(json['timestamp']),
      content: readString(
        json['content'] ?? json['content_preview'],
        fallback: '',
      ),
    );
  }
}

class RecentMessagePage {
  const RecentMessagePage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasPrev,
    required this.hasNext,
    required this.prevOffset,
    required this.nextOffset,
  });

  final List<RecentMessage> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasPrev;
  final bool hasNext;
  final int? prevOffset;
  final int? nextOffset;

  factory RecentMessagePage.fromJson(Map<String, dynamic> json) {
    return RecentMessagePage(
      items: readList(
        json['items'],
      ).map((item) => RecentMessage.fromJson(readMap(item))).toList(),
      total: readInt(json['total']),
      limit: readInt(json['limit']),
      offset: readInt(json['offset']),
      hasPrev: readBool(json['has_prev']),
      hasNext: readBool(json['has_next']),
      prevOffset: readNullableInt(json['prev_offset']),
      nextOffset: readNullableInt(json['next_offset']),
    );
  }
}

class ChatDetail {
  const ChatDetail({
    required this.chatId,
    required this.label,
    required this.chatType,
    required this.whitelisted,
    required this.historyTokens,
    required this.timezone,
    required this.sessionStats,
    required this.summary,
    required this.ragStats,
    required this.recentMessages,
  });

  final int chatId;
  final String label;
  final String chatType;
  final bool whitelisted;
  final int historyTokens;
  final String timezone;
  final SessionStats sessionStats;
  final SummarySnapshot summary;
  final RagStats ragStats;
  final List<RecentMessage> recentMessages;

  factory ChatDetail.fromJson(Map<String, dynamic> json) {
    final settings = readMap(json['settings']);
    return ChatDetail(
      chatId: readInt(json['chat_id']),
      label: readString(json['label']),
      chatType: readString(json['chat_type']),
      whitelisted: readBool(json['whitelisted']),
      historyTokens: readInt(settings['history_tokens']),
      timezone: readString(settings['timezone'], fallback: 'UTC'),
      sessionStats: SessionStats.fromJson(readMap(json['session_stats'])),
      summary: SummarySnapshot.fromJson(readMap(json['summary'])),
      ragStats: RagStats.fromJson(readMap(json['rag_stats'])),
      recentMessages: readList(
        json['recent_messages'],
      ).map((item) => RecentMessage.fromJson(readMap(item))).toList(),
    );
  }
}

class PromptPreview {
  const PromptPreview({
    required this.chatId,
    required this.chatLabel,
    required this.timezone,
    required this.lastMessageType,
    required this.generatedAt,
    required this.systemProtocol,
    required this.memoryContext,
  });

  final int chatId;
  final String chatLabel;
  final String timezone;
  final String lastMessageType;
  final String? generatedAt;
  final String systemProtocol;
  final String memoryContext;

  factory PromptPreview.fromJson(Map<String, dynamic> json) {
    return PromptPreview(
      chatId: readInt(json['chat_id']),
      chatLabel: readString(json['chat_label']),
      timezone: readString(json['timezone'], fallback: 'UTC'),
      lastMessageType: readString(json['last_message_type'], fallback: 'text'),
      generatedAt: readNullableString(json['generated_at']),
      systemProtocol: readString(json['system_protocol'], fallback: ''),
      memoryContext: readString(json['memory_context'], fallback: ''),
    );
  }
}

class RagRecord {
  const RagRecord({
    required this.msgId,
    required this.status,
    required this.processedAt,
    required this.denoisedContent,
    required this.role,
    required this.messageType,
    required this.sourceContent,
  });

  final int msgId;
  final String status;
  final String? processedAt;
  final String denoisedContent;
  final String role;
  final String messageType;
  final String sourceContent;

  factory RagRecord.fromJson(Map<String, dynamic> json) {
    return RagRecord(
      msgId: readInt(json['msg_id']),
      status: readString(json['status']),
      processedAt: readNullableString(json['processed_at']),
      denoisedContent: readString(json['denoised_content'], fallback: ''),
      role: readString(json['role'], fallback: 'unknown'),
      messageType: readString(json['message_type'], fallback: 'text'),
      sourceContent: readString(
        json['source_content'] ?? json['source_preview'],
        fallback: '',
      ),
    );
  }
}

class RagRecordPage {
  const RagRecordPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasPrev,
    required this.hasNext,
    required this.prevOffset,
    required this.nextOffset,
  });

  final List<RagRecord> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasPrev;
  final bool hasNext;
  final int? prevOffset;
  final int? nextOffset;

  factory RagRecordPage.fromJson(Map<String, dynamic> json) {
    return RagRecordPage(
      items: readList(
        json['items'],
      ).map((item) => RagRecord.fromJson(readMap(item))).toList(),
      total: readInt(json['total']),
      limit: readInt(json['limit']),
      offset: readInt(json['offset']),
      hasPrev: readBool(json['has_prev']),
      hasNext: readBool(json['has_next']),
      prevOffset: readNullableInt(json['prev_offset']),
      nextOffset: readNullableInt(json['next_offset']),
    );
  }
}

class LogSnapshot {
  const LogSnapshot({
    required this.path,
    required this.content,
    required this.truncated,
  });

  final String path;
  final String content;
  final bool truncated;

  factory LogSnapshot.fromJson(Map<String, dynamic> json) {
    return LogSnapshot(
      path: readString(json['path'], fallback: ''),
      content: readString(json['content'], fallback: ''),
      truncated: readBool(json['truncated']),
    );
  }
}

class SubscriptionRecord {
  const SubscriptionRecord({
    required this.id,
    required this.name,
    required this.route,
    required this.isActive,
    required this.status,
    required this.targetCount,
    required this.lastPublishTime,
    required this.lastCheckTime,
    required this.lastError,
    required this.errorCount,
  });

  final int id;
  final String name;
  final String route;
  final bool isActive;
  final String status;
  final int targetCount;
  final String? lastPublishTime;
  final String? lastCheckTime;
  final String? lastError;
  final int errorCount;

  factory SubscriptionRecord.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecord(
      id: readInt(json['id']),
      name: readString(json['name']),
      route: readString(json['route']),
      isActive: readBool(json['is_active']),
      status: readString(json['status'], fallback: 'unknown'),
      targetCount: readInt(json['target_count']),
      lastPublishTime: readNullableString(json['last_publish_time']),
      lastCheckTime: readNullableString(json['last_check_time']),
      lastError: readNullableString(json['last_error']),
      errorCount: readInt(json['error_count']),
    );
  }
}

class DashboardExtensionTool {
  const DashboardExtensionTool({
    required this.name,
    required this.description,
    required this.readOnly,
  });

  final String name;
  final String description;
  final bool readOnly;

  factory DashboardExtensionTool.fromJson(Map<String, dynamic> json) {
    return DashboardExtensionTool(
      name: readString(json['name']),
      description: readString(json['description'], fallback: ''),
      readOnly: readBool(json['read_only'], fallback: true),
    );
  }
}

class DashboardExtensionTriggerMatch {
  const DashboardExtensionTriggerMatch({
    required this.urlDomains,
    required this.keywords,
    required this.regexPatterns,
  });

  final List<String> urlDomains;
  final List<String> keywords;
  final List<String> regexPatterns;

  factory DashboardExtensionTriggerMatch.fromJson(Map<String, dynamic> json) {
    return DashboardExtensionTriggerMatch(
      urlDomains: readStringList(json['url_domains']),
      keywords: readStringList(json['keywords']),
      regexPatterns: readStringList(json['regex']),
    );
  }
}

class DashboardExtensionTrigger {
  const DashboardExtensionTrigger({
    required this.name,
    required this.type,
    required this.description,
    required this.scopes,
    required this.schedule,
    required this.match,
  });

  final String name;
  final String type;
  final String description;
  final List<String> scopes;
  final String schedule;
  final DashboardExtensionTriggerMatch match;

  factory DashboardExtensionTrigger.fromJson(Map<String, dynamic> json) {
    return DashboardExtensionTrigger(
      name: readString(json['name']),
      type: readString(json['type']),
      description: readString(json['description'], fallback: ''),
      scopes: readStringList(json['scopes']),
      schedule: readString(json['schedule'], fallback: ''),
      match: DashboardExtensionTriggerMatch.fromJson(readMap(json['match'])),
    );
  }
}

class DashboardExtensionConfigField {
  const DashboardExtensionConfigField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.secret,
    required this.help,
    required this.placeholder,
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final bool secret;
  final String help;
  final String placeholder;

  factory DashboardExtensionConfigField.fromJson(Map<String, dynamic> json) {
    return DashboardExtensionConfigField(
      key: readString(json['key']),
      label: readString(json['label']),
      type: readString(json['type'], fallback: 'text'),
      required: readBool(json['required']),
      secret: readBool(json['secret']),
      help: readString(json['help'], fallback: ''),
      placeholder: readString(json['placeholder'], fallback: ''),
    );
  }
}

class DashboardExtensionPanel {
  const DashboardExtensionPanel({
    required this.slot,
    required this.kind,
    required this.title,
  });

  final String slot;
  final String kind;
  final String title;

  factory DashboardExtensionPanel.fromJson(Map<String, dynamic> json) {
    return DashboardExtensionPanel(
      slot: readString(json['slot']),
      kind: readString(json['kind']),
      title: readString(json['title'], fallback: ''),
    );
  }
}

class DashboardExtension {
  const DashboardExtension({
    required this.id,
    required this.name,
    required this.version,
    required this.purpose,
    required this.description,
    required this.author,
    required this.homepage,
    required this.sourceType,
    required this.status,
    required this.installed,
    required this.enabled,
    required this.localPath,
    required this.permissions,
    required this.tools,
    required this.triggers,
    required this.configFields,
    required this.dashboardPanels,
    required this.hasRuntime,
    required this.runtimeScriptPath,
    required this.configValueCount,
    required this.recordCount,
    required this.latestRecordAt,
  });

  final String id;
  final String name;
  final String version;
  final String purpose;
  final String description;
  final String author;
  final String homepage;
  final String sourceType;
  final String status;
  final bool installed;
  final bool enabled;
  final String localPath;
  final List<String> permissions;
  final List<DashboardExtensionTool> tools;
  final List<DashboardExtensionTrigger> triggers;
  final List<DashboardExtensionConfigField> configFields;
  final List<DashboardExtensionPanel> dashboardPanels;
  final bool hasRuntime;
  final String? runtimeScriptPath;
  final int configValueCount;
  final int recordCount;
  final String? latestRecordAt;

  factory DashboardExtension.fromJson(Map<String, dynamic> json) {
    return DashboardExtension(
      id: readString(json['id']),
      name: readString(json['name']),
      version: readString(json['version'], fallback: '0.0.0'),
      purpose: readString(json['purpose'], fallback: ''),
      description: readString(json['description'], fallback: ''),
      author: readString(json['author'], fallback: ''),
      homepage: readString(json['homepage'], fallback: ''),
      sourceType: readString(json['source_type'], fallback: 'local_dir'),
      status: readString(json['status'], fallback: 'discovered'),
      installed: readBool(json['installed'], fallback: false),
      enabled: readBool(json['enabled'], fallback: false),
      localPath: readString(json['local_path'], fallback: ''),
      permissions: readStringList(json['permissions']),
      tools: readList(
        json['tools'],
      ).map((item) => DashboardExtensionTool.fromJson(readMap(item))).toList(),
      triggers: readList(json['triggers'])
          .map((item) => DashboardExtensionTrigger.fromJson(readMap(item)))
          .toList(),
      configFields: readList(json['config_fields'])
          .map((item) => DashboardExtensionConfigField.fromJson(readMap(item)))
          .toList(),
      dashboardPanels: readList(
        json['dashboard_panels'],
      ).map((item) => DashboardExtensionPanel.fromJson(readMap(item))).toList(),
      hasRuntime: readBool(json['has_runtime']),
      runtimeScriptPath: readNullableString(json['runtime_script_path']),
      configValueCount: readInt(json['config_value_count']),
      recordCount: readInt(json['record_count']),
      latestRecordAt: readNullableString(json['latest_record_at']),
    );
  }
}

class ExtensionConfigFieldState {
  const ExtensionConfigFieldState({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.secret,
    required this.help,
    required this.placeholder,
    required this.value,
    required this.hasValue,
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final bool secret;
  final String help;
  final String placeholder;
  final String value;
  final bool hasValue;

  factory ExtensionConfigFieldState.fromJson(Map<String, dynamic> json) {
    return ExtensionConfigFieldState(
      key: readString(json['key']),
      label: readString(json['label']),
      type: readString(json['type'], fallback: 'text'),
      required: readBool(json['required']),
      secret: readBool(json['secret']),
      help: readString(json['help'], fallback: ''),
      placeholder: readString(json['placeholder'], fallback: ''),
      value: readString(json['value'], fallback: ''),
      hasValue: readBool(json['has_value']),
    );
  }
}

class ExtensionConfigState {
  const ExtensionConfigState({
    required this.scopeType,
    required this.fields,
    required this.unknownKeys,
  });

  final String scopeType;
  final List<ExtensionConfigFieldState> fields;
  final List<String> unknownKeys;

  factory ExtensionConfigState.fromJson(Map<String, dynamic> json) {
    return ExtensionConfigState(
      scopeType: readString(json['scope_type'], fallback: 'global'),
      fields: readList(json['fields'])
          .map((item) => ExtensionConfigFieldState.fromJson(readMap(item)))
          .toList(),
      unknownKeys: readStringList(json['unknown_keys']),
    );
  }
}

class ExtensionRecordPreview {
  const ExtensionRecordPreview({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.recordType,
    required this.recordKey,
    required this.title,
    required this.contentPreview,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  final int id;
  final String scopeType;
  final int scopeId;
  final String recordType;
  final String? recordKey;
  final String? title;
  final String contentPreview;
  final String? createdAt;
  final String? updatedAt;
  final String? expiresAt;

  factory ExtensionRecordPreview.fromJson(Map<String, dynamic> json) {
    return ExtensionRecordPreview(
      id: readInt(json['id']),
      scopeType: readString(json['scope_type'], fallback: 'global'),
      scopeId: readInt(json['scope_id']),
      recordType: readString(json['record_type']),
      recordKey: readNullableString(json['record_key']),
      title: readNullableString(json['title']),
      contentPreview: readString(json['content_preview'], fallback: ''),
      createdAt: readNullableString(json['created_at']),
      updatedAt: readNullableString(json['updated_at']),
      expiresAt: readNullableString(json['expires_at']),
    );
  }
}

class ExtensionTriggerRunState {
  const ExtensionTriggerRunState({
    required this.id,
    required this.triggerName,
    required this.lastRunAt,
    required this.lastStatus,
    required this.lastError,
    required this.updatedAt,
  });

  final int id;
  final String triggerName;
  final String? lastRunAt;
  final String lastStatus;
  final String? lastError;
  final String? updatedAt;

  factory ExtensionTriggerRunState.fromJson(Map<String, dynamic> json) {
    return ExtensionTriggerRunState(
      id: readInt(json['id']),
      triggerName: readString(json['trigger_name']),
      lastRunAt: readNullableString(json['last_run_at']),
      lastStatus: readString(json['last_status'], fallback: 'unknown'),
      lastError: readNullableString(json['last_error']),
      updatedAt: readNullableString(json['updated_at']),
    );
  }
}

class ExtensionRuntimeState {
  const ExtensionRuntimeState({
    required this.hasScript,
    required this.scriptPath,
  });

  final bool hasScript;
  final String? scriptPath;

  factory ExtensionRuntimeState.fromJson(Map<String, dynamic> json) {
    return ExtensionRuntimeState(
      hasScript: readBool(json['has_script']),
      scriptPath: readNullableString(json['script_path']),
    );
  }
}

class ExtensionDetail {
  const ExtensionDetail({
    required this.extension,
    required this.runtime,
    required this.config,
    required this.records,
    required this.triggerRuns,
  });

  final DashboardExtension extension;
  final ExtensionRuntimeState runtime;
  final ExtensionConfigState config;
  final List<ExtensionRecordPreview> records;
  final List<ExtensionTriggerRunState> triggerRuns;

  factory ExtensionDetail.fromJson(Map<String, dynamic> json) {
    return ExtensionDetail(
      extension: DashboardExtension.fromJson(readMap(json['extension'])),
      runtime: ExtensionRuntimeState.fromJson(readMap(json['runtime'])),
      config: ExtensionConfigState.fromJson(readMap(json['config'])),
      records: readList(
        json['records'],
      ).map((item) => ExtensionRecordPreview.fromJson(readMap(item))).toList(),
      triggerRuns: readList(json['trigger_runs'])
          .map((item) => ExtensionTriggerRunState.fromJson(readMap(item)))
          .toList(),
    );
  }
}

class ExtensionImportMethod {
  const ExtensionImportMethod({
    required this.id,
    required this.label,
    required this.description,
    required this.recommended,
    required this.enabled,
  });

  final String id;
  final String label;
  final String description;
  final bool recommended;
  final bool enabled;

  factory ExtensionImportMethod.fromJson(Map<String, dynamic> json) {
    return ExtensionImportMethod(
      id: readString(json['id']),
      label: readString(json['label']),
      description: readString(json['description'], fallback: ''),
      recommended: readBool(json['recommended']),
      enabled: readBool(json['enabled'], fallback: true),
    );
  }
}

class ExtensionCatalog {
  const ExtensionCatalog({
    required this.items,
    required this.importMethods,
    required this.recommendedIndexUrl,
    required this.extensionsDir,
  });

  final List<DashboardExtension> items;
  final List<ExtensionImportMethod> importMethods;
  final String? recommendedIndexUrl;
  final String extensionsDir;

  factory ExtensionCatalog.fromJson(Map<String, dynamic> json) {
    return ExtensionCatalog(
      items: readList(
        json['items'],
      ).map((item) => DashboardExtension.fromJson(readMap(item))).toList(),
      importMethods: readList(
        json['import_methods'],
      ).map((item) => ExtensionImportMethod.fromJson(readMap(item))).toList(),
      recommendedIndexUrl: readNullableString(json['recommended_index_url']),
      extensionsDir: readString(json['extensions_dir'], fallback: ''),
    );
  }
}

class ExtensionInstallResult {
  const ExtensionInstallResult({
    required this.ok,
    required this.method,
    required this.message,
    required this.extension,
  });

  final bool ok;
  final String method;
  final String message;
  final DashboardExtension extension;

  factory ExtensionInstallResult.fromJson(Map<String, dynamic> json) {
    return ExtensionInstallResult(
      ok: readBool(json['ok'], fallback: false),
      method: readString(json['method'], fallback: ''),
      message: readString(json['message'], fallback: ''),
      extension: DashboardExtension.fromJson(readMap(json['extension'])),
    );
  }
}

String _normalizeUrl(String value) {
  if (value.endsWith('/')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

Map<String, dynamic> readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic entry) => MapEntry(key.toString(), entry));
  }
  return const {};
}

List<dynamic> readList(Object? value) {
  return value is List ? value : const [];
}

List<String> readStringList(Object? value) {
  return readList(value).map((item) => item.toString()).toList();
}

String readString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

String? readNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? readNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

bool readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return fallback;
}
