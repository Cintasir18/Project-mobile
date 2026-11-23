import 'dart:async';

import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int currentQuestion = 0;
  int score = 0;
  int? selectedAnswer;
  bool isFinished = false;
  Timer? _advanceTimer;

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'What is the main purpose of ELORA?',
      'options': [
        'Online shopping',
        'Student administration',
        'Food delivery',
        'Social media',
      ],
      'answer': 1,
    },
    {
      'question': 'Who manages student payment records?',
      'options': [
        'Students only',
        'Visitors',
        'Institution administration',
        'Public users',
      ],
      'answer': 2,
    },
    {
      'question': 'What does LBS help users find?',
      'options': [
        'Institution locations',
        'Quiz answers',
        'Passwords',
        'Payment amounts',
      ],
      'answer': 0,
    },
    {
      'question': 'Which feature helps answer student questions?',
      'options': ['Profile', 'ELORA AI', 'Payment History', 'Logout'],
      'answer': 1,
    },
    {
      'question': 'Where can students view unpaid fees?',
      'options': ['Explore', 'Profile', 'Payment & Administration', 'Quiz'],
      'answer': 2,
    },
    {
      'question': 'Apa fungsi accelerometer pada aplikasi ELORA?',
      'options': [
        'Mengambil foto profil',
        'Mendeteksi arah dan gerakan perangkat',
        'Mengirim notifikasi',
        'Menyimpan data blockchain',
      ],
      'answer': 1,
    },
    {
      'question': 'BST (British Summer Time) berlaku pada periode?',
      'options': ['Jan–Jun', 'Mar–Okt', 'Apr–Sep', 'Nov–Feb'],
      'answer': 1,
    },
    {
      'question': 'Apa yang dimaksud dengan genesis block pada blockchain?',
      'options': [
        'Blok terakhir',
        'Blok pertama dalam rantai',
        'Blok yang rusak',
        'Blok cadangan',
      ],
      'answer': 1,
    },
    {
      'question': 'Fitur biometrik pada ELORA menggunakan?',
      'options': [
        'Kamera wajah saja',
        'Hanya sidik jari',
        'local_auth package',
        'Bluetooth',
      ],
      'answer': 2,
    },
    {
      'question': 'SHA-256 digunakan untuk?',
      'options': [
        'Enkripsi video',
        'Hashing data blockchain',
        'Kompresi gambar',
        'Login biometrik',
      ],
      'answer': 1,
    },
  ];

  void _selectAnswer(int index) {
    if (selectedAnswer != null) return;

    setState(() {
      selectedAnswer = index;
    });

    _advanceTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    _advanceTimer?.cancel();
    _advanceTimer = null;

    if (selectedAnswer == null) return;

    if (selectedAnswer == questions[currentQuestion]['answer']) {
      score++;
    }

    if (currentQuestion < questions.length - 1) {
      setState(() {
        currentQuestion++;
        selectedAnswer = null;
      });
    } else {
      setState(() {
        isFinished = true;
      });
    }
  }

  void _restartQuiz() {
    _advanceTimer?.cancel();
    _advanceTimer = null;

    setState(() {
      currentQuestion = 0;
      score = 0;
      selectedAnswer = null;
      isFinished = false;
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  String _motivationFor(int percentage) {
    if (percentage == 100) return 'Sempurna! Penguasaan penuh!';
    if (percentage >= 80) return 'Luar biasa! Kamu hebat!';
    if (percentage >= 60) return 'Bagus! Terus tingkatkan!';
    if (percentage >= 40) return 'Terus semangat! Review kembali materinya.';
    return 'Jangan menyerah! Coba lagi dan pelajari lebih keras.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(child: isFinished ? _buildResult() : _buildQuiz()),
    );
  }

  Widget _buildQuiz() {
    final question = questions[currentQuestion];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          Text(
            'QUESTION ${currentQuestion + 1} OF ${questions.length}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: eloraPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentQuestion + 1) / questions.length,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: eloraPrimary,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: eloraPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.quiz_outlined,
                  color: Colors.white70,
                  size: 30,
                ),
                const SizedBox(height: 20),
                Text(
                  question['question'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose the correct answer',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Answer options',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            (question['options'] as List).length,
            (index) => _buildOption(
              index,
              question['options'][index] as String,
              question['answer'] as int,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: selectedAnswer == null ? null : _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                currentQuestion == questions.length - 1
                    ? 'See Results'
                    : 'Next Question',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: eloraDark,
        ),
        const Expanded(
          child: Text(
            'ELORA Quiz',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
        ),
        const Icon(Icons.emoji_events_outlined, color: eloraPrimary, size: 25),
      ],
    );
  }

  Widget _buildOption(int index, String option, int correctAnswer) {
    final isSelected = selectedAnswer == index;
    final showCorrect = selectedAnswer != null && index == correctAnswer;
    final showWrong = isSelected && index != correctAnswer;

    Color borderColor = Colors.grey.shade200;
    Color backgroundColor = Colors.white;
    Color textColor = eloraDark;

    if (showCorrect) {
      borderColor = eloraPrimary;
      backgroundColor = eloraPrimary.withValues(alpha: 0.08);
    } else if (showWrong) {
      borderColor = Colors.red.shade300;
      backgroundColor = Colors.red.withValues(alpha: 0.05);
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected || showCorrect
                    ? eloraPrimary
                    : eloraBackground,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: isSelected || showCorrect ? Colors.white : eloraDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showCorrect)
              const Icon(Icons.check_circle, color: eloraPrimary, size: 20)
            else if (showWrong)
              Icon(Icons.cancel, color: Colors.red.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final percentage = (score / questions.length * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: eloraPrimary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 55,
                color: eloraPrimary,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Quiz Completed!',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: eloraDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You answered $score out of ${questions.length} questions correctly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: eloraPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _motivationFor(percentage),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _restartQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: eloraPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to Home',
                style: TextStyle(
                  color: eloraPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
