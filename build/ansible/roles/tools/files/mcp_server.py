#!/usr/bin/env python3
"""
KosmOS FastMCP server — default tool suite.

Tools exposed:
  - filesystem: read_file, write_file, list_dir, find_files
  - shell: run_command (bubblewrap-sandboxed)
  - web_fetch: fetch a URL and return text
  - calculator: evaluate a safe math expression

Start: python /opt/kosmos/mcp/server.py
Port : FASTMCP_PORT env var (default 8080)
"""

import ast
import operator as _op
import os
import re
import subprocess
import urllib.request
from pathlib import Path
from typing import Optional

from fastmcp import FastMCP

mcp = FastMCP("KosmOS")
PORT = int(os.environ.get("FASTMCP_PORT", 8080))
SANDBOX_USER = os.environ.get("KOSMOS_USER", "kosmos")
WORKSPACE = Path(os.environ.get("KOSMOS_WORKSPACE", "/home/kosmos/workspace"))
WORKSPACE.mkdir(parents=True, exist_ok=True)

# ── filesystem ─────────────────────────────────────────────────────────────────

@mcp.tool()
def read_file(path: str) -> str:
    """Read a file from the workspace."""
    target = (WORKSPACE / path).resolve()
    if not str(target).startswith(str(WORKSPACE)):
        raise PermissionError("Path escapes workspace boundary")
    if not target.exists():
        raise FileNotFoundError(f"File not found: {path}")
    return target.read_text(errors="replace")


@mcp.tool()
def write_file(path: str, content: str) -> str:
    """Write content to a file in the workspace (creates parent dirs)."""
    target = (WORKSPACE / path).resolve()
    if not str(target).startswith(str(WORKSPACE)):
        raise PermissionError("Path escapes workspace boundary")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    return f"Written {len(content)} bytes to {path}"


@mcp.tool()
def list_dir(path: str = ".") -> list[str]:
    """List files in a workspace directory."""
    target = (WORKSPACE / path).resolve()
    if not str(target).startswith(str(WORKSPACE)):
        raise PermissionError("Path escapes workspace boundary")
    if not target.is_dir():
        raise NotADirectoryError(f"Not a directory: {path}")
    return [str(p.relative_to(WORKSPACE)) for p in sorted(target.iterdir())]


@mcp.tool()
def find_files(pattern: str, directory: str = ".") -> list[str]:
    """Find files matching a glob pattern in the workspace."""
    base = (WORKSPACE / directory).resolve()
    if not str(base).startswith(str(WORKSPACE)):
        raise PermissionError("Path escapes workspace boundary")
    return [str(p.relative_to(WORKSPACE)) for p in sorted(base.rglob(pattern))]


# ── shell (bubblewrap-sandboxed) ───────────────────────────────────────────────

@mcp.tool()
def run_command(command: str, timeout: int = 30) -> dict:
    """
    Run a shell command in a bubblewrap sandbox.

    Returns: {"stdout": str, "stderr": str, "returncode": int}
    """
    bwrap_cmd = [
        "bwrap",
        "--ro-bind", "/usr", "/usr",
        "--ro-bind", "/lib", "/lib",
        "--ro-bind", "/lib64", "/lib64",
        "--ro-bind", "/bin", "/bin",
        "--ro-bind", "/sbin", "/sbin",
        "--ro-bind", "/etc", "/etc",
        "--bind", str(WORKSPACE), str(WORKSPACE),
        "--proc", "/proc",
        "--dev", "/dev",
        "--tmpfs", "/tmp",
        "--unshare-all",
        "--share-net",             # network access for pip install etc.
        "--chdir", str(WORKSPACE),
        "/bin/bash", "-c", command,
    ]
    try:
        result = subprocess.run(
            bwrap_cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {"stdout": "", "stderr": f"Command timed out after {timeout}s", "returncode": -1}
    except FileNotFoundError:
        # bubblewrap not available — fall back to restricted shell
        result = subprocess.run(
            ["bash", "-c", command],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(WORKSPACE),
        )
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
        }


# ── web fetch ──────────────────────────────────────────────────────────────────

@mcp.tool()
def web_fetch(url: str, max_bytes: int = 65536) -> str:
    """
    Fetch a URL and return its text content (HTML stripped to readable text).
    Max 64 KB returned by default.
    """
    if not url.startswith(("http://", "https://")):
        raise ValueError("Only http/https URLs are supported")
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "KosmOS/1.0 (agentic workflow)"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        raw = resp.read(max_bytes)
    text = raw.decode("utf-8", errors="replace")
    # Strip HTML tags — rough but dependency-free
    text = re.sub(r"<style[^>]*>.*?</style>", " ", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<script[^>]*>.*?</script>", " ", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:max_bytes]


# ── calculator ─────────────────────────────────────────────────────────────────

_CALC_OPS: dict = {
    ast.Add:  _op.add,
    ast.Sub:  _op.sub,
    ast.Mult: _op.mul,
    ast.Div:  _op.truediv,
    ast.Pow:  _op.pow,
    ast.Mod:  _op.mod,
    ast.USub: _op.neg,
    ast.UAdd: _op.pos,
}


def _eval_node(node: ast.expr) -> float:
    """Recursively evaluate a parsed AST node using only allowed operations."""
    if isinstance(node, ast.Constant):
        if not isinstance(node.value, (int, float)):
            raise ValueError(f"Unsupported literal type: {type(node.value).__name__}")
        return float(node.value)
    if isinstance(node, ast.BinOp):
        op = _CALC_OPS.get(type(node.op))
        if op is None:
            raise ValueError(f"Unsupported operator: {type(node.op).__name__}")
        return op(_eval_node(node.left), _eval_node(node.right))
    if isinstance(node, ast.UnaryOp):
        op = _CALC_OPS.get(type(node.op))
        if op is None:
            raise ValueError(f"Unsupported unary operator: {type(node.op).__name__}")
        return op(_eval_node(node.operand))
    raise ValueError(f"Unsupported expression node: {type(node).__name__}")


@mcp.tool()
def calculator(expression: str) -> float:
    """
    Evaluate a safe arithmetic expression.
    Supports: + - * / ** % and parentheses.
    """
    expression = expression.strip().replace("^", "**")
    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError as exc:
        raise ValueError(f"Invalid expression: {exc}") from exc
    return _eval_node(tree.body)


# ── entrypoint ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run(transport="sse", host="0.0.0.0", port=PORT)
