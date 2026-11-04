import 'package:flutter/material.dart';

import '../models/vial_question.dart';

class AcademyQuestionCard extends StatelessWidget {
  final VialQuestion question;
  final int questionNumber;
  final int? selected;
  final bool revealAnswer;
  final bool isLast;
  final bool examMode;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;

  const AcademyQuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.selected,
    required this.revealAnswer,
    required this.isLast,
    required this.onAnswer,
    required this.onNext,
    this.examMode = false,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF123149);
    const blue = Color(0xFF1767D2);
    const green = Color(0xFF14966A);
    const red = Color(0xFFC84852);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF112E46),
                borderRadius: BorderRadius.circular(23),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1E153B5F),
                    blurRadius: 19,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      'assets/cultura_vial/academia/${question.illustration}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.route_rounded, size: 72, color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 13, 17, 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.visibility_rounded, color: Color(0xFF71DAD2), size: 17),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'ANALIZA LA SITUACIÓN',
                                style: TextStyle(
                                  color: Color(0xFFB2D5E5),
                                  fontSize: 11,
                                  letterSpacing: 1.25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF294C68),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#${questionNumber.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Text(
                          question.prompt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.category,
                          style: const TextStyle(color: Color(0xFF77D8CE), fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Text(
              examMode ? 'MARCA TU RESPUESTA' : 'ELIGE LA DECISIÓN MÁS SEGURA',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF657B8C)),
            ),
            const SizedBox(height: 11),
            for (var i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: revealAnswer && i == question.correct
                      ? const Color(0xFFE7F9EE)
                      : revealAnswer && selected == i && i != question.correct
                      ? const Color(0xFFFFEFEF)
                      : selected == i
                      ? const Color(0xFFE8F2FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: !examMode && selected != null ? null : () => onAnswer(i),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: revealAnswer && i == question.correct
                              ? green
                              : revealAnswer && selected == i && i != question.correct
                              ? red
                              : selected == i
                              ? blue
                              : const Color(0xFFD6E1EC),
                          width: selected == i || (revealAnswer && i == question.correct) ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 37,
                            height: 37,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected == i ? blue : const Color(0xFFF1F6FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: TextStyle(color: selected == i ? Colors.white : ink, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              question.options[i],
                              style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                            ),
                          ),
                          if (revealAnswer && i == question.correct)
                            const Icon(Icons.check_circle_rounded, color: green)
                          else if (revealAnswer && selected == i && i != question.correct)
                            const Icon(Icons.cancel_rounded, color: red)
                          else if (examMode && selected == i)
                            const Icon(Icons.radio_button_checked_rounded, color: blue),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (revealAnswer) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: selected == question.correct ? const Color(0xFFE8F8EE) : const Color(0xFFFFF2E4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected == question.correct ? Icons.verified_rounded : Icons.lightbulb_rounded,
                      color: selected == question.correct ? green : const Color(0xFFB86C18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected == question.correct ? '¡Muy bien! Razonaste la situación.' : 'Aprendizaje clave',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
                          ),
                          const SizedBox(height: 5),
                          Text(question.explanation, style: const TextStyle(height: 1.4, color: ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onNext,
                icon: Icon(isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                label: Text(isLast ? 'Terminar sesión' : 'Siguiente situación', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
            if (examMode)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'En el simulacro no se revelan las respuestas hasta la entrega.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF72869A)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
