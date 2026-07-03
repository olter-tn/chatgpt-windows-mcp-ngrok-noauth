import asyncio
import sys

from fastmcp.client import Client, StreamableHttpTransport


async def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python verify_mcp.py https://YOUR-DOMAIN.ngrok-free.dev/mcp")
        return 2

    url = sys.argv[1].rstrip("/")
    headers = {"ngrok-skip-browser-warning": "true"}

    async with Client(StreamableHttpTransport(url, headers=headers)) as client:
        tools = await client.list_tools()
        tool_names = [tool.name for tool in tools]
        print(f"Tool count: {len(tool_names)}")
        print("Tools: " + ", ".join(tool_names))

        snapshot_tool = next((tool for tool in tools if tool.name == "Snapshot"), None)
        if snapshot_tool is None:
            print("Snapshot tool: missing")
            return 1

        print(f"Snapshot output schema: {bool(getattr(snapshot_tool, 'outputSchema', None))}")

        result = await client.call_tool("Snapshot", {})
        content_types = [item.type for item in result.content]
        image_count = sum(1 for item in result.content if item.type == "image")
        structured = result.structured_content or {}

        print(f"Snapshot is_error: {result.is_error}")
        print("Snapshot content types: " + ",".join(content_types))
        print(f"Snapshot image count: {image_count}")
        print(f"Snapshot structured ok: {structured.get('ok')}")
        print(f"Snapshot structured has_image: {structured.get('has_image')}")

        if result.is_error or image_count == 0:
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
