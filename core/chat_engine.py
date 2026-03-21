from telegram import Update, constants
from telegram.ext import ContextTypes, ApplicationHandlerStop
from openai import AsyncOpenAI
import json
import re
import asyncio
import pytz

from core.access_service import access_service
from core.history_service import history_service
from core.config_service import config_service
from core.summary_service import summary_service
from config.settings import settings
from config.database import get_db_session
from models.history import History
from sqlalchemy import select, delete
from core.secure import is_admin
from core.lazy_sender import lazy_sender
from core.media_service import media_service, TTSNotConfiguredError, MediaServiceError
from utils.logger import logger
from utils.prompts import prompt_builder
from utils.config_validator import safe_int_config, safe_float_config
from core.sender_service import sender_service
from core.rag_service import rag_service
from core.extensions.runtime import extension_runtime_service
from collections import defaultdict

# 会话级 RAG 锁，防止并发导致重复嵌入
CHAT_LOCKS = defaultdict(asyncio.Lock)


def _safe_load_tool_arguments(raw_arguments) -> dict:
    if isinstance(raw_arguments, dict):
        return raw_arguments
    if not raw_arguments:
        return {}
    try:
        parsed = json.loads(raw_arguments)
    except (TypeError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


async def process_message_entry(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    HTTP/Telegram 消息入口 (文本)
    1. 鉴权
    2. 存入历史
    3. 放入缓冲队列 (LazySender)
    """
    user = update.effective_user
    chat = update.effective_chat
    message = update.message
    
    # 空值检查：user、chat、message 必须存在
    if not user or not chat or not message or not message.text:
        return
        
    # 指令交由 CommandHandler 处理
    if message.text.strip().startswith('/'):
        return

    # --- 1. 访问控制 ---
    is_adm = is_admin(user.id)
    
    if chat.type == constants.ChatType.PRIVATE:
        # 私聊：仅管理员可见，但不作为聊天记录处理
        if is_adm:
            pass
        return
    else:
        # 群组：必须在白名单内
        if not await access_service.is_whitelisted(chat.id):
            return
            
    # 通过鉴权后记录日志
    logger.info(f"MSG [{chat.id}] from {user.first_name}: {message.text[:20]}...")

    # 存入历史
    reply_to_id = None
    reply_to_content = None
    
    if message.reply_to_message:
        reply_to_id = message.reply_to_message.message_id
        raw_ref_text = message.reply_to_message.text or "[Non-text message]"
        reply_to_content = (raw_ref_text[:30] + "..") if len(raw_ref_text) > 30 else raw_ref_text

    await history_service.add_message(
        chat.id, 
        "user", 
        message.text, 
        message_id=message.message_id,
        reply_to_id=reply_to_id,
        reply_to_content=reply_to_content
    )
    
    # 触发聚合 (传递 dedup_id 以支持 Edits 并防重复)
    await lazy_sender.on_message(chat.id, context, dedup_id=update.update_id)

    try:
        asyncio.create_task(summary_service.check_and_summarize(chat.id))
    except Exception as e:
        logger.error(f"Failed to trigger proactive summary: {e}")


async def process_photo_entry(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    图片消息入口 (聚合模式)
    """
    user = update.effective_user
    chat = update.effective_chat
    message = update.message
    
    if not user or not chat or not message or not message.photo:
        return
        
    # --- 1. 访问控制 ---
    is_adm = is_admin(user.id)
    if chat.type == constants.ChatType.PRIVATE:
        if is_adm: pass
        return
    else:
        if not await access_service.is_whitelisted(chat.id):
            return
            
    logger.info(f"PHOTO [{chat.id}] from {user.first_name}")
    
    # 获取最大尺寸图片
    photo = message.photo[-1]
    file_id = photo.file_id
    
    # 存入历史 (占位)
    reply_to_id = None
    reply_to_content = None
    if message.reply_to_message:
        reply_to_id = message.reply_to_message.message_id
        raw_text = message.reply_to_message.text or "[Non-text message]"
        reply_to_content = (raw_text[:30] + "..") if len(raw_text) > 30 else raw_text

    # 获取 Caption 
    caption = message.caption or ""
    db_content = f"[Image: Processing...]{caption}"

    await history_service.add_message(
        chat.id, "user", db_content, 
        message_id=message.message_id,
        reply_to_id=reply_to_id, reply_to_content=reply_to_content,
        message_type="image", file_id=file_id
    )
    
    # 触发聚合 (传递 dedup_id 以支持 Edits 并防重复)
    await lazy_sender.on_message(chat.id, context, dedup_id=update.update_id)
    try:
        asyncio.create_task(summary_service.check_and_summarize(chat.id))
    except:
        pass


async def process_voice_message_entry(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    语音消息入口 (聚合模式)
    """
    user = update.effective_user
    chat = update.effective_chat
    message = update.message
    
    # 空值检查
    if not user or not chat or not message or not message.voice:
        return
    
    # --- 1. 访问控制 ---
    is_adm = is_admin(user.id)
    if chat.type == constants.ChatType.PRIVATE:
        if is_adm: pass
        return
    else:
        if not await access_service.is_whitelisted(chat.id):
            return
    
    logger.info(f"VOICE [{chat.id}] from {user.first_name}: {message.voice.duration}s")
    
    file_id = message.voice.file_id
    
    # 存入历史 (占位)
    reply_to_id = None
    reply_to_content = None
    if message.reply_to_message:
        reply_to_id = message.reply_to_message.message_id
        raw_text = message.reply_to_message.text or "[Non-text message]"
        reply_to_content = (raw_text[:30] + "..") if len(raw_text) > 30 else raw_text

    await history_service.add_message(
        chat.id, "user", "[Voice: Processing...]",
        message_id=message.message_id,
        reply_to_id=reply_to_id, reply_to_content=reply_to_content,
        message_type="voice", file_id=file_id
    )
    
    # 触发聚合 (传递 dedup_id 以支持 Edits 并防重复)
    await lazy_sender.on_message(chat.id, context, dedup_id=update.update_id)
    try:
        asyncio.create_task(summary_service.check_and_summarize(chat.id))
    except:
        pass


async def generate_response(chat_id: int, context: ContextTypes.DEFAULT_TYPE):
    """
    核心回复生成逻辑 (支持多模态聚合)
    1. 获取历史
    2. 扫描 Recent Assistant 之后的 User Messages
    3. 提取 pending 的图片/语音并下载转换
    4. 构造 Multimodal Payload
    5. 调用 LLM
    6. 解析结果 (Summary/Transcript) 并回填 DB
    7. 发送回复
    """
    logger.info(f"Generate Response triggered for Chat {chat_id}")
    
    configs = await config_service.get_all_settings()
    api_key = configs.get("api_key")
    base_url = configs.get("api_base_url")
    model = configs.get("model_name", "gpt-3.5-turbo")
    system_prompt_custom = configs.get("system_prompt")
    timezone = configs.get("timezone", "UTC")

    if not api_key:
        await context.bot.send_message(chat_id, "⚠️ 尚未配置 API Key，请使用 /dashboard 配置。")
        return

    dynamic_summary = await summary_service.get_summary(chat_id)
    extension_runtime = None

    # --- RAG Integration & Core Locking ---
    # 按照指示，整个生成过程需要在锁内执行，以保证 Strict Serialization
    async with CHAT_LOCKS[chat_id]:
        rag_context = ""
        # [RAG Sync Removed from Hot Path]
        # sync_historic_embeddings is now deprecated and moved to background ETL task.
        
        # Token limit check
        target_tokens = safe_int_config(
            configs.get("history_tokens"),
            settings.HISTORY_WINDOW_TOKENS,
            min_val=100, max_val=50000
        )
        
        # 1. 获取基础历史记录
        history_msgs = await history_service.get_token_controlled_context(chat_id, target_tokens=target_tokens)
        
        # 2. 识别“尾部”聚合区间 
        last_assistant_idx = -1
        for i in range(len(history_msgs) - 1, -1, -1):
            if history_msgs[i].role == 'assistant':
                last_assistant_idx = i
                break
                
        if last_assistant_idx == -1:
            tail_msgs = history_msgs
            base_msgs = []
        else:
            base_msgs = history_msgs[:last_assistant_idx+1]
            tail_msgs = history_msgs[last_assistant_idx+1:]
    
        # --- Shift-Left: Multimodal Pre-processing ---
        # 在 RAG 搜索之前，先处理 Pending 的图片和语音，获取 Caption/Transcript
        # 这样 RAG Rewrite 就能利用这些信息
        # 缓存处理结果，避免后续重复下载
        processed_media_cache = {} # msg_id -> (type, content_text)
        
        pending_images_map = {}
        pending_voices_map = {} # Initialize this map as it's used in process_media_item
        # --- Shift-Left: Multimodal Pre-processing (Parallelized) ---
        # 并行处理所有待处理的图片和语音，以最大化 TTFT
        tasks = []
        
        async def process_media_item(msg):
            # 1. Image Processing
            if msg.message_type == 'image' and msg.file_id and "[Image: Processing...]" in msg.content:
                try:
                    f = await context.bot.get_file(msg.file_id)
                    b = await f.download_as_bytearray()
                    file_bytes = bytes(b)
                    
                    # Call Media Model (Captioning)
                    # Use generic XML Protocol
                    caption = await media_service.caption_image(file_bytes)
                    
                    # Cache & Update Content using Legacy Format
                    # Format: [Image Summary: caption]
                    processed_media_cache[msg.message_id] = ("image", caption)
                    msg.content = f"[Image Summary: {caption}]"
                    
                    # Store for later rendering
                    pending_images_map[msg.message_id] = (msg, file_bytes)
                except Exception as e:
                    logger.error(f"Shift-Left Image failed: {e}")
                    msg.content = "[Image Summary: Analyze Failed]"

            # 2. Voice Processing
            elif msg.message_type == 'voice' and msg.file_id and "[Voice: Processing...]" in msg.content:
                try:
                    f = await context.bot.get_file(msg.file_id)
                    b = await f.download_as_bytearray()
                    file_bytes = bytes(b)
                    
                    # Call Media Model (Transcription)
                    # Use generic XML Protocol
                    transcript = await media_service.transcribe_audio(file_bytes)
                    
                    # Cache & Update Content using Legacy Format
                    # Format: Raw Text
                    processed_media_cache[msg.message_id] = ("voice", transcript)
                    msg.content = transcript
                    
                    # Store
                    pending_voices_map[msg.message_id] = (msg, file_bytes)
                except Exception as e:
                    logger.error(f"Shift-Left Voice failed: {e}")
                    msg.content = "[Voice Transcript Failed]"

        # Create tasks for all tail messages
        if tail_msgs:
            for msg in tail_msgs:
                if msg.message_type in ('image', 'voice'):
                    tasks.append(process_media_item(msg))
            
            if tasks:
                logger.info(f"Shift-Left: Processing {len(tasks)} media items in parallel...")
                await asyncio.gather(*tasks)


        # --- RAG Search ---
        # 移到锁内执行，确保使用最新的 embeddings
        current_query = ""
        try:
            # 聚合当前轮次中所有的用户文本消息作为查询词 (此时已包含多模态转换后的文本)
            user_texts = [
                m.content for m in tail_msgs 
                if m.role == 'user' and m.content
            ]
            current_query = " ".join(user_texts).strip()
            
            if current_query:
                # 收集当前上下文中的所有消息 ID 以排除 (Self-Echo Prevention)
                # 包括 base_msgs 和 tail_msgs
                context_ids = [m.id for m in history_msgs if m.id]
                
                # --- Query Rewriting (Contextualization) ---
                # 准备完整上下文给 Rewriter (与主模型对齐)
                # 包含: 1. Long-term Summary; 2. All History in Active Window
                
                full_history_lines = []
                for m in history_msgs:
                    # 简单格式化 content, 不截断 (Trust the model/token limit of rewriter)
                    full_history_lines.append(f"{m.role.capitalize()}: {m.content}")
                
                full_history_str = "\n".join(full_history_lines)
                
                rewritten_query = await rag_service.contextualize_query(
                    query_text=current_query, 
                    conversation_history=full_history_str,
                    long_term_summary=dynamic_summary
                )
                
                found_context = await rag_service.search_context(
                    chat_id, 
                    rewritten_query, 
                    exclude_ids=context_ids
                )

                if found_context:
                    rag_context = found_context
                    logger.info(f"RAG: Injected memory for '{current_query[:20]}...'")
        except Exception as e:
            logger.error(f"RAG Search Error: {e}")
    
        if rag_context:
            dynamic_summary += f"\n\n[Relevant Long-term Memories]\n{rag_context}"

        # 3. 准备系统提示词
        # 只要末尾存在语音或图片，就启用对应的多模态协议
        has_v = any(m.message_type == 'voice' for m in tail_msgs)
        has_i = any(m.message_type == 'image' for m in tail_msgs)

        extension_scope = "voice_chat" if has_v else "text_chat"
        extension_runtime = await extension_runtime_service.resolve_runtime(
            chat_id=chat_id,
            scope=extension_scope,
            text=current_query,
            metadata={
                "has_voice": has_v,
                "has_image": has_i,
                "tail_message_count": len(tail_msgs),
            },
        )
        if extension_runtime.prompt_injection:
            dynamic_summary += (
                f"\n\n[Extension Runtime Context]\n{extension_runtime.prompt_injection}"
            )
        if extension_runtime.extension_ids:
            logger.info(
                "Extension runtime activated for chat %s: %s",
                chat_id,
                ", ".join(extension_runtime.extension_ids),
            )
    


    # 4. 检查上一轮表情违规情况 (Reaction Violation Check)
    has_rv = False
    if last_assistant_idx != -1:
        last_assistant_msg = history_msgs[last_assistant_idx]
        # 解析标签中的 react 属性
        react_matches = re.finditer(r'react=["\']([^"\']+)["\']', last_assistant_msg.content)
        for rm in react_matches:
            full_react = rm.group(1).strip()
            emoji_part = full_react.split(":")[0].strip() if ":" in full_react else full_react
            if emoji_part not in sender_service.TG_FREE_REACTIONS:
                has_rv = True
                break
    
    system_content = prompt_builder.build_system_prompt(
        soul_prompt=system_prompt_custom, 
        timezone=timezone, 
        dynamic_summary=dynamic_summary,
        has_voice=has_v,
        has_image=has_i,
        reaction_violation=has_rv
    )
    
    messages = [{"role": "system", "content": system_content}]
    
    # 时区处理
    import pytz
    try:
        tz = pytz.timezone(timezone)
    except:
        tz = pytz.UTC

    # 4. 填充基础历史 (base_msgs)
    for h in base_msgs:
        time_str = "Unknown"
        if h.timestamp:
            try:
                dt = h.timestamp.replace(tzinfo=pytz.UTC) if h.timestamp.tzinfo is None else h.timestamp
                time_str = dt.astimezone(tz).strftime("%Y-%m-%d %H:%M:%S")
            except: pass
        
        msg_id_str = f"MSG {h.message_id}" if h.message_id else "MSG ?"
        msg_type_str = h.message_type.capitalize() if h.message_type else "Text"
        prefix = f"[{msg_id_str}] [{time_str}] [{msg_type_str}] "
        if h.reply_to_content:
            prefix += f'(Reply to "{h.reply_to_content}") '
        messages.append({"role": h.role, "content": prefix + h.content})

    # 5. 扫描聚合区间内的 Pending 内容 (Using Pre-processed Cache)
    # pending_images_map = {msg_id: (msg_obj, file_bytes)}
    # pending_voices_map = {msg_id: (msg_obj, file_bytes)}
    
    has_multimodal = bool(pending_images_map or pending_voices_map)
    
    # 还需要检查是否有纯文本的 tail messages 需要加入
    # 如果 tail_msgs 里有 id 不在 pending map 里，且是 user 文本，也算 multimodal batch 吗？
    # 统一逻辑：只要有 tail_msgs，就重组为 user message list
    
    if tail_msgs:
        multimodal_content = []
        
        for msg in tail_msgs:
            # Time & Prefix
            time_str = "Unknown"
            if msg.timestamp:
                try:
                    dt = msg.timestamp.replace(tzinfo=pytz.UTC) if msg.timestamp.tzinfo is None else msg.timestamp
                    time_str = dt.astimezone(tz).strftime("%Y-%m-%d %H:%M:%S")
                except: pass
            
            msg_id_str = f"MSG {msg.message_id}" if msg.message_id else "MSG ?"
            msg_type_str = msg.message_type.capitalize() if msg.message_type else "Text"
            prefix = f"[{msg_id_str}] [{time_str}] [{msg_type_str}] "

            # Image
            if msg.message_id in pending_images_map:
                msg_obj, file_bytes = pending_images_map[msg.message_id]
                # 获取 XML (Shift-Left 已更新 msg.content)
                # content: <img_summary ...>...</img_summary>
                
                try:
                    b64 = await media_service.process_image_to_base64(file_bytes)
                    if b64:
                        multimodal_content.append({"type": "text", "text": f"{prefix}{msg.content}"})
                        multimodal_content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}})
                except Exception as e:
                    logger.error(f"Image B64 failed: {e}")
                    multimodal_content.append({"type": "text", "text": f"{prefix}[Image Error]"})
            
            # Voice
            elif msg.message_id in pending_voices_map:
                msg_obj, file_bytes = pending_voices_map[msg.message_id]
                # content: <transcript ...>...</transcript>
                
                try:
                    b64 = await media_service.process_audio_to_base64(file_bytes)
                    if b64:
                        multimodal_content.append({"type": "text", "text": f"{prefix}{msg.content}"})
                        multimodal_content.append({"type": "input_audio", "input_audio": {"data": b64, "format": "wav"}})
                except Exception as e:
                    logger.error(f"Voice B64 failed: {e}")
                    multimodal_content.append({"type": "text", "text": f"{prefix}[Voice Error]"})
            
            # Text / Processed-but-failed Media
            else:
                if msg.content:
                    text_content = msg.content
                    if msg.reply_to_content:
                        prefix += f'(Reply to "{msg.reply_to_content}") '
                    multimodal_content.append({"type": "text", "text": prefix + text_content})

        if multimodal_content:
            messages.append({"role": "user", "content": multimodal_content})
    else:
        # Should not happen if tail_msgs is empty, but just in case
        pass

    # 7. 预先持久化 Shift-Left 媒体数据 (Critical Fix)
    # 将识别结果写入数据库，确保即使主模型 API 失败，转录内容也不丢失
    try:
        # 使用副本迭代以防运行时修改
        for mid, (mtype, content) in list(processed_media_cache.items()):
            if mtype == 'image':
                 msg_obj, _ = pending_images_map.get(mid, (None,None))
                 if msg_obj:
                    # Persist: [Image Summary: caption]
                    await history_service.update_message_content_by_file_id(msg_obj.file_id, f"[Image Summary: {content}]")
                    logger.info(f"Persisted Image Caption for Msg {mid}")
                    
            elif mtype == 'voice':
                 msg_obj, _ = pending_voices_map.get(mid, (None,None))
                 if msg_obj:
                     # Persist: Raw Transcript
                    await history_service.update_message_content_by_file_id(msg_obj.file_id, content)
                    logger.info(f"Persisted Voice Transcript for Msg {mid}")
    except Exception as e:
        logger.error(f"Failed to persist media data before LLM call: {e}")

    # 8. 调用 LLM
    current_temp = safe_float_config(configs.get("temperature", "0.7"), 0.7, 0.0, 2.0)
    
    try:
        client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        request_messages = list(messages)
        active_tools = extension_runtime.tool_registry.tools if extension_runtime else []
        reply_content = ""
        finish_reason = None

        for _ in range(4):
            request_kwargs = {
                "model": model,
                "messages": request_messages,
                "temperature": current_temp,
                "max_tokens": 4000,
                "modalities": ["text"],
            }
            if active_tools:
                request_kwargs["tools"] = active_tools

            response = await client.chat.completions.create(**request_kwargs)

            if not response.choices:
                logger.error("LLM Error: No choices returned.")
                await context.bot.send_message(chat_id, "⚠️ AI 未返回任何选项")
                return

            choice = response.choices[0]
            finish_reason = choice.finish_reason
            message_obj = choice.message
            tool_calls = getattr(message_obj, "tool_calls", None) or []

            if tool_calls and extension_runtime:
                assistant_tool_calls = []
                for tool_call in tool_calls:
                    function_data = getattr(tool_call, "function", None)
                    tool_name = (getattr(function_data, "name", "") or "").strip()
                    arguments = _safe_load_tool_arguments(
                        getattr(function_data, "arguments", "")
                    )
                    assistant_tool_calls.append(
                        {
                            "id": tool_call.id,
                            "type": "function",
                            "function": {
                                "name": tool_name,
                                "arguments": json.dumps(arguments, ensure_ascii=False),
                            },
                        }
                    )

                request_messages.append(
                    {
                        "role": "assistant",
                        "content": message_obj.content or "",
                        "tool_calls": assistant_tool_calls,
                    }
                )

                for tool_call in tool_calls:
                    function_data = getattr(tool_call, "function", None)
                    tool_name = (getattr(function_data, "name", "") or "").strip()
                    arguments = _safe_load_tool_arguments(
                        getattr(function_data, "arguments", "")
                    )
                    try:
                        tool_result = await extension_runtime.tool_registry.execute(
                            tool_name,
                            arguments,
                        )
                    except Exception as tool_error:
                        logger.error(
                            "Extension tool execution failed for %s/%s: %s",
                            chat_id,
                            tool_name,
                            tool_error,
                            exc_info=True,
                        )
                        tool_result = f"Tool execution error: {tool_error}"

                    request_messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": tool_result or "",
                        }
                    )

                continue

            reply_content = (message_obj.content or "").strip()
            break

        if not reply_content:
            logger.warning(f"LLM Empty Response. Finish Reason: {finish_reason}")
            # 如果是 content_filter，明确告知用户
            if finish_reason == 'content_filter':
                await context.bot.send_message(chat_id, "⚠️ AI 内容被安全过滤器拦截")
            else:
                await context.bot.send_message(chat_id, f"⚠️ AI 返回空内容 (Reason: {finish_reason})")
            return
            
        reply_content = reply_content.strip()
        logger.info(f"LLM Response: {reply_content[:100]}...")
        
        # (原回填逻辑已移除，由上方预持久化接管)
            
        if not reply_content:
            reply_content = "<chat>...</chat>" # 兜底

        # 9. 发送回复
        # 只要包含语音输入，一律采用语音响应
        reply_mtype = 'voice' if has_v else 'text'
        
        await sender_service.send_llm_reply(
            chat_id=chat_id,
            reply_content=reply_content,
            context=context,
            history_msgs=history_msgs,
            message_type=reply_mtype
        )


    except Exception as e:
        logger.error(f"API Call failed: {e}")
        # --- 污染清理逻辑 ---
        # 如果处理失败，删除当前批次中处于 "Processing..." 状态的占位消息，防止污染上下文
        # 仅清除那些**尚未处理成功**（仍是 Processing 占位符）的消息。
        # 如果 Shift-Left 已经成功生成了 Description/Transcript 并更新了 DB，则保留。
        try:
            async for session in get_db_session():
                # 寻找当前批次中所有仍带 Processing 标识的消息 ID
                # 注意：Shift-Left 可能会修改内存中的 msg.content，所以这里应该去查询 DB，或者是依赖 msg.content 如果 Shift-Left 没跑或者是失败了
                # 但是 msg 对象是引用的，所以在内存中如果是 [图片内容: ...] 那就不匹配了 -> 正确，因为那是有效数据！
                # 只要匹配 [Image: Processing...] 或 [Voice: Processing...] 就删
                
                pending_ids = [m.id for m in tail_msgs if "[Image: Processing...]" in m.content or "[Voice: Processing...]" in m.content]
                if pending_ids:
                    await session.execute(delete(History).where(History.id.in_(pending_ids)))
                    await session.commit()
                    logger.info(f"Context Cleanup: Removed {len(pending_ids)} pending placeholder(s) due to API failure.")
        except Exception as cleanup_err:
            logger.error(f"Failed to cleanup pending placeholders: {cleanup_err}")

        # 强制通知管理员 (私聊推送)
        try:
            error_msg = (
                f"🚨 <b>API Call Failed</b>\n\n"
                f"会话 ID: <code>{chat_id}</code>\n"
                f"错误详情: <code>{e}</code>\n\n"
                f"💡 <i>上下文污染已自动清理，请检查 API 余额或网络环境。</i>"
            )
            await context.bot.send_message(settings.ADMIN_USER_ID, error_msg, parse_mode='HTML')
        except Exception as notify_err:
            logger.error(f"Failed to notify admin privately: {notify_err}")


async def process_reaction_update(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """处理表情回应更新"""
    reaction = update.message_reaction
    if not reaction:
        return
        
    chat = reaction.chat
    user = reaction.user
    message_id = reaction.message_id
    
    if chat.type == constants.ChatType.PRIVATE:
        return
    if not await access_service.is_whitelisted(chat.id):
        return
        
    if user and user.id == context.bot.id:
        return

    emojis = []
    for react in reaction.new_reaction:
        if hasattr(react, 'emoji'):
            emojis.append(react.emoji)
        elif hasattr(react, 'custom_emoji_id'):
            emojis.append('[CustomEmoji]')
            
    if not emojis:
        content = f"[System Info] {user.first_name if user else 'User'} removed reaction from [MSG {message_id}]"
    else:
        emoji_str = "".join(emojis)
        content = f"[System Info] {user.first_name if user else 'User'} reacted {emoji_str} to [MSG {message_id}]"

    logger.info(f"REACTION [{chat.id}]: {content}")
    
    await history_service.add_message(
        chat_id=chat.id,
        role="system",
        content=content
    )


async def process_message_edit(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    处理已编辑的消息 (EDITED_MESSAGE)
    同步更新数据库中的内容
    """
    # 兼容两种入口：MessageHandler(filters.UpdateType.EDITED_MESSAGE) / TypeHandler(Update)
    msg = update.edited_message if hasattr(update, "edited_message") else None
    if not msg:
        return

    chat = msg.chat
    
    # 简单的权限检查 (Optional, update logic is safe)
    if chat.type != constants.ChatType.PRIVATE:
        if not await access_service.is_whitelisted(chat.id):
            return

    # 对语音消息优先使用 caption（支持“发送后补附言/改附言”场景）
    if msg.voice is not None:
        new_text = (msg.caption or "").strip()
        if not new_text:
            # 策略：忽略语音附言清空，避免误影响历史/RAG。
            # 若用户希望移除这段信息，需使用 /del。
            logger.info(f"EDITED [{chat.id}]: Voice caption cleared for Msg {msg.message_id}, ignored by policy.")
            raise ApplicationHandlerStop
    else:
        new_text = msg.text or msg.caption or "[Media Content Updated]"

    success = await history_service.update_message_content(chat.id, msg.message_id, new_text)

    # 兜底：某些场景下 message_id 映射不到，改用 file_id 回写
    if (not success) and msg.voice and msg.voice.file_id:
        try:
            success = await history_service.update_message_content_by_file_id(msg.voice.file_id, new_text)
        except Exception as e:
            logger.warning(f"EDITED [{chat.id}]: Fallback update by file_id failed: {e}")

    if success:
        logger.info(f"EDITED [{chat.id}]: Msg {msg.message_id} updated in DB.")
    else:
        logger.warning(f"EDITED [{chat.id}]: Msg {msg.message_id} not found in DB (too old?).")

    # 已处理 edited_message，阻断后续 group 的 handler
    raise ApplicationHandlerStop

lazy_sender.set_callback(generate_response)
