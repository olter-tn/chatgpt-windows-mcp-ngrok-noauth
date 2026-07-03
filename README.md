# ChatGPT Windows MCP via ngrok, no auth

This repo is a practical demo for connecting ChatGPT to a Windows desktop through MCP using:

- [CursorTouch/Windows-MCP](https://github.com/CursorTouch/Windows-MCP)
- ngrok
- ChatGPT Developer Mode custom MCP apps
- Streamable HTTP
- No Authentication

Huge shout-out to **CursorTouch/Windows-MCP**. That project does the real Windows automation work. This repo is a small field guide and launcher around it, focused on the exact "make ChatGPT use my Windows computer" path.

## What this does

The demo starts a local Windows-MCP server on your machine, exposes it through an ngrok HTTPS URL, and gives you the URL to paste into ChatGPT as a custom MCP app.

```text
ChatGPT
  -> ngrok HTTPS URL
  -> http://127.0.0.1:8001/mcp
  -> Windows-MCP
  -> your Windows desktop
```

## Security warning

This demo intentionally uses **No Authentication** because that is the simplest way to test a custom MCP app in ChatGPT.

While ngrok is running, anyone who obtains the public URL may be able to use the exposed MCP tools. Windows-MCP can control apps, type, click, take screenshots, access files, run PowerShell, inspect processes, and read or write parts of the registry.

Use this only for short-lived demos on a machine you control. Stop ngrok as soon as you finish.

## Prerequisites

- Windows 10 or Windows 11
- Python 3.13 available through `uv`
- `uv` installed
- ngrok installed and authenticated
- ChatGPT Developer Mode access
- A local clone of CursorTouch/Windows-MCP, or permission to run it from PyPI with `uvx`

If ngrok is installed but not authenticated:

```powershell
ngrok config add-authtoken YOUR_NGROK_TOKEN
```

## Quick start

From this repo:

```powershell
.\scripts\preflight.ps1
```

Then start the demo with a local Windows-MCP checkout:

```powershell
.\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP
```

If you do not have a local Windows-MCP checkout, the script can run the PyPI package through `uvx`:

```powershell
.\scripts\start-demo.ps1
```

The script prints a ChatGPT MCP URL like:

```text
https://example.ngrok-free.dev/mcp
```

Use that exact `/mcp` URL in ChatGPT. Do not add a trailing slash.

## ChatGPT setup

In ChatGPT Developer Mode, create a custom app:

```text
MCP server URL: https://YOUR-NGROK-DOMAIN.ngrok-free.dev/mcp
Protocol: Streamable HTTP
Authentication: No Authentication
```

Then ask ChatGPT to call `Snapshot`. A working setup should return a desktop screenshot and a structured result with `ok: true`.

See [docs/chatgpt-setup.md](docs/chatgpt-setup.md) for the full walkthrough.

## Verify manually

After starting the tunnel:

```powershell
uv run --with fastmcp python .\scripts\verify_mcp.py https://YOUR-NGROK-DOMAIN.ngrok-free.dev/mcp
```

Expected output includes:

```text
Snapshot output schema: true
Snapshot is_error: false
Snapshot content types: text,image
Snapshot structured ok: true
```

## Stop the demo

```powershell
.\scripts\stop-demo.ps1
```

This stops ngrok and the Windows-MCP process started on the demo port.

## Repo layout

```text
docs/
  chatgpt-setup.md      Full ChatGPT custom MCP app setup
  security.md           What no-auth means and how to reduce risk
  troubleshooting.md    Common failures and fixes
scripts/
  preflight.ps1         Checks tools and scans tracked files for accidental secrets
  start-demo.ps1        Starts Windows-MCP and ngrok
  stop-demo.ps1         Stops the demo processes
  verify_mcp.py         Lists tools and calls Snapshot through MCP
```

## Notes

- This repo does not vendor Windows-MCP.
- Runtime files are written under `.run/`, which is ignored by Git.
- The docs use fake placeholder domains and tokens only. Run `.\scripts\preflight.ps1` before publishing changes.
- The recommended production shape is OAuth or a proper secure tunnel. This repo is intentionally about the no-auth ngrok path for demos.
- If `Snapshot` does not return an image, use a Windows-MCP build where `Snapshot` defaults to screenshot-first behavior, or call it with `use_vision=true`.

## License

MIT. CursorTouch/Windows-MCP is licensed separately by its authors.
