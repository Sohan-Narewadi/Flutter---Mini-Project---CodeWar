import pytest
from app.judge import run_case, UnsupportedLanguageError

PY_ADD = "def add(a, b):\n    return a + b"


def test_python_pass():
    result = run_case("python", PY_ADD, "add", [2, 3], 5)
    assert result["passed"] is True
    assert result["actual"] == "5"


def test_python_fail():
    result = run_case("python", "def add(a, b):\n    return a - b", "add", [2, 3], 5)
    assert result["passed"] is False


def test_python_timeout():
    result = run_case("python", "def add(a, b):\n    while True:\n        pass", "add", [2, 3], 5)
    assert result["passed"] is False
    assert "Timed out" in result["actual"]


def test_python_syntax_error():
    result = run_case("python", "def add(a, b) return a + b", "add", [2, 3], 5)
    assert result["passed"] is False
    assert result["actual"] != ""


def test_unsupported_language():
    with pytest.raises(UnsupportedLanguageError):
        run_case("cpp", "int x;", "add", [2, 3], 5)


TS_ADD = "function add(a: number, b: number): number {\n  return a + b;\n}"


def test_typescript_pass():
    result = run_case("typescript", TS_ADD, "add", [2, 3], 5)
    assert result["passed"] is True
    assert result["actual"] == "5"


def test_typescript_fail():
    result = run_case("typescript", "function add(a: number, b: number): number {\n  return a - b;\n}", "add", [2, 3], 5)
    assert result["passed"] is False


def test_typescript_null_expected():
    code = "function findMaximum(nums: number[]): number | null {\n  if (nums.length === 0) return null;\n  return Math.max(...nums);\n}"
    result = run_case("typescript", code, "findMaximum", [[]], None)
    assert result["passed"] is True
