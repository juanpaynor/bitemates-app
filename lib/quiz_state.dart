import 'package:flutter/material.dart';
import 'package:myapp/quiz_data.dart';

class QuizState with ChangeNotifier {
  int _currentQuestionIndex = 0;
  final List<int> _answers = [];

  int get currentQuestionIndex => _currentQuestionIndex;
  List<int> get answers => _answers;
  QuizQuestion get currentQuestion => quizQuestions[_currentQuestionIndex];
  bool get isFirstQuestion => _currentQuestionIndex == 0;
  bool get isLastQuestion => _currentQuestionIndex == quizQuestions.length - 1;

  void nextQuestion(int answerIndex) {
    _answers.add(answerIndex);
    if (!isLastQuestion) {
      _currentQuestionIndex++;
    }
    notifyListeners();
  }

  void previousQuestion() {
    if (!isFirstQuestion) {
      _currentQuestionIndex--;
      _answers.removeLast();
      notifyListeners();
    }
  }

  void reset() {
    _currentQuestionIndex = 0;
    _answers.clear();
    notifyListeners();
  }
}
