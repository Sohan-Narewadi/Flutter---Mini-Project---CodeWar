"""Shared glue between a stored Question and the judge."""
from fastapi import HTTPException

from app.judge import UnsupportedLanguageError, run_all_cases
from app.models.question import Question
from app.schemas import TestResultOut


def judge_question(question: Question, code: str, language: str) -> tuple[list[TestResultOut], int, int]:
    """Runs `code` against every judge case. Returns (results, passed, total).

    Unsupported languages become an HTTP 400 before anything is executed.
    """
    try:
        entry_point = question.entry_point.get(language, "")
        results = run_all_cases(language, code, entry_point, question.judge_cases)
    except UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    display = question.test_cases
    out = [
        TestResultOut(
            input=display[i]["input"],
            expected=display[i]["expected_output"],
            actual=results[i]["actual"],
            passed=results[i]["passed"],
            duration_ms=results[i]["duration_ms"],
        )
        for i in range(len(results))
    ]
    passed_tests = sum(1 for r in out if r.passed)
    return out, passed_tests, len(out)
