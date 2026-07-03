# Security notes

This repo demonstrates a no-auth MCP tunnel because it is the easiest way to connect a custom MCP app in ChatGPT.

No auth also means no access control at the MCP layer.

## What is exposed

Windows-MCP can expose tools that interact with your Windows machine, including:

- screen capture
- mouse and keyboard control
- app launching and switching
- filesystem access
- PowerShell execution
- clipboard access
- process listing and termination
- registry access

If the public ngrok URL leaks while the tunnel is running, another party may be able to invoke those tools.

## Safer demo habits

- Run it only while you are watching the machine.
- Close sensitive apps first.
- Use a temporary Windows user account if possible.
- Keep the tunnel lifetime short.
- Stop ngrok immediately after the demo.
- Do not expose this on a work machine with private data.
- Prefer OAuth or a secure tunnel for anything beyond a throwaway demo.

## Stop command

```powershell
.\scripts\stop-demo.ps1
```

Or stop ngrok directly:

```powershell
Stop-Process -Name ngrok -Force
```

## Why no-auth is included anyway

ChatGPT custom MCP app setup can be easiest to validate with "No Authentication". This repo documents that path honestly and makes the risk visible instead of hiding it.
