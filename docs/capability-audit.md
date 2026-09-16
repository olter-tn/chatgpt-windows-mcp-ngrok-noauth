# Windows laptop MCP capability audit

Audit dates: **2026-09-15–16**. Scope: this repository's launcher, proxy, server integration, added tools, pinned upstream package and real operation on this laptop.

## Result and evidence

The server exposes **24 tools**: all 20 in Windows-MCP 0.8.5, plus `Command`, `FileTransfer`, `UploadFile`, and `ComputerCapabilities`. Commands and file paths have no application-level allowlist or workspace sandbox. Agents can use installed software and Windows APIs through arbitrary executable arguments or PowerShell scripts. Access is determined by the server's Windows token, the target application and the MCP client.

Public endpoint verification passed all **10 checks** on Windows 10 build 19045, Python 3.13.15, Windows-MCP 0.8.5 and FastMCP 4.0.3. This baseline reported session 1, input desktop `Default`, and `elevated=false`. Evidence is in ignored `.run/verification-public-full.json`; current state and startup reports are in `.run/instances/8010/`. Query `ComputerCapabilities` for current privileges rather than relying on an earlier report.

The current Administrator server passed **all 11 public checks** with `--require-admin --exercise --desktop`, including `UploadFile` delivery. The report is `.run/verification-public-admin.json`. Elevation was granted through the standard Windows flow. The desktop manager requests it when starting an Administrator instance or stopping one that is already elevated.

The regression suite passes **94 tests**, and Ruff reports no errors. Added coverage includes file export snapshots, expiry, revocation, filename/path handling, MCP resources, binary content, ranged HTTP downloads, manager privilege selection, stale process identities, UAC cancellation and responsive GUI actions. A dependency emits an AnyIO deprecation warning from Starlette's test client; tests still pass. These results establish the behaviors below, not universal compatibility with every Windows application or MCP client.

The new Python/Tkinter manager was visually inspected on this laptop. Its controller started, verified and stopped an isolated local instance while preserving the existing public server. Its native `ShellExecuteExW` elevation path also completed a real Administrator connection check. Evidence is in `.run/manager/verification-lifecycle.json` and `.run/manager/verification-elevation.json`. The Desktop shortcut opens the manager without a console window.

## Findings and changes

The 2026-09-16 onboarding checks also exercised a fresh extracted copy without a virtual environment or an installed setup helper: verified uv download, managed Python/Tkinter installation, locked runtime installation, and local Start → Check → Stop all passed. The official ngrok download passed its publisher-signature check with existing ngrok removed from that test process's PATH. Synthetic-token tests verified restricted file permissions and absence of token values in command arguments. Evidence is in `.run/verification-first-run.json`; live ngrok account signup and email verification remain user steps.

| Finding | Change and effect |
| --- | --- |
| An incomplete sibling source checkout prevented a reliable runtime; dependencies could drift. | Added Python 3.13 setup, pinned Windows-MCP 0.8.5 and a complete `uv.lock`. Setup generates a stdio configuration with absolute paths. The sibling checkout was preserved. |
| The proxy stopped after the first SSE event, which can precede the result. | It now forwards the complete stream, including priming events, progress and final responses. |
| Chunked uploads, slash redirects and header handling could break MCP traffic. | Added strict body framing, chunk decoding, `/mcp/` normalization, Accept repair and hop-header removal. Session/protocol/authentication/Origin headers are preserved. |
| Failed streams could trigger a second HTTP response. | After response headers are sent, failure closes/logs the stream instead of sending another status line. |
| Startup/stop could affect unrelated ngrok processes and used fragile process matching. | Added per-instance state, atomic writes, a lock, Windows argv quoting and identity checks using PID, start time and executable path. |
| Starting and managing the MCP required PowerShell commands. | Added a Python/Tkinter desktop manager with Start, Stop, Copy link, live status, connection checks, settings and logs. It calls the same lifecycle scripts and requests normal Windows elevation when needed. See the [launcher guide](launcher.md). |
| Verification failures were not reliable startup failures. | Local and public checks now fail startup on a nonzero result. Recorded components are rolled back on failure. Missing runtimes, occupied ports, incomplete source overrides and required elevation fail explicitly. |
| Inherited configuration could restrict tool discovery. | Standard startup clears inherited tool filters and explicitly enables the complete upstream tool set. Telemetry and UTF-8 settings are configured before imports. |
| The synchronous shell tool was insufficient for long work, stdin and complete stdout plus stderr. | Added `Command`: no implicit execution deadline, separate disk-backed output, byte paging, stdin, native argv/cwd/environment, exit status, reconnect discovery and process-group termination. |
| Text tools lacked general binary transfer. | Added base64 `FileTransfer` reads/writes with explicit offsets, 1 MiB chunks and no total file-size cap. Invalid input is rejected before overwriting files. |
| A remote agent could read laptop files but had no downloadable delivery route to return in chat. | Added `UploadFile`: snapshot copies, expiring HTTP(S) links through the existing tunnel, MCP resources, optional embedded bytes, filename/MIME/hash metadata, byte-range downloads and revocation. Native conversation storage remains client-controlled. See [file sharing](file-sharing.md). |
| Advertised power did not show actual privileges. | Added `ComputerCapabilities` reporting elevation, desktop, session, drives, runtimes and limits. Required elevation is also verified over MCP during startup. |
| A real native edit-control test failed to replace existing text. | Added native Unicode input, literal braces/surrogate pairs, document-selection keys compatible with the tested control, and key-release recovery after partial input. `MultiEdit` uses this same typing path. |
| An untrusted browser Origin was accepted in a live test. | Added an Origin guard; the same case now returns 403. It does not authenticate clients. |
| The old verifier primarily checked Snapshot and assumed an image by default. | Added tool-schema checks, decoded images, OS reads, shell behavior, reconnects, file/registry round trips and an optional native desktop fixture. |

Multiple-event streaming, Accept handling and Origin checks follow the [MCP Streamable HTTP specification](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Capability coverage

| Area | Availability and evidence |
| --- | --- |
| Vision and UI | Screenshot, Snapshot and display inventory are available. Real images decoded locally and through ngrok; the test window was found in the UI tree. Protected capture surfaces and individual UI trees remain application-dependent. |
| Mouse and keyboard | Click, move, scroll, shortcuts, type, multi-select and multi-edit are available. A real fixture verified click/move, exact replacement text, two fields and `é😀{}`. Scroll and multi-select were discovered but not separately exercised against every application. |
| Apps and timing | App launch/switch/resize, Wait and WaitFor are available. The fixture launched, switched foreground and passed an active-window wait. |
| Files | Text/directory operations and arbitrary binary transfer. Disposable text and multi-chunk binary round trips passed with cleanup; tests cover overwrite protection, invalid base64 and offsets. |
| Registry | Read/enumerate/write/delete. System information read; a unique HKCU key/value created, read and removed. System-wide changes still need appropriate Windows rights. |
| Processes | Inspection/control and managed command groups. Process listing passed; tests cover children, surviving descendants, timeouts and crash cleanup. |
| Shell | PowerShell scripts and installed executables with argv, cwd, environment and stdin. Tested independent stdout/stderr, nonzero exit codes, UTF-8 paging and scripts longer than 40 KB. |
| Long work | Start/poll/input/terminate/rediscover. A job continued after its MCP client disconnected and was read from another connection. Restart ends managed jobs. |
| Clipboard and notifications | Upstream Clipboard and Notification schemas discovered and code inspected. User clipboard contents and notification preferences were not changed for testing. |
| Network and Windows APIs | Scrape plus arbitrary commands can use network APIs, COM, WMI/CIM, services and tasks as permitted by Windows. Scrape retains upstream URL restrictions; Command has no URL allowlist. System services, drivers, firewall and account credentials were not changed as tests. |
| Connections | Real stdio calls, local Streamable HTTP and public ngrok HTTPS passed. Client metadata refresh, image support and policies remain client responsibilities. |
| Lifecycle and protocol | Tests cover both PowerShell hosts' syntax/argv/identity behavior, complete SSE, framing, headers, Origin rules and upstream errors. Live launcher startup/stop and startup verification were exercised. |

The implementation wraps the pinned [CursorTouch Windows-MCP](https://github.com/CursorTouch/Windows-MCP) package without changing its installed source. It uses private upstream builder/middleware hooks and replaces in-process typing/shortcut methods. The stdio integration test checks the resulting inventory and calls. Dependency upgrades must rerun the suite and desktop checks.

## Remaining boundaries

- **Windows privileges:** `-RequireAdministrator` verifies elevation; Windows must grant it before startup. UAC's secure desktop, locked sessions, protected processes and inaccessible resources are not universally controllable even by an elevated server.
- **Input:** Windows restricts injected input by integrity level. Some apps ignore synthetic input or expose incomplete automation. Rejected input is reported, but the server cannot make every app accept it. [Microsoft documents SendInput's restrictions](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput).
- **Shared desktop:** agents share the desktop, clipboard and filesystem. Multi-step workflows are not isolated per agent; coordinate GUI actions and refresh visual context.
- **Process lifetime:** Job Objects track directly created descendants and terminate them on server exit. Work delegated to a service, WMI process creation or task scheduler is outside that group. [Microsoft describes Job Objects and child inheritance](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- **Client behavior:** the server cannot force correct model choices, alter client policies or account restrictions, or add image support to an incompatible client.
- **Resources:** per-request chunks can be paged, but disk capacity, memory, networks and installed software remain finite. Logs have no automatic retention policy. Command provides pipes, not terminal/ConPTY emulation.
- **Upstream behavior:** PowerShell retains its synchronous result format; use Command for separate complete stdout/stderr. Slow or inaccessible Snapshot trees may require Screenshot and coordinates where input works.
- **Exposure:** every reachable caller of this no-auth tunnel receives the server's privileges. Origin checks are not authentication. See [access and exposure](security.md).

## Reproduce

```powershell
.\scripts\setup.ps1
.\scripts\preflight.ps1
.\.venv\Scripts\python.exe -m ruff check scripts tests
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe .\scripts\verify_mcp.py http://127.0.0.1:8011/mcp --exercise --desktop --report .run\verification-full.json
.\.venv\Scripts\python.exe .\scripts\verify_mcp.py https://YOUR-DOMAIN.ngrok-free.dev/mcp --exercise --desktop --report .run\verification-public-full.json
```

Run desktop checks in an available interactive session. Add `--require-admin` when validating an elevated server. Failed checks produce a nonzero exit code and individual errors. Evidence files stay local because they include machine-specific details. The native window and its file/registry fixtures are disposable and cleaned up.
