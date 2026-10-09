import subprocess

import pytest

from app import judge
from app.judge import execute_many, run_all_cases


@pytest.fixture()
def count_spawns(monkeypatch):
    spawned = []
    real = subprocess.Popen

    def counting(*a, **kw):
        spawned.append(a[0] if a else kw.get("args"))
        return real(*a, **kw)

    monkeypatch.setattr(judge.subprocess, "Popen", counting)
    return spawned


def _cases(*pairs):
    return [{"args": list(a), "expected": e} for a, e in pairs]


def test_all_cases_of_a_submission_share_one_process(count_spawns):
    code = "def double(x):\n    return x * 2\n"
    cases = _cases(*[([i], i * 2) for i in range(20)])
    results = run_all_cases("python", code, "double", cases)
    assert [r["passed"] for r in results] == [True] * 20
    assert len(count_spawns) == 1


def test_results_keep_case_order_and_per_case_timing():
    code = "def f(x):\n    return x + 1\n"
    out = execute_many("python", code, "f", [[1], [10], [100]])
    assert [r["value"] for r in out] == [2, 11, 101]
    assert all(r["ok"] and r["duration_ms"] >= 0 for r in out)


def test_an_exception_in_one_case_does_not_affect_the_others():
    code = "def f(x):\n    return 10 // x\n"
    out = execute_many("python", code, "f", [[5], [0], [2]])
    assert [r["ok"] for r in out] == [True, False, True]
    assert out[1]["error"].startswith("ZeroDivisionError")
    assert out[2]["value"] == 5


def test_an_infinite_loop_times_out_only_that_case(monkeypatch):
    monkeypatch.setattr(judge, "TIMEOUT_S", 1)
    code = "def f(x):\n    while x == 0:\n        pass\n    return x\n"
    out = execute_many("python", code, "f", [[1], [0], [3]])
    assert [r["ok"] for r in out] == [True, False, True]
    assert "Timed out" in out[1]["error"]
    assert out[2]["value"] == 3  # later cases still get judged


def test_a_program_that_exits_the_interpreter_only_fails_its_own_case():
    code = "import os\ndef f(x):\n    if x == 2:\n        os._exit(3)\n    return x\n"
    out = execute_many("python", code, "f", [[1], [2], [3]])
    assert [r["ok"] for r in out] == [True, False, True]


def test_sys_exit_and_prints_do_not_break_result_parsing():
    code = "import sys\ndef f(x):\n    print('noise', x)\n    if x == 2:\n        sys.exit(1)\n    return x\n"
    out = execute_many("python", code, "f", [[1], [2], [3]])
    assert [r["ok"] for r in out] == [True, False, True]
    assert [r["value"] for r in out if r["ok"]] == [1, 3]


def test_a_syntax_error_fails_every_case_quickly_with_one_spawn(count_spawns):
    out = execute_many("python", "def f(x:\n    return x\n", "f", [[1], [2], [3], [4]])
    assert all(not r["ok"] and "SyntaxError" in r["error"] for r in out)
    assert len(count_spawns) == 1


def test_unserialisable_and_missing_return_values_are_reported_not_raised():
    out = execute_many("python", "def f(x):\n    return {x}\n", "f", [[1]])
    assert not out[0]["ok"] and "serializable" in out[0]["error"]


def test_wrong_function_name_is_a_clean_error():
    out = execute_many("python", "def g(x):\n    return x\n", "f", [[1], [2]])
    assert all(not r["ok"] and "NameError" in r["error"] for r in out)


def test_typescript_batches_and_isolates_errors(count_spawns):
    code = "function f(x: number): number {\n  if (x === 2) { throw new Error('boom'); }\n  return x * 3;\n}\n"
    out = execute_many("typescript", code, "f", [[1], [2], [3]])
    assert [r["ok"] for r in out] == [True, False, True]
    assert out[1]["error"] == "Error: boom"
    assert [r["value"] for r in out if r["ok"]] == [3, 9]
    assert len(count_spawns) == 1


def test_typescript_infinite_loop_times_out_only_that_case(monkeypatch):
    monkeypatch.setattr(judge, "TIMEOUT_S", 1)
    code = "function f(x: number): number {\n  while (x === 0) {}\n  return x;\n}\n"
    out = execute_many("typescript", code, "f", [[1], [0], [4]])
    assert [r["ok"] for r in out] == [True, False, True]
    assert "Timed out" in out[1]["error"]


def test_empty_case_list_spawns_nothing(count_spawns):
    assert execute_many("python", "def f():\n    return 1\n", "f", []) == []
    assert count_spawns == []
