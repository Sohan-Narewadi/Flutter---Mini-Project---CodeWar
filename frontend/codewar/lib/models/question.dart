class TestCase {
  final String input;
  final String expectedOutput;

  const TestCase({required this.input, required this.expectedOutput});

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      input: json['input']?.toString() ?? '',
      expectedOutput: json['expected_output']?.toString() ?? '',
    );
  }
}

class Question {
  final String id;
  final String title;
  final String difficulty;
  final List<String> tags;
  final String prompt;
  final String exampleInput;
  final String exampleOutput;
  final Map<String, String> starterCode;
  final List<TestCase> testCases;

  const Question({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.tags,
    required this.prompt,
    required this.exampleInput,
    required this.exampleOutput,
    required this.starterCode,
    required this.testCases,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final starter = <String, String>{};
    final starterJson = json['starter_code'] as Map<String, dynamic>?;
    if (starterJson != null) {
      starterJson.forEach((k, v) => starter[k] = v.toString());
    }
    return Question(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      difficulty: json['difficulty'] ?? 'Easy',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      prompt: json['prompt'] ?? '',
      exampleInput: json['example_input']?.toString() ?? '',
      exampleOutput: json['example_output']?.toString() ?? '',
      starterCode: starter,
      testCases: (json['test_cases'] as List?)
              ?.map((e) => TestCase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
