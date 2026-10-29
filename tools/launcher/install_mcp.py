#!/usr/bin/env python3
"""Registers tools/launcher/lodestone_mcp.py with the Claude desktop app as the local MCP server "lodestone".

Adds one entry to ~/Library/Application Support/Claude/claude_desktop_config.json (a backup is kept
next to it) and leaves everything else in that file alone. Restart the Claude app afterwards.
Usage: python3 tools/launcher/install_mcp.py [--remove]
"""
import json
import os
import shutil
import sys

CONFIG = os.path.expanduser("~/Library/Application Support/Claude/claude_desktop_config.json")
SERVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lodestone_mcp.py")

with open(CONFIG) as f:
    config = json.load(f)
shutil.copy2(CONFIG, CONFIG + ".before-lodestone")
servers = config.setdefault("mcpServers", {})
if "--remove" in sys.argv:
    servers.pop("lodestone", None)
    if not servers:
        config.pop("mcpServers")
    print("Removed the lodestone server")
else:
    servers["lodestone"] = {"command": "/usr/bin/python3", "args": [SERVER]}
    print("Added the lodestone server:", SERVER)
with open(CONFIG, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
print("Restart the Claude app to load it.")
