# Echogram Extensions Runtime

## 概览

当前 `Extensions` 运行时已经接入三条主链路：

- `text_chat`
- `voice_chat`
- `proactive_message`

以及一条后台链路：

- `global_scheduled`

核心实现位于 [runtime.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/extensions/runtime.py)。

## 先分清 Trigger 和 Scope

- `trigger`
  - 说明什么时候命中
- `scope`
  - 说明命中后介入哪条运行链路

一个 Extension 可以有多个 trigger；每个 trigger 可以对应不同 scope。

## 触发器类型

当前支持：

- `global_passive`
  - 全局被动触发
- `scoped_passive`
  - 只在指定 scope 中触发
- `global_scheduled`
  - 后台定时触发

## 作用域

当前支持：

- `text_chat`
  - 文本消息进入主对话链路时
- `voice_chat`
  - 语音消息进入主对话链路时
- `proactive_message`
  - 主动消息生成前

## 匹配条件

当前支持：

- `match.url_domains`
- `match.keywords`
- `match.regex`

语义是“任意一个条件命中即可”。

例如：

```json
{
  "name": "bilibili_link_listener",
  "type": "scoped_passive",
  "scopes": ["text_chat"],
  "match": {
    "regex": [
      "(?:b23\\.tv/[A-Za-z0-9]+|bilibili\\.com/[^\\s<>()]*(?:BV[0-9A-Za-z]{10}|av\\d+))"
    ]
  }
}
```

## 运行时入口

运行时基类是 [EchogramExtension](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/extensions/runtime.py)。

你通常会实现这几个方法：

```python
class Extension(EchogramExtension):
    def get_tools(self, context):
        ...

    async def execute_tool(self, tool_name, arguments, context):
        ...

    async def build_prompt_injection(self, context):
        ...

    async def on_scheduled_trigger(self, trigger, context):
        ...
```

职责划分：

- `get_tools(context)`
  - 返回当前轮次可用工具
- `execute_tool(...)`
  - 执行工具
- `build_prompt_injection(context)`
  - 返回要注入系统上下文的纯文本
- `on_scheduled_trigger(...)`
  - 处理后台定时任务

## 聊天链路是怎么接进去的

在主聊天链路中，运行时会：

1. 根据当前 `scope` 和 `text` 计算命中的 Extensions
2. 对每个命中的 Extension 调用 `build_prompt_injection(context)`
3. 把结果拼进系统上下文
4. 调用 `get_tools(context)` 收集工具定义
5. 把工具定义带给模型
6. 如果模型发起 tool call，再回调 `execute_tool(...)`

接入点在 [chat_engine.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/chat_engine.py)。

## 主动消息链路

在主动消息链路中，运行时会重新用 `scope="proactive_message"` 匹配一次 Extension。

这适合：

- 从数据库读最近几小时的摘要
- 把摘要注入主动消息提示词
- 让主动消息建立在近期外部上下文之上

接入点在 [news_push_service.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/news_push_service.py)。

## 定时链路

后台当前每 5 分钟检查一次 `global_scheduled` 触发器。

支持的 `schedule` 写法：

- `hourly`
- `daily`
- `15m`
- `6h`
- `2d`
- `09:30`

接入点在 [bot.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/core/bot.py)。

## `ExtensionRuntimeContext`

运行时传给 Extension 的 `context` 包含：

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

### `context.summary`

需要权限 `llm:summary`。

```python
summary = await context.summary.summarize(
    raw_text,
    prompt_override="请把下面的原始字幕清洗成适合提示词注入的中文摘要。",
)
```

用途：

- 清洗网页抓取、接口返回、字幕文本
- 统一整理成纯文本
- 输出可写库、可回喂模型的紧凑摘要

### `context.media`

需要权限 `llm:multimodal`。

```python
video_summary = await context.media.summarize_video(
    file_path=video_path,
    prompt_override="请结合抽帧和音频概括这个视频的主题与关键内容。",
)
```

用途：

- 图片总结
- 音频总结
- 视频总结

视频路径会自动复用 ffmpeg / ffprobe 进行抽帧和音频提取。

### `context.storage`

用于 Extension 私有存储。

推荐场景：

- 存 token / cookie
- 存摘要缓存
- 存调度结果
- 存最近活动记录

## Bilibili Extension 运行流程

示例实现位于：

- [bilibili/manifest.json](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/manifest.json)
- [bilibili/extension.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/extension.py)
- [bilibili_support.py](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/bilibili_support.py)

当前行为：

1. 在 `text_chat` 中匹配 Bilibili 视频链接
2. 提取 `BV` 或 `av`
3. 调 `x/web-interface/view` 拿 `aid/cid/title`
4. 调 `x/player/v2` 看字幕列表
5. 优先选择 `zh-CN`
6. 没有 `zh-CN` 时回退到 `zh-Hans`
7. 还没有时回退到 `ai-zh`
8. 如果字幕仍不可用，则下载低清 HTML5 MP4
9. 用 `context.media.summarize_video(...)` 做多模态摘要
10. 再用 `context.summary.clean_text(...)` 洗成稳定文本
11. 把结果缓存到数据库
12. 注入当前轮次提示词

它还会：

- 在 `proactive_message` 中读最近的 Bilibili 摘要再注入
- 在定时任务中清理过期缓存

## 当前边界

- `permissions` 还不是强沙箱；它目前是“声明 + 运行时白名单 helper”
- Extension 仍然是本地 Python 代码，不是隔离执行环境
- Dashboard 目前只支持声明式 panel，不支持自带任意前端代码

## 测试建议

1. 打开 Dashboard，启用 `Bilibili` Extension
2. 如有需要，在配置里填入 `SESSDATA`
3. 给 Bot 发送一条带 Bilibili 视频链接的文本
4. 确认当前轮次能看到注入的 Bilibili 摘要
5. 如果视频没有字幕，确认它会回退到视频多模态摘要
6. 触发一次主动消息，确认最近摘要能被再次注入
