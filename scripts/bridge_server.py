#!/usr/bin/env python3
"""
Phase 6 Bridge Server — Voice Task App → Obsidian Sync
Lightweight HTTP server (stdlib only, no Flask dependency).
Listens on port 5000. Accepts POST /api/v1/sync_task.
"""

import json
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
import logging

# ── Configuration ──────────────────────────────────────────────
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen2.5:7b"
OBSIDIAN_BASE = "http://192.168.100.7:27123/vault/0 Inbox"
OBSIDIAN_TOKEN = "f0556927e85d22aced4d43a89adc85a13b8da20ef76f59c70739882c43ae2fbd"
LISTEN_PORT = 5000

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("bridge")


def call_ollama(title: str, notes: str) -> dict:
    """Call Ollama to extract priority and category from task text."""
    prompt = (
        f"Extract the priority and category from this task.\n"
        f"Title: {title}\n"
        f"Notes: {notes or 'none'}\n\n"
        "Return ONLY a JSON object with keys 'priority' (one of: High, Medium, Low) "
        "and 'category' (a short string). No markdown, no explanation.\n"
        "Example: {{\"priority\": \"Medium\", \"category\": \"General\"}}"
    )

    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
    }).encode("utf-8")

    req = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            response_text = result.get("response", "{}")
            # Try to parse the JSON from the response
            return _extract_json(response_text)
    except Exception as e:
        log.error(f"Ollama call failed: {e}")
        return {"priority": "Medium", "category": "General"}


def _extract_json(text: str) -> dict:
    """Best-effort JSON extraction from LLM response."""
    # Try direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Try to find JSON in code blocks or braces
    import re
    match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass
    return {"priority": "Medium", "category": "General"}


def build_markdown(title: str, notes: str, priority: str, category: str) -> str:
    """Format task as Markdown with YAML frontmatter."""
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    md = (
        f"---\n"
        f"title: {title}\n"
        f"priority: {priority}\n"
        f"category: {category}\n"
        f"created: \"{ts}\"\n"
        f"status: todo\n"
        f"---\n\n"
        f"# {title}\n\n"
    )
    if notes:
        md += f"## Notes\n\n{notes}\n"
    return md


def post_to_obsidian(filename: str, content: str) -> str:
    """POST markdown content to Obsidian REST API. Returns the file URL."""
    from urllib.parse import quote
    # OBSIDIAN_BASE has a space in "0 Inbox" — encode the full path
    url_full = f"{OBSIDIAN_BASE}/{filename}"
    # Split into scheme+host and path, encode only the path
    idx = url_full.index("/", url_full.index("://") + 3)
    base = url_full[:idx]
    path = url_full[idx:]
    url = base + quote(path, safe="/")
    req = urllib.request.Request(
        url,
        data=content.encode("utf-8"),
        headers={
            "Authorization": f"Bearer {OBSIDIAN_TOKEN}",
            "Content-Type": "text/markdown",
        },
        method="PUT",  # Obsidian Local REST API uses PUT for file creation
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            log.info(f"Obsidian response: {resp.status}")
            return url
    except urllib.error.HTTPError as e:
        log.error(f"Obsidian HTTP error {e.code}: {e.read().decode()}")
        raise
    except Exception as e:
        log.error(f"Obsidian POST failed: {e}")
        raise


class BridgeHandler(BaseHTTPRequestHandler):
    """Handles incoming sync requests."""

    def _send_json(self, status: int, data: dict):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        if self.path != "/api/v1/sync_task":
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        title = data.get("title", "").strip()
        notes = data.get("notes", "").strip()

        if not title:
            self._send_json(400, {"error": "Missing 'title' field"})
            return

        log.info(f"Received task: title='{title}', notes='{notes[:50]}...'")

        # Step 1: Call Ollama for extraction
        log.info("Calling Ollama for priority/category extraction...")
        extracted = call_ollama(title, notes)
        priority = extracted.get("priority", "Medium")
        category = extracted.get("category", "General")
        log.info(f"Extracted: priority={priority}, category={category}")

        # Step 2: Build markdown
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"Task_{timestamp}.md"
        md_content = build_markdown(title, notes, priority, category)

        # Step 3: POST to Obsidian
        log.info(f"Posting to Obsidian: {filename}")
        try:
            obsidian_url = post_to_obsidian(filename, md_content)
            log.info(f"Obsidian sync successful: {obsidian_url}")
            self._send_json(200, {
                "status": "success",
                "obsidian_url": obsidian_url,
                "priority": priority,
                "category": category,
            })
        except Exception as e:
            self._send_json(502, {
                "status": "error",
                "message": f"Obsidian sync failed: {str(e)}",
            })

    def log_message(self, format, *args):
        """Redirect to our logger."""
        log.info("%s %s", self.address_string(), format % args)


def main():
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), BridgeHandler)
    log.info(f"Phase 6 Bridge server starting on port {LISTEN_PORT}...")
    log.info(f"  Ollama:       {OLLAMA_URL} ({OLLAMA_MODEL})")
    log.info(f"  Obsidian:     {OBSIDIAN_BASE}")
    log.info("  Endpoint:     POST /api/v1/sync_task")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
