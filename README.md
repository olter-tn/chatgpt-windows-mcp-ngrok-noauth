# Windows laptop MCP — full tool set, local or through ngrok

This project runs [CursorTouch/Windows-MCP](https://github.com/CursorTouch/Windows-MCP) with every upstream tool enabled and adds durable command jobs, binary file transfer, downloadable file exports, and an actual access report. It imposes no command allowlist or filesystem sandbox. Windows permissions determine what the server can do.

The runtime is pinned to Windows-MCP **0.8.5**; `uv.lock` also locks its dependencies. The original Windows automation implementation and its credit remain with CursorTouch.

**“100% access” is not a guarantee any MCP can make.** An elevated server can perform administrative work, but Windows secure desktop, ACLs, protected processes, application behavior, and the agent client's own permissions still apply. See the [capability audit](docs/capability-audit.md) for findings and verification coverage.

## Desktop manager — easiest way

Download this repository using **Code → Download ZIP**, choose **Extract All**, and double-click **Open MCP Manager.cmd** in the extracted folder. You do not need to install Python, uv, Git or ngrok beforehand. Use a writable folder on an Intel/AMD 64-bit Windows 10/11 laptop with an internet connection.

The launcher prepares Python and opens **Setup & settings**. Choose remote or local access, click **Install / repair**, then use the ngrok dashboard button to obtain and save your authtoken if connecting remotely. The launcher checks missing software, runtime imports, configuration and occupied ports. It installs the required packages and ngrok; you complete account signup/email verification and Windows approval prompts.

Click **Start MCP**, wait for **Running**, then **Copy link**. **Connect an AI app** walks through the remaining client configuration, including ChatGPT's custom MCP access and local stdio clients. **Check connection** tests the server. **Stop MCP** disconnects it; closing the manager leaves it running. Create a Desktop shortcut from Setup. See the [launcher guide](docs/launcher.md) for the complete first-run journey and recovery steps.

## Install from PowerShell

For command-line setup on supported Windows, run from this folder:

```powershell
.\scripts\setup.ps1
.\scripts\preflight.ps1 -LocalOnly
```

Setup downloads a verified, pinned uv helper and creates `.venv` from the lockfile using Python 3.13, downloading Python if needed. It also writes `.run/mcp-stdio.json` with this machine's absolute paths for local MCP agents. It does not change system execution policy, UAC, or antivirus settings. The GUI's installation uses `-Production` to omit development-only packages.

## Connect a local agent

For clients supporting `mcpServers` configuration, use the entry in `.run/mcp-stdio.json`. The client launches the server over stdio. Other clients can use the same executable and arguments in their own configuration format.

To run a shared Streamable HTTP endpoint:

```powershell
.\scripts\start-demo.ps1 -LocalOnly
```

The default client URL is `http://127.0.0.1:8011/mcp`. The server listens on 8010, with the compatibility proxy on 8011. It is accessible from this laptop. All components run in the interactive Windows user session.

## Connect a remote agent through ngrok

Install [ngrok](https://ngrok.com/download/windows) and configure your account token locally:

```powershell
ngrok config add-authtoken YOUR_NGROK_TOKEN
.\scripts\preflight.ps1
.\scripts\start-demo.ps1
```

If ngrok is in this project's local tools folder instead of PATH, use `.\.run\tools\ngrok.exe config add-authtoken YOUR_NGROK_TOKEN`. The launcher discovers that location automatically; `-NgrokPath` supports other locations.

The launcher prints an HTTPS `/mcp` URL. Configure the agent for **Streamable HTTP / No Authentication**. The same 24 tools are available locally and remotely:

```text
Remote MCP client -> ngrok HTTPS -> 127.0.0.1:8011 -> 127.0.0.1:8010 -> Windows
Local MCP client  -> stdio, or the same local HTTP endpoint
```

This remains an intentionally **unauthenticated** endpoint: anyone able to reach the tunnel can invoke the computer's tools with the server's Windows privileges. Browser Origin checks do not authenticate remote agents. See [security notes](docs/security.md).

## Administrator access

Open PowerShell using **Run as administrator**, then start with:

```powershell
.\scripts\start-demo.ps1 -RequireAdministrator
# Or add -LocalOnly for a local HTTP endpoint.
```

`-RequireAdministrator` fails immediately if elevation is absent. It does not bypass the Windows UAC prompt. Call `ComputerCapabilities` to check the running server's actual `elevated` value. A stdio server inherits the client process's Windows token.

## Capabilities

| Area | Tools |
| --- | --- |
| Screens, displays and UI elements | `Screenshot`, `Snapshot`, `DisplayInventory` |
| Mouse, keyboard and multi-field input | `Click`, `Move`, `Scroll`, `Type`, `Shortcut`, `MultiSelect`, `MultiEdit` |
| Apps, waits and clipboard | `App`, `Wait`, `WaitFor`, `Clipboard` |
| Files, processes and registry | `FileSystem`, `Process`, `Registry` |
| Scripting, web content and notifications | `PowerShell`, `Scrape`, `Notification` |
| Added here | `Command`, `FileTransfer`, `UploadFile`, `ComputerCapabilities` |

Use `Screenshot` for fast visual context. `Snapshot` includes UI extraction by default; explicitly request `use_vision=true` for an image, and set `use_ui_tree=false` when the tree is unnecessary. Screenshots may be scaled: use their coordinate metadata and `DisplayInventory` when targeting pixels, especially with multiple monitors.

Typing uses native Unicode input without changing the clipboard. Literal braces, accented text and emoji are supported; newline and tab send their corresponding keys. `clear=true` replaces text using document-selection keys. Window behavior and Windows input permissions still apply.

PowerShell and Command can invoke installed applications, Python, cmd, Git, WSL, COM, WMI/CIM, Windows services, scheduled tasks and network APIs to the extent permitted by Windows. A separate MCP tool is not required for every operating-system API.

### Long commands, stdin and complete output

```json
{"action":"start","command":"Get-ChildItem -LiteralPath C:\\ -Force","wait_seconds":1}
```

`Command` returns a `job_id`. Use `action="read"` to retrieve `stdout`, `stderr`, `exit_code`, and `state`. Pass each stream's `next_offset` on subsequent reads. Results are limited per call (up to 1 MiB per stream), while full output remains on disk. A returned `ok=true` means the job request succeeded; check **exit_code** for the command's success, and **state** for the entire process group's completion.

Use `program` plus `arguments` instead of `command` for a native executable. Optional `cwd` and `env` set its working directory and environment. `action="write"` queues UTF-8 stdin; `close_stdin=true` sends EOF. `action="list"` recovers job IDs after a client reconnect. `action="terminate"` stops the managed process group.

Jobs have no execution deadline unless `timeout_seconds` is supplied. Each read waits at most 30 seconds. Jobs survive client disconnects, and Windows Job Objects keep child processes owned even after their parent exits. They end when the server stops or crashes. The tool provides pipes rather than a terminal/ConPTY. Programs delegated to external services or task schedulers are outside that process group. Scripts and output remain in ignored `.run/jobs/`; use `FileTransfer` to retrieve original bytes when output is not UTF-8.

### Binary files

`FileTransfer` accepts any absolute Windows-accessible file path. Upload base64 chunks with `mode="write"`; the first call uses offset 0 and creates a new file, or explicitly overwrites with `overwrite=true`. Subsequent chunks use the returned `next_offset`. Parent directories must exist. Download with `mode="read"` until `eof=true`. Chunk size is at most 1 MiB; total file size is not limited by the tool. Use `FileSystem` for text and directory operations.

### Send a file into a conversation

To deliver a local file into a chat, call `UploadFile` with its absolute `path`. It returns a real `download_url` through the existing HTTP/ngrok endpoint, plus a filename, MIME type, SHA-256 and MCP resource. Links default to 24 hours and can be revoked. This exports file bytes and a download link; native conversation attachment storage remains client-controlled. See [file sharing](docs/file-sharing.md) for examples, stdio behavior and limits.

## Verify and stop

```powershell
.\.venv\Scripts\python.exe .\scripts\verify_mcp.py http://127.0.0.1:8011/mcp --exercise --report .run\verification.json
.\.venv\Scripts\python.exe -m pytest -q
.\scripts\stop-demo.ps1
```

Verification checks all required tools, decodes actual screenshots, checks access facts and system reads, and exercises shell stdin/stdout/stderr/exit status. `--exercise` adds temporary text/binary/registry round trips with cleanup. `--desktop` additionally opens a temporary native window and exercises UI discovery, window switching, mouse, keyboard and multiple text fields. Run it while the desktop is available. `--require-admin` verifies elevation.

Startup verifies local MCP before publishing, verifies the public URL afterwards, and rolls back its processes on failure. State and logs are under `.run/instances/PORT/`. Stop checks saved PID, creation time and executable identity; it does not stop unrelated ngrok instances or other listeners.

Launcher options: `-Port`, `-ProxyPort`, `-ScreenshotScale`, `-NoAcceptProxy`, `-SkipVerify`, `-LocalOnly`, `-RequireAdministrator`, `-NgrokPath`. `-WindowsMcpPath` is an optional source override for a complete, compatible checkout; omit it for the tested, locked runtime. Bind addresses are local loopback; remote access uses the tunnel.

See [troubleshooting](docs/troubleshooting.md), the [ChatGPT setup guide](docs/chatgpt-setup.md), and [publishing and release checks](docs/publishing.md). GitHub Actions runs Windows checks and builds a source ZIP. Runtime files, exported user files, tokens and logs are excluded. License: MIT; Windows-MCP retains its authors' separate license.
