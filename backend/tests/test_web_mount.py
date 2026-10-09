from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.webmount import mount_web


def _app(tmp_path, with_index=True):
    app = FastAPI()

    @app.get("/api/ping")
    def ping():
        return {"ok": True}

    web = tmp_path / "web"
    web.mkdir()
    if with_index:
        (web / "index.html").write_text("<html>CODEWAR APP</html>")
        (web / "main.dart.js").write_text("console.log(1)")
    mounted = mount_web(app, str(web))
    return app, mounted


def test_serves_the_built_app_and_keeps_api_routes(tmp_path):
    app, mounted = _app(tmp_path)
    assert mounted is True
    c = TestClient(app)
    assert "CODEWAR APP" in c.get("/").text
    assert c.get("/main.dart.js").status_code == 200
    assert c.get("/api/ping").json() == {"ok": True}  # API routes win over the static mount


def test_no_build_means_no_mount(tmp_path):
    app, mounted = _app(tmp_path, with_index=False)
    assert mounted is False
    assert TestClient(app).get("/").status_code == 404
    assert TestClient(app).get("/api/ping").status_code == 200


def test_missing_directory_is_fine():
    assert mount_web(FastAPI(), "/definitely/not/here") is False
