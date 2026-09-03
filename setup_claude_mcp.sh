#!/bin/bash
# Setup script for ros-mcp-server with Claude Code
# Usage: bash setup_claude_mcp.sh [ROS_DISTRO] [ROS_DOMAIN_ID]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROS_DISTRO="${1:-jazzy}"
ROS_DOMAIN_ID="${2:-0}"
UV_BIN="${HOME}/.local/bin/uv"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
CLAUDE_JSON="${HOME}/.claude.json"

# ── 1. Check prerequisites ────────────────────────────────────────────────────
echo "[1/5] Checking prerequisites..."

if [ ! -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
    echo "ERROR: ROS ${ROS_DISTRO} not found at /opt/ros/${ROS_DISTRO}/setup.bash"
    echo "  Install ROS: https://docs.ros.org"
    exit 1
fi
echo "  ROS ${ROS_DISTRO}: OK"

if [ ! -x "${UV_BIN}" ]; then
    echo "  uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source "${HOME}/.local/bin/env" 2>/dev/null || true
fi
echo "  uv: OK ($(${UV_BIN} --version))"

# ── 2. Install Python dependencies ───────────────────────────────────────────
echo "[2/5] Installing dependencies..."
"${UV_BIN}" sync --directory "${SCRIPT_DIR}" --quiet
echo "  Dependencies installed."

# ── 3. Create wrapper script ──────────────────────────────────────────────────
echo "[3/5] Creating start_server.sh..."
cat > "${SCRIPT_DIR}/start_server.sh" << EOF
#!/bin/bash
source /opt/ros/${ROS_DISTRO}/setup.bash
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID}
cd ${SCRIPT_DIR}
exec ${UV_BIN} run server.py
EOF
chmod +x "${SCRIPT_DIR}/start_server.sh"
echo "  Created: ${SCRIPT_DIR}/start_server.sh"

# ── 4. Update ~/.claude/settings.json (global MCP config) ────────────────────
echo "[4/5] Updating ${CLAUDE_SETTINGS}..."
mkdir -p "${HOME}/.claude"

if [ ! -f "${CLAUDE_SETTINGS}" ]; then
    echo '{}' > "${CLAUDE_SETTINGS}"
fi

python3 - << PYEOF
import json, sys

settings_path = "${CLAUDE_SETTINGS}"
with open(settings_path) as f:
    settings = json.load(f)

settings.setdefault("mcpServers", {})
settings["mcpServers"]["ros-mcp-server"] = {
    "name": "ROS MCP Server",
    "transport": "stdio",
    "command": "/bin/bash",
    "args": ["${SCRIPT_DIR}/start_server.sh"]
}

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
print("  Updated:", settings_path)
PYEOF

# ── 5. Fix project-level config in ~/.claude.json ────────────────────────────
echo "[5/5] Fixing project config in ${CLAUDE_JSON}..."

if [ -f "${CLAUDE_JSON}" ]; then
    python3 - << PYEOF
import json

claude_json_path = "${CLAUDE_JSON}"
cwd = "${HOME}"
server_entry = {
    "type": "stdio",
    "command": "/bin/bash",
    "args": ["${SCRIPT_DIR}/start_server.sh"],
    "env": {}
}

with open(claude_json_path) as f:
    d = json.load(f)

projects = d.get("projects", {})
if cwd in projects:
    servers = projects[cwd].get("mcpServers", {})
    # Fix any ros-mcp entry (uvx or old configs)
    for key in list(servers.keys()):
        if "ros" in key.lower():
            servers[key] = server_entry
    if not any("ros" in k.lower() for k in servers):
        servers["ros-mcp"] = server_entry
    projects[cwd]["mcpServers"] = servers
    d["projects"] = projects

with open(claude_json_path, "w") as f:
    json.dump(d, f, indent=2)
print("  Updated:", claude_json_path)
PYEOF
else
    echo "  ~/.claude.json not found, skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "Setup complete!"
echo "  ROS distro   : ${ROS_DISTRO}"
echo "  ROS domain   : ${ROS_DOMAIN_ID}"
echo "  Server script: ${SCRIPT_DIR}/start_server.sh"
echo ""
echo "Restart Claude Code to connect to ros-mcp-server."
