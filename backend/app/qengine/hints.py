"""Escalating hints: LLM-written when available, canned otherwise."""
import os
from typing import Callable

from app.qengine.llm import _default_complete
from app.qengine.templates import TOPIC_LABELS

_GENERAL = [
    "Work the first test case by hand and write down each step you take. Your steps are your algorithm.",
    "Think about what information you need to remember as you scan the input once. What is the simplest thing to keep track of?",
    "Write the brute-force version first. Once it passes, look for repeated work you can remove.",
]

_BY_TOPIC = {
    "arrays": [
        "Can you solve it with a single pass over the list and one or two running variables?",
        "Many array problems become easy if you keep a running best/total, or sort first. Check the edge cases: empty list, one element, negatives.",
    ],
    "strings": [
        "Treat the string as a sequence of characters you scan left to right. A dictionary or a counter often helps.",
        "Check edge cases: empty string, repeated characters, upper vs lower case, and non-letter characters.",
    ],
    "math": [
        "Look for a formula or a short loop. Try a few small inputs and spot the pattern.",
        "Check the boundaries (0, 1, very large values). For divisibility ideas, think about the modulo operator.",
    ],
    "hashmap": [
        "A dictionary or set gives O(1) lookups. What would you store as you scan, and what would you look up?",
        "Store what you have seen so far (value to index, or counts), then ask: does the thing I need already exist?",
    ],
    "two-pointers": [
        "Put one pointer at each end (or both at the start). How should each pointer move after you inspect the pair?",
        "If the data is sorted, a pair sum that is too small means moving the left pointer right; too big means moving the right pointer left.",
    ],
    "dp": [
        "Define what dp[i] means in words first, then find how dp[i] depends on earlier entries.",
        "Write the recurrence and the base cases (usually dp[0] and dp[1]). Fill the table in order.",
    ],
}


def canned_hint(topic: str, level: int) -> str:
    level = max(1, min(level, 3))
    if level == 1:
        return _GENERAL[0]
    specific = _BY_TOPIC.get(topic, [])
    if level == 2:
        return specific[0] if specific else _GENERAL[1]
    return specific[1] if len(specific) > 1 else _GENERAL[2]


def get_hint(
    topic: str,
    prompt: str,
    code: str,
    level: int,
    complete: Callable[[str], str | None] | None = None,
) -> str:
    """Level 1 = gentle nudge, 3 = near-solution outline. Never reveals full code."""
    complete = complete or (_default_complete if os.environ.get("ANTHROPIC_API_KEY") else None)
    if complete is not None:
        instruction = (
            f"A learner is stuck on a {TOPIC_LABELS.get(topic, topic)} coding problem.\n"
            f"Problem: {prompt}\nTheir current code:\n{code[:2000]}\n\n"
            f"Give hint level {level} of 3 (1 = a gentle nudge about the approach, 2 = name the key idea or data structure, "
            "3 = outline the algorithm in plain words). Do NOT write the solution code. Reply with at most 3 sentences."
        )
        try:
            text = complete(instruction)
            if text and text.strip():
                return text.strip()
        except Exception:
            pass
    return canned_hint(topic, level)
