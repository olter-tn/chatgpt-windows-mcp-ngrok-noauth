# Troubleshooting

## ChatGPT cannot connect

Check that ngrok is still running:

```powershell
Invoke-RestMethod http://127.0.0.1:4040/api/tunnels
```

If there is no tunnel, start again:

```powershell
.\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP
```

## Use `/mcp`, not `/mcp/`

Use:

```text
https://YOUR-DOMAIN.ngrok-free.dev/mcp
```

Avoid:

```text
https://YOUR-DOMAIN.ngrok-free.dev/mcp/
```

Some MCP clients are sensitive to redirects.

## ngrok says the agent is too old

Update ngrok:

```powershell
ngrok update
```

If `ngrok` is not on PATH, find it:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ngrok.exe
```

Then run the found `ngrok.exe update`.

## ngrok says authentication failed

Configure your token:

```powershell
ngrok config add-authtoken YOUR_NGROK_TOKEN
```

## Port 8001 is already in use

Stop the demo:

```powershell
.\scripts\stop-demo.ps1
```

Or choose another port:

```powershell
.\scripts\start-demo.ps1 -Port 8010 -WindowsMcpPath ..\Windows-MCP
```

## Snapshot appears but does not return an image

Use a Windows-MCP build where `Snapshot` defaults to `use_vision=true`, or call:

```json
{
  "use_vision": true,
  "use_ui_tree": false
}
```

For detailed UI elements, call:

```json
{
  "use_ui_tree": true,
  "use_vision": false
}
```

## Verify outside ChatGPT

```powershell
uv run --with fastmcp python .\scripts\verify_mcp.py https://YOUR-DOMAIN.ngrok-free.dev/mcp
```

This checks tool discovery and calls `Snapshot`.
