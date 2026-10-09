"""Serves the built Flutter web app from the API server, so one address
(and one process) is enough to play locally or on your Wi-Fi."""
import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

DEFAULT_WEB_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "codewar", "build", "web")
)


def mount_web(app: FastAPI, directory: str | None = None) -> bool:
    """Mounts `directory` (default: the Flutter web build, or $CODEWAR_WEB_DIR)
    at "/" when it contains an index.html. Must be called after every API
    router is registered so API routes take precedence. Returns whether it mounted."""
    directory = directory or os.environ.get("CODEWAR_WEB_DIR") or DEFAULT_WEB_DIR
    if not os.path.isfile(os.path.join(directory, "index.html")):
        return False
    app.mount("/", StaticFiles(directory=directory, html=True), name="web")
    return True
