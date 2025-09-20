import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/quiz_state.dart';

class QuizQuestionScreen extends StatelessWidget {
  const QuizQuestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quizState = Provider.of<QuizState>(context);
    final question = quizState.currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${quizState.currentQuestionIndex + 1}/10'),
        leading: quizState.isFirstQuestion
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => quizState.previousQuestion(),
              ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(question.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              question.text,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ...question.answers.asMap().entries.map((entry) {
              int idx = entry.key;
              var answer = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (quizState.isLastQuestion) {
                      quizState.nextQuestion(idx);
                      context.go('/quiz/results');
                    } else {
                      quizState.nextQuestion(idx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 60),
                  ),
                  child: Text('${answer.emoji} ${answer.text}'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
