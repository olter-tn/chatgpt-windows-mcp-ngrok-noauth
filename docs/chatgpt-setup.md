# ChatGPT setup

This guide assumes the demo has already started and printed a public ngrok URL.

## 1. Start the local MCP server and ngrok

```powershell
.\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP
```

The script prints something like:

```text
ChatGPT MCP URL:
https://example.ngrok-free.dev/mcp
```

Use the exact URL. The path should be `/mcp`, without a trailing slash.

## 2. Create the ChatGPT custom MCP app

In ChatGPT Developer Mode:

1. Open the custom app or connector creation flow.
2. Choose MCP.
3. Enter the public ngrok URL:

```text
https://example.ngrok-free.dev/mcp
```

4. Select:

```text
Protocol: Streamable HTTP
Authentication: No Authentication
```

5. Save or connect the app.

## 3. Test with Snapshot

Ask ChatGPT:

```text
Use the Windows MCP Snapshot tool and tell me what is on my screen.
```

Expected behavior:

- ChatGPT discovers the Windows-MCP tools.
- `Snapshot` is visible.
- `Snapshot` returns text plus an image.
- The structured result includes `ok: true`.

## 4. Use the computer

Once Snapshot works, ChatGPT can use tools like:

- `Screenshot`
- `Snapshot`
- `Click`
- `Type`
- `Shortcut`
- `App`
- `PowerShell`
- `FileSystem`
- `Clipboard`
- `Process`

Give specific, reversible tasks first. For example:

```text
Take a snapshot, then open Notepad and type "hello from ChatGPT". Do not save any file.
```

## 5. Stop when done

```powershell
.\scripts\stop-demo.ps1
```

Leaving a no-auth tunnel open is the main risk in this setup.
