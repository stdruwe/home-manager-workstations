#!/usr/bin/env python3
import base64
import json
import os
import re
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

SERVER_NAME = "node-red-file-mcp"
SERVER_VERSION = "1.1.0"
MAX_FILE_SIZE = 1024 * 1024
FILENAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,126}\.json$")


def send(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def text_result(value: Any, *, is_error: bool = False) -> dict[str, Any]:
    text = value if isinstance(value, str) else json.dumps(value, indent=2, ensure_ascii=False)
    result: dict[str, Any] = {"content": [{"type": "text", "text": text}]}
    if is_error:
        result["isError"] = True
    return result


def runtime_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR")
    if not base:
        raise RuntimeError("XDG_RUNTIME_DIR is not set")
    root = Path(base) / "hermes-node-red"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        root.chmod(0o700)
    except OSError:
        pass
    return root


def resolve_flow_file(filename: str) -> Path:
    if not isinstance(filename, str) or not FILENAME_RE.fullmatch(filename):
        raise ValueError(
            "filename must be a basename ending in .json and may contain only letters, digits, '.', '_' and '-'"
        )
    root = runtime_dir().resolve()
    path = (root / filename).resolve()
    if path.parent != root:
        raise ValueError("filename escapes the allowed flow directory")
    if not path.is_file():
        raise FileNotFoundError(f"flow file not found: {filename}")
    if path.stat().st_size > MAX_FILE_SIZE:
        raise ValueError(f"flow file exceeds {MAX_FILE_SIZE} bytes")
    return path


def load_flow_file(filename: str) -> tuple[dict[str, Any], Path]:
    path = resolve_flow_file(filename)
    try:
        raw = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(f"flow file is not valid UTF-8: {exc}") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON: {exc.msg} at line {exc.lineno}, column {exc.colno}") from exc
    if not isinstance(data, dict):
        raise ValueError("flow JSON must be an object")
    return data, path


def validate_flow_data(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    seen_ids: dict[str, str] = {}

    flow_id = data.get("id")
    if not isinstance(flow_id, str) or not flow_id:
        errors.append("Flow missing required id field")
    else:
        seen_ids[flow_id] = "Flow"

    label = data.get("label")
    if label is not None and not isinstance(label, str):
        errors.append("Flow label must be a string when present")

    disabled = data.get("disabled")
    if disabled is not None and not isinstance(disabled, bool):
        errors.append("Flow disabled must be a boolean when present")

    info = data.get("info")
    if info is not None and not isinstance(info, str):
        errors.append("Flow info must be a string when present")

    for field, kind in (("nodes", "Node"), ("configs", "Config node")):
        items = data.get(field)
        if items is None:
            continue
        if not isinstance(items, list):
            errors.append(f"Flow {field} must be an array when present")
            continue
        for idx, item in enumerate(items):
            if not isinstance(item, dict):
                errors.append(f"{kind} at index {idx} must be an object")
                continue
            item_id = item.get("id")
            if not isinstance(item_id, str) or not item_id:
                errors.append(f"{kind} at index {idx} missing required id field")
            else:
                previous = seen_ids.get(item_id)
                if previous is not None:
                    errors.append(f"{kind} {item_id} duplicates id already used by {previous}")
                else:
                    seen_ids[item_id] = f"{kind} at index {idx}"
            item_type = item.get("type")
            if not isinstance(item_type, str) or not item_type:
                ident = item_id if isinstance(item_id, str) and item_id else f"index {idx}"
                errors.append(f"{kind} {ident} missing required type field")

    return errors


def node_red_request(flow_id: str, data: dict[str, Any]) -> dict[str, Any]:
    raw_url = os.environ.get("NODE_RED_URL", "")
    if not raw_url:
        raise RuntimeError("NODE_RED_URL is not set")

    parts = urllib.parse.urlsplit(raw_url)
    if parts.scheme not in ("http", "https") or not parts.hostname:
        raise ValueError("NODE_RED_URL must be an http(s) URL")

    username = urllib.parse.unquote(parts.username or "")
    password = urllib.parse.unquote(parts.password or "")

    host = parts.hostname
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"
    if parts.port:
        host = f"{host}:{parts.port}"

    base_path = parts.path.rstrip("/")
    base_url = urllib.parse.urlunsplit((parts.scheme, host, base_path, "", ""))
    url = f"{base_url}/flow/{urllib.parse.quote(flow_id, safe='')}"

    headers = {
        "Content-Type": "application/json",
        "Node-RED-API-Version": "v2",
    }

    token = os.environ.get("NODE_RED_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    elif username or password:
        encoded = base64.b64encode(f"{username}:{password}".encode()).decode()
        headers["Authorization"] = f"Basic {encoded}"

    body = json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(url, data=body, headers=headers, method="PUT")

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status = response.status
            response_body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        response_body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Failed to update flow: HTTP {exc.code}: {response_body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to reach Node-RED: {exc.reason}") from exc

    if status not in (200, 204):
        raise RuntimeError(f"Failed to update flow: HTTP {status}: {response_body}")

    if status == 204 or not response_body.strip():
        return {"id": flow_id, "status": status}

    try:
        parsed = json.loads(response_body)
    except json.JSONDecodeError:
        parsed = {"raw": response_body}
    return {"id": flow_id, "status": status, "response": parsed}


TOOLS = [
    {
        "name": "validate_flow_file",
        "description": (
            "Validate a complete Node-RED flow stored as a JSON file without deploying it. "
            "The file must already exist in $XDG_RUNTIME_DIR/hermes-node-red/. Pass only its basename, "
            "for example 'schlafzimmer.json'. Absolute paths and path traversal are rejected."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "filename": {
                    "type": "string",
                    "description": "Basename of the JSON file inside $XDG_RUNTIME_DIR/hermes-node-red/",
                    "pattern": r"^[A-Za-z0-9][A-Za-z0-9._-]{0,126}\.json$",
                }
            },
            "required": ["filename"],
            "additionalProperties": False,
        },
    },
    {
        "name": "update_flow_file",
        "description": (
            "Validate and update one existing Node-RED flow from a complete JSON file using PUT /flow/:id. "
            "The file must already exist in $XDG_RUNTIME_DIR/hermes-node-red/. Pass only its basename. "
            "The flow id stored in the file must exactly match flowId; mismatches and duplicate IDs are rejected. "
            "Other flows are not modified."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "flowId": {"type": "string", "description": "ID of the existing flow to update"},
                "filename": {
                    "type": "string",
                    "description": "Basename of the JSON file inside $XDG_RUNTIME_DIR/hermes-node-red/",
                    "pattern": r"^[A-Za-z0-9][A-Za-z0-9._-]{0,126}\.json$",
                },
            },
            "required": ["flowId", "filename"],
            "additionalProperties": False,
        },
    },
]


def call_tool(name: str, args: Any) -> dict[str, Any]:
    if not isinstance(args, dict):
        return text_result("Tool arguments must be an object", is_error=True)

    try:
        if name == "validate_flow_file":
            filename = args.get("filename")
            data, path = load_flow_file(filename)
            errors = validate_flow_data(data)
            return text_result(
                {
                    "valid": not errors,
                    "errors": errors or None,
                    "filename": path.name,
                    "bytes": path.stat().st_size,
                    "flowId": data.get("id"),
                    "nodes": len(data.get("nodes", [])) if isinstance(data.get("nodes"), list) else None,
                    "configs": len(data.get("configs", [])) if isinstance(data.get("configs"), list) else None,
                }
            )

        if name == "update_flow_file":
            flow_id = args.get("flowId")
            filename = args.get("filename")
            if not isinstance(flow_id, str) or not flow_id:
                raise ValueError("flowId must be a non-empty string")

            data, path = load_flow_file(filename)
            errors = validate_flow_data(data)
            if errors:
                return text_result(
                    {"updated": False, "valid": False, "errors": errors, "filename": path.name},
                    is_error=True,
                )

            file_flow_id = data.get("id")
            if file_flow_id != flow_id:
                return text_result(
                    {
                        "updated": False,
                        "valid": False,
                        "errors": [
                            f"Flow id mismatch: file contains {file_flow_id!r}, requested target is {flow_id!r}"
                        ],
                        "filename": path.name,
                    },
                    is_error=True,
                )

            result = node_red_request(flow_id, data)
            return text_result(
                {
                    "updated": True,
                    "valid": True,
                    "filename": path.name,
                    "bytes": path.stat().st_size,
                    "flowId": flow_id,
                    "nodeRed": result,
                }
            )

        return text_result(f"Unknown tool: {name}", is_error=True)
    except Exception as exc:
        return text_result(f"Error: {exc}", is_error=True)


def handle(message: dict[str, Any]) -> dict[str, Any] | None:
    method = message.get("method")
    msg_id = message.get("id")

    if method == "initialize":
        params = message.get("params") or {}
        protocol_version = params.get("protocolVersion", "2025-11-25")
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        }

    if method in ("notifications/initialized", "notifications/cancelled"):
        return None

    if method == "ping":
        return {"jsonrpc": "2.0", "id": msg_id, "result": {}}

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}}

    if method == "tools/call":
        params = message.get("params") or {}
        result = call_tool(params.get("name", ""), params.get("arguments") or {})
        return {"jsonrpc": "2.0", "id": msg_id, "result": result}

    if msg_id is None:
        return None

    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def main() -> None:
    runtime_dir()
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError("JSON-RPC message must be an object")
            response = handle(message)
            if response is not None:
                send(response)
        except Exception as exc:
            send({"jsonrpc": "2.0", "id": None, "error": {"code": -32603, "message": str(exc)}})


if __name__ == "__main__":
    main()
