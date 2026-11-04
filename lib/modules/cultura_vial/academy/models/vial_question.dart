enum AcademiaMode { aprender, practicar, simulacro }

class VialQuestion {
  final String category;
  final String prompt;
  final List<String> options;
  final int correct;
  final String explanation;
  final String illustration;
  final String id;

  const VialQuestion(
    this.category,
    this.prompt,
    this.options,
    this.correct,
    this.explanation, {
    this.illustration = 'peatonal',
    this.id = '',
  });
}
