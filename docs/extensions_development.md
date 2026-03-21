# Echogram Extensions Development

## 术语

- 单个实体、类型、实例统一用 `Extension`
- 集合、系统、页面、路由资源统一用 `Extensions`
- 本地目录和 API 路由统一用 `extensions/`、`/api/extensions`

## 当前已经具备的能力

- `extensions/` 目录发现与 `manifest.json` 解析
- `extension.py` 运行时加载
- Dashboard 中的 `Extensions` 列表、详情、启用/停用、配置保存
- 通过仓库 URL 或本地 ZIP 导入 Extension
- 触发器与作用域声明
- 命中触发器后自动注入提示词
- 命中触发器后为当前轮次注册工具，并在 tool call 时执行
- `global_scheduled` 定时调度
- Extension 私有数据库存储
- 受控摘要 helper：`context.summary`
- 受控多模态 helper：`context.media`
- 示例 Extension：`extensions/bilibili`

## 最小目录结构

只可发现：

```text
extensions/
  my_extension/
    manifest.json
```

可运行：

```text
extensions/
  my_extension/
    manifest.json
    extension.py
```

推荐结构：

```text
extensions/
  my_extension/
    manifest.json
    extension.py
    helper_module.py
    README.md
    assets/
```

说明：

- 只有 `manifest.json` 时，Dashboard 能发现这个 Extension
- 同时存在 `manifest.json` 和 `extension.py` 时，运行时才会加载代码
- 如果逻辑较复杂，推荐像 `extensions/bilibili` 一样拆出辅助模块，而不是把所有代码塞进一个文件

## Manifest 约定

当前实现对应 [manifest.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/extensions/manifest.py)。

### 基础字段

- `id`
- `name`
- `version`
- `purpose`
- `description`
- `author`
- `homepage`
- `enabled`

### 权限字段

`permissions` 用来声明 Extension 需要的能力边界。

当前推荐使用：

- `network:http`
- `network:https`
- `llm:summary`
- `llm:multimodal`
- `file:read`
- `file:write`
- `subprocess:restricted`
- `mcp:client`

其中当前已经有运行时约束的是：

- `llm:summary`
  - 允许调用 `context.summary`
- `llm:multimodal`
  - 允许调用 `context.media`

### 工具字段

`tools` 只负责声明用途，真正的 OpenAI-style 工具定义仍由 `extension.py` 的 `get_tools(context)` 返回。

当前声明层支持：

- `name`
- `description`
- `read_only`

### 触发器字段

`triggers` 用来声明 Extension 何时介入。

当前支持的类型：

- `global_passive`
- `scoped_passive`
- `global_scheduled`

当前支持的作用域：

- `text_chat`
- `voice_chat`
- `proactive_message`

当前支持的匹配条件：

- `match.url_domains`
- `match.keywords`
- `match.regex`

### 配置字段

`config_schema.fields` 会渲染到 Dashboard 的 Extension 配置页。

当前支持：

- `key`
- `label`
- `type`
- `required`
- `secret`
- `help`
- `placeholder`

推荐的 `type`：

- `text`
- `multiline`
- `toggle`

如果 `secret=true`，Dashboard 会隐藏值，不回显原文。

### Dashboard 字段

`dashboard.panels` 用来声明详情页中展示哪些固定面板。

当前常用 slot：

- `extensions.detail.overview`
- `extensions.detail.tools`
- `extensions.detail.config`
- `extensions.detail.activity`

## `extension.py` 入口

运行时会按下面顺序寻找入口：

1. `create_extension(manifest)`
2. `extension`
3. `Extension`

推荐直接实现：

```python
from core.extensions import EchogramExtension


class Extension(EchogramExtension):
    def get_tools(self, context):
        return []

    async def execute_tool(self, tool_name, arguments, context):
        raise NotImplementedError

    async def build_prompt_injection(self, context):
        return ""

    async def on_scheduled_trigger(self, trigger, context):
        return None
```

## 运行时上下文

当前 `ExtensionRuntimeContext` 提供：

- `manifest`
- `storage`
- `summary`
- `media`
- `chat_id`
- `scope`
- `text`
- `matched_triggers`
- `trigger`
- `metadata`

最常用的是：

- `context.storage`
  - 读写 Extension 私有设置、记录和触发器状态
- `context.summary`
  - 调用受控文本摘要模型
- `context.media`
  - 调用受控多模态模型，底层会复用 ffmpeg 做视频抽帧和音频提取

## `context.summary`

`context.summary` 需要权限 `llm:summary`。

可用方法：

```python
cleaned = await context.summary.summarize(
    raw_text,
    focus="保留视频主题、主要观点和关键链接",
    prompt_override="请把下面的脏数据清洗成适合主模型消费的中文摘要。",
)
```

```python
cleaned = await context.summary.clean_text(
    raw_text,
    prompt_override="请把下面的原始输出整理成精炼的中文摘要。",
)
```

特点：

- 不是任意聊天接口，而是固定用途的摘要 helper
- 支持 `prompt_override` 临时覆盖默认任务提示词
- 输入长度和输出 token 都有安全上限

## `context.media`

`context.media` 需要权限 `llm:multimodal`。

可用方法：

```python
image_summary = await context.media.summarize_image(
    image_bytes,
    prompt_override="请提取界面里的按钮、警告和可执行信息。",
)
```

```python
audio_summary = await context.media.summarize_audio(
    audio_bytes,
    prompt_override="请概括这段音频在讲什么。",
)
```

```python
video_summary = await context.media.summarize_video(
    file_path=video_path,
    prompt_override="请结合抽帧和音频概括这个视频的主题与关键内容。",
)
```

特点：

- 由核心层统一接管多模态请求
- 支持 `prompt_override`
- 视频分析会复用 ffmpeg / ffprobe 做抽帧和音频提取
- Extension 不需要自己重新实现这套 ffmpeg 流程

## 存储能力

当前 `context.storage` 主要支持：

- 设置
  - `get_setting`
  - `set_setting`
  - `delete_setting`
  - `list_settings`
- 记录
  - `put_record`
  - `list_records`
  - `get_latest_record`
  - `get_record`
  - `delete_records`
- 触发器运行状态
  - `get_trigger_run`
  - `mark_trigger_run`
  - `list_trigger_runs`

示例：

```python
await context.storage.set_setting(
    context.extension_id,
    "sessdata",
    "...",
    is_secret=True,
)

summary_record = await context.storage.get_record(
    context.extension_id,
    record_type="video_summary",
    record_key="BV1xx411c7mD",
)
```

## Bilibili 示例

仓库里已经提供了可运行样例 [extensions/bilibili/manifest.json](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/manifest.json) 和 [extensions/bilibili/extension.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/extension.py)。

当前这条链已经实现：

1. 在 `text_chat` 中监听 `bilibili.com` / `b23.tv` 视频链接
2. 优先调用 Bilibili 的字幕接口，按 `zh-CN -> zh-Hans -> ai-zh` 选择字幕
3. 如果没有可用字幕，回退到获取低清 HTML5 MP4
4. 通过 `context.media.summarize_video(...)` 生成多模态摘要
5. 再用 `context.summary.clean_text(...)` 洗成稳定文本
6. 把摘要缓存进 Extension 数据库
7. 把摘要注入当前轮次提示词

它还额外演示了：

- `proactive_message` 作用域下读取最近摘要做主动消息注入
- `global_scheduled` 定时清理过期缓存

## 建议的开发顺序

1. 先写 `manifest.json`
2. 在 Dashboard 中确认能被发现
3. 再写最小 `extension.py`
4. 先打通 `build_prompt_injection` 或 `get_tools`
5. 最后再补定时任务、存储和更复杂的配置

## 相关文件

- [Extensions Runtime](./extensions_runtime.md)
- [Bilibili Extension Manifest](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/manifest.json)
- [Bilibili Extension Runtime](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/extension.py)
