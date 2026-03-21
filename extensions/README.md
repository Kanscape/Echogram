# Echogram Extensions Directory

This directory contains discoverable and installable Echogram extensions.

## Directory layout

Minimal discoverable extension:

```text
extensions/
  some_extension/
    manifest.json
```

Runnable extension:

```text
extensions/
  some_extension/
    manifest.json
    extension.py
```

Recommended structure:

```text
extensions/
  some_extension/
    manifest.json
    extension.py
    helper_module.py
    README.md
    assets/
```

## What an Extension can currently do

- Declare tools, triggers, permissions, config fields, and dashboard panels
- Inject extra prompt context into `text_chat`, `voice_chat`, and `proactive_message`
- Register tools for the current turn and handle tool calls
- Run scheduled tasks with `global_scheduled`
- Store settings, records, and trigger state in the Extension database
- Call `context.summary` for controlled text cleanup
- Call `context.media` for controlled image/audio/video summarization

## Included example

This repository now ships with a working sample in [bilibili/manifest.json](/C:/Users/Liuha/Documents/Workspace/Antigravity/Echogram/extensions/bilibili/manifest.json).

That sample demonstrates:

- Matching `bilibili.com` / `b23.tv` video links
- Fetching Bilibili CC subtitles with language preference
- Falling back to low-quality HTML5 MP4 when subtitles are unavailable
- Summarizing the result with `context.summary` and `context.media`
- Caching summaries in the Extension database
- Injecting recent summaries into proactive messages
