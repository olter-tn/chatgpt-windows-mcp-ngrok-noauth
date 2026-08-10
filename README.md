# ChatGPT Windows MCP via ngrok (No Auth)

A practical demo for connecting ChatGPT to a Windows desktop through MCP using [CursorTouch/Windows-MCP](https://github.com/CursorTouch/Windows-MCP), ngrok, Streamable HTTP, and a ChatGPT custom MCP app.

> [!WARNING]
> This setup intentionally uses **no authentication** for quick demos. Anyone who gets the public ngrok URL may be able to invoke exposed Windows-MCP tools. Use it only on a machine you control, keep the tunnel short-lived, and stop ngrok when finished.

## How it works

```text
ChatGPT
  -> ngrok HTTPS URL
  -> local compatibility proxy
  -> http://127.0.0.1:8002/mcp
  -> Windows-MCP
  -> Windows desktop
```

The compatibility proxy normalizes Streamable HTTP `Accept` headers so clients can communicate reliably with Windows-MCP.

## Prerequisites

- Windows 10 or Windows 11
- Python 3.13 available through `uv`
- `uv`
- ngrok, installed and authenticated
- ChatGPT Developer Mode access
- Optional: a local checkout of `CursorTouch/Windows-MCP`

Authenticate ngrok if needed:

```powershell
ngrok config add-authtoken YOUR_NGROK_TOKEN
```

## Quick start

Run the preflight checks:

```powershell
.\scripts\preflight.ps1
```

Start with a local Windows-MCP checkout:

```powershell
.\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP
```

Or let the script run the package through `uvx`:

```powershell
.\scripts\start-demo.ps1
```

The launcher prints an MCP endpoint similar to:

```text
https://example.ngrok-free.dev/mcp
```

Use that exact `/mcp` endpoint in ChatGPT without adding a trailing slash.

## Configure ChatGPT

Create a custom MCP app in ChatGPT Developer Mode with:

```text
MCP server URL: https://YOUR-NGROK-DOMAIN.ngrok-free.dev/mcp
Protocol: Streamable HTTP
Authentication: No Authentication
```

Then call the `Snapshot` tool. A successful connection should return a desktop screenshot and a structured result with `ok: true`.

For the full walkthrough, see [`docs/chatgpt-setup.md`](docs/chatgpt-setup.md).

## Verify the connection

```powershell
uv run --with fastmcp python .\scripts\verify_mcp.py https://YOUR-NGROK-DOMAIN.ngrok-free.dev/mcp
```

A healthy run should report that `Snapshot` completed successfully and returned the expected content.

## Direct mode

By default, the demo uses a small local proxy to ensure the required Streamable HTTP media types are present. To expose Windows-MCP directly instead:

```powershell
.\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP -NoAcceptProxy
```

If you encounter:

```text
Not Acceptable: Client must accept both application/json and text/event-stream
```

restart without `-NoAcceptProxy` so the compatibility proxy is enabled.

## Stop the demo

```powershell
.\scripts\stop-demo.ps1
```

This stops ngrok and the Windows-MCP process started for the demo.

## Repository structure

```text
docs/
  chatgpt-setup.md      ChatGPT custom MCP app walkthrough
  security.md           No-auth risks and mitigations
  troubleshooting.md    Common failures and fixes

scripts/
  preflight.ps1         Checks dependencies and scans tracked files for secrets
  mcp_accept_proxy.py   Normalizes Streamable HTTP Accept headers
  start-demo.ps1        Starts Windows-MCP and ngrok
  stop-demo.ps1         Stops demo processes
  verify_mcp.py         Lists tools and verifies Snapshot through MCP
```

## Security notes

Windows-MCP can expose powerful desktop capabilities such as clicking, typing, screenshots, file access, PowerShell execution, process inspection, and registry access. A public no-auth tunnel should therefore be treated as temporary and sensitive.

For anything beyond a controlled demo, use authentication or a properly secured tunnel. See [`docs/security.md`](docs/security.md).

## Credits

The Windows automation layer comes from [CursorTouch/Windows-MCP](https://github.com/CursorTouch/Windows-MCP). This repository focuses on the ChatGPT + ngrok integration path around it.

## License

MIT. CursorTouch/Windows-MCP is licensed separately by its authors.
