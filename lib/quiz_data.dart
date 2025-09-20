class QuizQuestion {
  final String text;
  final List<QuizAnswer> answers;
  final String emoji;

  QuizQuestion({
    required this.text,
    required this.answers,
    required this.emoji,
  });
}

class QuizAnswer {
  final String text;
  final String emoji;

  QuizAnswer({required this.text, required this.emoji});
}

final List<QuizQuestion> quizQuestions = [
  QuizQuestion(
    text: "At a dinner, I usually...",
    emoji: "💬",
    answers: [
      QuizAnswer(text: "Lead the convo", emoji: "🗣️"),
      QuizAnswer(text: "Sit back and listen", emoji: "👂"),
      QuizAnswer(text: "A mix of both", emoji: "😅"),
    ],
  ),
  QuizQuestion(
    text: "How adventurous are you with food?",
    emoji: "🍣",
    answers: [
      QuizAnswer(text: "Love trying new things", emoji: "🍣"),
      QuizAnswer(text: "I stick to my favorites", emoji: "🍕"),
      QuizAnswer(text: "Depends on the vibe", emoji: "🍲"),
    ],
  ),
  QuizQuestion(
    text: "Pick your ideal Friday night",
    emoji: "🌃",
    answers: [
      QuizAnswer(text: "Party with friends", emoji: "🎉"),
      QuizAnswer(text: "Chill with a book/show", emoji: "📚"),
      QuizAnswer(text: "Gaming or hobbies", emoji: "🎮"),
    ],
  ),
  QuizQuestion(
    text: "How do you feel about meeting strangers?",
    emoji: "🤝",
    answers: [
      QuizAnswer(text: "Excited!", emoji: "🤩"),
      QuizAnswer(text: "Open but chill", emoji: "🙂"),
      QuizAnswer(text: "A little nervous", emoji: "😬"),
    ],
  ),
  QuizQuestion(
    text: "What type of convos do you enjoy most?",
    emoji: "🎤",
    answers: [
      QuizAnswer(text: "Funny stories & jokes", emoji: "😂"),
      QuizAnswer(text: "Deep thoughts & ideas", emoji: "💡"),
      QuizAnswer(text: "World events & culture", emoji: "🌍"),
      QuizAnswer(text: "Hobbies & passions", emoji: "🎶"),
    ],
  ),
  QuizQuestion(
    text: "Do you enjoy anime?",
    emoji: "🎌",
    answers: [
      QuizAnswer(text: "Yes", emoji: "✅"),
      QuizAnswer(text: "Sometimes", emoji: "🤷"),
      QuizAnswer(text: "Not really", emoji: "❌"),
    ],
  ),
  QuizQuestion(
    text: "Is music a big part of your life?",
    emoji: "🎸",
    answers: [
      QuizAnswer(text: "Absolutely", emoji: "🎧"),
      QuizAnswer(text: "A little", emoji: "🎵"),
      QuizAnswer(text: "Not much", emoji: "🙅"),
    ],
  ),
  QuizQuestion(
    text: "When people disagree at the table, I...",
    emoji: "⚖️",
    answers: [
      QuizAnswer(text: "Keep things chill", emoji: "🕊️"),
      QuizAnswer(text: "Join in the debate", emoji: "⚡"),
      QuizAnswer(text: "Avoid conflict", emoji: "😅"),
    ],
  ),
  QuizQuestion(
    text: "How do you usually make decisions?",
    emoji: "🤔",
    answers: [
      QuizAnswer(text: "Plan it out", emoji: "📋"),
      QuizAnswer(text: "Go with the flow", emoji: "🎲"),
    ],
  ),
  QuizQuestion(
    text: "Your perfect dinner vibe is...",
    emoji: "✨",
    answers: [
      QuizAnswer(text: "Classy & relaxed", emoji: "🍷"),
      QuizAnswer(text: "Casual & fun", emoji: "🍕"),
      QuizAnswer(text: "Lively & social", emoji: "🍹"),
    ],
  ),
];
