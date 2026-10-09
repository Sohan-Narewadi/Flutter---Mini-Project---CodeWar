from app.models import Question, Player
from app.schemas import QuestionOut, PlayerOut


def test_question_out_from_orm_object():
    q = Question(
        id="q_find_max_test", title="Find Maximum Element", difficulty="Easy",
        tags=["Arrays"], prompt="p", example_input="in", example_output="out",
        starter_code={"python": "code"},
        test_cases=[{"input": "[1,2]", "expected_output": "2"}],
        entry_point={"python": "find_maximum"}, judge_cases=[{"args": [[1, 2]], "expected": 2}],
    )
    out = QuestionOut.model_validate(q)
    assert out.id == "q_find_max_test"
    assert out.test_cases[0].expected_output == "2"
    # backend-only fields must not leak into the API shape
    assert not hasattr(out, "entry_point")
    assert not hasattr(out, "judge_cases")


def test_player_out_from_orm_object():
    p = Player(id=2, username="codeknight", display_name="CodeKnight", level=12,
               xp=600, xp_to_next=1000, hp=800, hp_max=1000, gold=1240, streak=7,
               rating=1000, wins=0, losses=0)
    out = PlayerOut.model_validate(p)
    assert out.username == "codeknight"
