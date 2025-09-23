import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/quiz_state.dart';
import 'package:myapp/auth_notifier.dart';

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
                    // Record the answer
                    quizState.nextQuestion(idx);

                    if (quizState.isLastQuestion) {
                      // FIX: Call the correct method to update the quiz status
                      Provider.of<AuthNotifier>(context, listen: false)
                          .completeQuiz();

                      // Navigate to the results screen
                      context.go('/quiz/results');
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
