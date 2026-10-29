#!/usr/bin/env python3
"""A tiny local MCP server the Claude app runs, so the studio page's Launch button can start the game.

One tool, launch_game: opens Godot running Lodestone on this Mac. Speaks MCP over stdio
(newline-delimited JSON-RPC 2.0), standard library only. Registered in the Claude app's
claude_desktop_config.json as "lodestone" by tools/launcher/install_mcp.py.
"""
import json
import os
import subprocess
import sys

GAME = os.environ.get("LODESTONE_GAME") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game")
GAME = os.path.normpath(GAME)

TOOLS = [{
    "name": "launch_game",
    "description": "Start Lodestone (the Godot project) in a new game window on this Mac.",
    "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
}]


def launch_game():
    subprocess.Popen(["/usr/bin/open", "-n", "-a", "Godot", "--args", "--path", GAME],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"content": [{"type": "text", "text": "Lodestone is starting."}],
            "structuredContent": {"launched": True, "game": GAME}}


def handle(msg):
    method, params = msg.get("method"), msg.get("params") or {}
    if method == "initialize":
        return {"protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "lodestone", "version": "1.0.0"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        if params.get("name") == "launch_game":
            return launch_game()
        raise ValueError("unknown tool: %s" % params.get("name"))
    raise LookupError(method)


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if "id" not in msg:  # a notification (e.g. notifications/initialized): no reply
            continue
        reply = {"jsonrpc": "2.0", "id": msg["id"]}
        try:
            reply["result"] = handle(msg)
        except LookupError as e:
            reply["error"] = {"code": -32601, "message": "method not found: %s" % e}
        except Exception as e:  # noqa: BLE001 - report any tool failure back to the caller
            reply["error"] = {"code": -32603, "message": str(e)}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
