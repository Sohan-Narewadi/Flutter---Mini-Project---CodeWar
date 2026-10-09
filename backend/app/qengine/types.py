from dataclasses import dataclass, field


@dataclass
class GeneratedQuestion:
    """A candidate problem, before verification.

    `inputs` are argument lists; expected outputs are NOT part of this type
    because they are always computed by running `reference_solution` through
    the judge (see verify.build_judge_cases).
    """
    title: str
    difficulty: str          # "easy" | "medium" | "hard"
    topic: str
    prompt: str
    params: list[str]
    entry_python: str        # snake_case function name
    entry_ts: str            # camelCase function name
    reference_solution: str  # Python source defining entry_python
    inputs: list[list]
    source: str              # "llm" | "template"
    tags: list[str] = field(default_factory=list)
