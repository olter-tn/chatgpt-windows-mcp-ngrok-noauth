from __future__ import annotations

import argparse
import http.client
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}

REQUIRED_ACCEPT_TYPES = ("application/json", "text/event-stream")


def merged_accept(value: str) -> str:
    parts = [part.strip() for part in value.split(",") if part.strip()]
    lowered = {part.split(";", 1)[0].strip().lower() for part in parts}

    for required in REQUIRED_ACCEPT_TYPES:
        if required not in lowered:
            parts.append(required)

    return ", ".join(parts)


class McpAcceptProxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    target_host: str
    target_port: int

    def do_GET(self) -> None:
        self.forward()

    def do_POST(self) -> None:
        self.forward()

    def do_DELETE(self) -> None:
        self.forward()

    def do_OPTIONS(self) -> None:
        self.forward()

    def log_message(self, format: str, *args: object) -> None:
        sys.stdout.write("%s - %s\n" % (self.log_date_time_string(), format % args))
        sys.stdout.flush()

    def forward(self) -> None:
        body = self._read_body()
        headers = self._forward_headers(len(body))

        connection = http.client.HTTPConnection(
            self.target_host,
            self.target_port,
            timeout=120,
        )

        try:
            connection.putrequest(
                self.command,
                self.path,
                skip_host=True,
                skip_accept_encoding=True,
            )
            connection.putheader("Host", f"{self.target_host}:{self.target_port}")
            for name, value in headers.items():
                connection.putheader(name, value)
            connection.endheaders(body if body else None)

            response = connection.getresponse()
            self.send_response(response.status, response.reason)
            for name, value in response.getheaders():
                if name.lower() not in HOP_BY_HOP_HEADERS:
                    self.send_header(name, value)
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True

            content_type = response.getheader("Content-Type", "")
            if self.command == "POST" and "text/event-stream" in content_type:
                self._stream_first_sse_event(response)
            else:
                self._stream_response(response)
        except Exception as exc:
            message = f"MCP accept proxy error: {exc}".encode("utf-8", errors="replace")
            self.send_response(502, "Bad Gateway")
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(message)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True
            self.wfile.write(message)
        finally:
            connection.close()

    def _stream_response(self, response: http.client.HTTPResponse) -> None:
        reader = getattr(response, "read1", response.read)
        while True:
            chunk = reader(8192)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()

    def _stream_first_sse_event(self, response: http.client.HTTPResponse) -> None:
        reader = getattr(response, "read1", response.read)
        tail = b""

        while True:
            chunk = reader(8192)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()

            tail = (tail + chunk)[-8:]
            if b"\r\n\r\n" in tail or b"\n\n" in tail:
                break

    def _read_body(self) -> bytes:
        content_length = self.headers.get("Content-Length")
        if not content_length:
            return b""
        return self.rfile.read(int(content_length))

    def _forward_headers(self, body_length: int) -> dict[str, str]:
        headers: dict[str, str] = {}

        for name, value in self.headers.items():
            lower_name = name.lower()
            if lower_name in HOP_BY_HOP_HEADERS:
                continue
            if lower_name in {"host", "content-length"}:
                continue
            headers[name] = value

        if self.path.split("?", 1)[0].rstrip("/") == "/mcp":
            headers["Accept"] = merged_accept(headers.get("Accept", ""))

        if body_length:
            headers["Content-Length"] = str(body_length)

        return headers


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Forward MCP HTTP traffic and add missing Streamable HTTP Accept media types."
    )
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--target-host", default="127.0.0.1")
    parser.add_argument("--target-port", type=int, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    handler = type(
        "ConfiguredMcpAcceptProxy",
        (McpAcceptProxy,),
        {
            "target_host": args.target_host,
            "target_port": args.target_port,
        },
    )

    server = ThreadingHTTPServer((args.listen_host, args.listen_port), handler)
    print(
        "MCP accept proxy listening on "
        f"http://{args.listen_host}:{args.listen_port} -> "
        f"http://{args.target_host}:{args.target_port}",
        flush=True,
    )
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
