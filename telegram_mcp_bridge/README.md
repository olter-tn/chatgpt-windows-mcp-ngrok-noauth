# Telegram ↔ same ChatGPT thread (MCP App bridge)

An experimental, *no-OpenAI-API, no browser automation* bridge that relays incoming Telegram messages into a ChatGPT conversation **with an active MCP App listener card**.

### Architecture

`Telegram Bot API webhook → Node queue (SQLite) → ChatGPT MCP App iframe → ui/update-model-context → ui/message → active chat → telegram_reply MCP tool → Telegram sendMessage`

ChatGPT does not expose a general API for writing turns into arbitrary consumer ChatGPT conversations. This project uses the **official MCP Apps `ui/message` host bridge**, which can submit user-role follow-ups **from an active embedded app**, subject to host permission and rendering. It does **not** wake a closed chat, guarantee unattended turns, inherit any other chat, or act as an OpenAI-issued API key. When ChatGPT is closed, the backend queues messages until a listener is resumed. The iframe may be suspended even while a tab is visible.

## Setup

1. Create a Telegram bot with `@BotFather` and copy the Bot API token. Never commit tokens to Git.
2. Obtain your numeric Telegram user ID (only that user, in a private chat, is accepted). Bots do not have a message-to-user route until you open the bot and send `/start`.
3. Copy `.env.example` to `.env` locally. Create strong secrets for `MCP_ROUTE_TOKEN` and `TELEGRAM_WEBHOOK_SECRET` (48+ random URL-safe characters). For local testing use an HTTPS tunnel such as ngrok.
4. Set `PUBLIC_BASE_URL=https://your-app.onrender.com` and `TELEGRAM_BOT_TOKEN`, `TELEGRAM_USER_ID`, and `TELEGRAM_WEBHOOK_SECRET`. On startup the service calls Telegram's `setWebhook`, using your secret for Telegram's signature header.
5. Install Node >=22 and run `npm install`, `npm start`, `npm test`. `PORT` defaults to `8787`. The server needs `MCP_ROUTE_TOKEN` to start.
6. In ChatGPT web > Plugins > Add custom MCP server: use `https://your-app.onrender.com/mcp/YOUR_MCP_ROUTE_TOKEN` (include the full secret path), Streamable HTTP, **No authentication**. The secret URL is the gateway credential; treat it as a password and rotate it after exposure. Install the plugin.
7. **In the existing conversation you want to extend**, select the plugin using `@`, then ask: `Use open_telegram_listener to display the Telegram listener card in this conversation.` Press **Start listening** in the card.
8. Message your Telegram bot. While the embedded listener is alive, it should use MCP Apps `ui/message` to submit the Telegram text as a follow-up in this conversation. The model needs to call `telegram_reply(event_id,text)` to return its answer to Telegram. Test with `hello` first.

## Tools

- `open_telegram_listener` — mount the bridge App UI.
- `telegram_reply` — deliver an answer to the original Telegram destination (bound on server, not user-provided).
- `telegram_bridge_status` / `telegram_recent_events` — read-only delivery diagnostics.
- `telegram_retry_event` — **explicit** retry of a submitted event (may duplicate a chat turn).
- Internal UI tools: `bridge_activate_listener`, `bridge_claim_next`, `bridge_confirm_submitted`, `bridge_release`, `bridge_deactivate_listener`.

## Safety and security

- `MCP_ROUTE_TOKEN` guards the MCP endpoint as a secret URL. This is an **experimental developer-mode auth scheme**, **not OAuth**. ChatGPT supports OAuth separately; for production exposure, implement OAuth/authorization server and user-level authorization rather than relying solely on a URL secret.
- Telegram ingress verifies the `X-Telegram-Bot-Api-Secret-Token` header using a timing-safe comparison and restricts users to exactly `TELEGRAM_USER_ID` in a private chat. No arbitrary `chat_id` can be passed to `telegram_reply`.
- No bot token or routing key appears in App UI resources or the Git repository.
- One listener owns the queue; claiming is atomic; Telegram update IDs are deduplicated; submitted events aren't auto-replayed. After `ui/message` host ambiguity, the UI stops rather than blindly injecting duplicates.
- **No automatic guarantee of a reply:** the model may not invoke `telegram_reply`, and ChatGPT may ask for approval before write tools or follow-ups.
- **SQLite storage is local. Render's free filesystem is ephemeral.** Queue data can be lost on restarts/deploys; use a paid persistent disk or implement an external transactional database before relying on it for important messages. Keep a single server instance. A paid plan/disk may incur costs.
- The service binds HTTPS via the hosting provider; the origin endpoint is `/telegram/webhook` and must never be added as a ChatGPT MCP URL.
- Telegram messages are only accepted as text. Generated replies are chunked for Telegram's 4096-character limit. Multiple sends can partially succeed if Telegram fails mid-reply.
- `PUBLIC_BASE_URL` is necessary for webhook registration. `setWebhook` happens after a successful service start; if you add/change credentials, restart/redeploy the service.
- The app deliberately requires a click to start the listener; opening the card doesn't implicitly trigger turns. Browser/tab suspension can interrupt polling.

## Limitations, current validation

The SQLite message queue is unit tested. End-to-end ChatGPT injection and Telegram delivery require your configured developer plugin, live bot credentials, and a running listener; those cannot be verified by the repository tests. Host support of background `ui/message` is **experimental/host-dependent** and might reject automatic triggers. If no user action is permitted, switch to manually triggered dispatch or a ChatGPT Work MCP Events subscription where supported.

Reference architecture: https://github.com/wynsyl1014/mcp-app-message-bridge
Official protocol: https://developers.openai.com/plugins/build/chatgpt-ui and https://apps.extensions.modelcontextprotocol.io/api/interfaces/app.McpUiMessageRequest.html

## Deployment

Host the Node service on Render using `render.yaml` or by setting build `npm install --omit=dev`, start `npm start`, runtime Node 22+, and health check `/health`. Put all secrets into Render environment variables. For a branch deployment, set Root Directory to the location of this project on the branch.

If using Render free tier, wake-up latency and volatile SQLite state are expected. The MCP URL must include the value assigned to `MCP_ROUTE_TOKEN`, which is not automatically shown to the user by the tool. Read it securely from your hosting dashboard.