import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/quiz_state.dart';
import 'package:myapp/user_service.dart';

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quizState = Provider.of<QuizState>(context, listen: false);
    final userService = UserService();

    // Calculate personality from answers
    final personality = _calculatePersonality(quizState.answers);
    
    // Save the raw quiz answers to Firestore
    userService.updateUserQuizAnswers(quizState.answers);

    // Save the calculated personality to Firestore
    userService.updateUserPersonality(personality);

    // Determine the persona to display to the user
    final personaData = _getPersona(personality);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B35FF), Color(0xFFB49AFF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 20),
              Text(
                'Your Dinner Persona',
                style: GoogleFonts.pacifico(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                personaData['name']!,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  personaData['description']!,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white.withAlpha(220),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  quizState.reset();
                  context.go('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B35FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Find My Group',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculatePersonality(List<int> answers) {
    // This is a more detailed personality calculation
    // based on the quiz questions and answers.

    // Extraversion calculation
    int extraversion = 0;
    if (answers[0] == 0) extraversion += 2;
    if (answers[0] == 2) extraversion += 1;
    if (answers[2] == 0) extraversion += 2;
    if (answers[3] == 0) extraversion += 2;
    if (answers[3] == 1) extraversion += 1;
    if (answers[9] == 2) extraversion += 1;

    // Openness calculation
    int openness = 0;
    if (answers[1] == 0) openness += 2;
    if (answers[1] == 2) openness += 1;
    if (answers[4] == 1) openness += 1;
    if (answers[4] == 2) openness += 1;

    // Chill Factor calculation
    int chillFactor = 0;
    if (answers[7] == 0) chillFactor += 2;
    if (answers[7] == 2) chillFactor += 1;
    if (answers[8] == 1) chillFactor += 1;
    if (answers[9] == 0) chillFactor += 1;

    // Conversation Style determination
    String conversationStyle = "";
    if (answers[4] == 0) conversationStyle = "Funny stories & jokes";
    if (answers[4] == 1) conversationStyle = "Deep thoughts & ideas";
    if (answers[4] == 2) conversationStyle = "World events & culture";
    if (answers[4] == 3) conversationStyle = "Hobbies & passions";

    // Interests determination
    List<String> interests = [];
    if (answers[5] <= 1) interests.add("Anime");
    if (answers[6] <= 1) interests.add("Music");
    if (answers[2] == 2) interests.add("Gaming");

    return {
      'extraversion': extraversion,
      'openness': openness,
      'chill_factor': chillFactor,
      'conversation_style': conversationStyle,
      'interests': interests,
    };
  }

  Map<String, String> _getPersona(Map<String, dynamic> personality) {
    // This logic determines the persona based on the calculated personality scores.
    if (personality['extraversion'] > 3) {
      return {
        'name': 'The Social Connector',
        'description':
            'You love to bring people together and spark lively conversations. You\'re the heart of the dinner party!'
      };
    } else if (personality['openness'] > 2) {
      return {
        'name': 'The Adventurous Explorer',
        'description':
            'You\'re always seeking new flavors and experiences. You bring excitement and discovery to the table.'
      };
    } else if (personality['chill_factor'] > 2) {
      return {
        'name': 'The Chill Listener',
        'description':
            'You enjoy comfortable classics and good company. You\'re a relaxed and thoughtful dinner guest.'
      };
    } else {
      return {
        'name': 'The Balanced Contributor',
        'description':
            'You enjoy a mix of good food, interesting conversations, and a relaxed atmosphere. You\'re a versatile and adaptable dinner companion.'
      };
    }
  }
}
