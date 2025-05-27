import 'package:flutter/material.dart';

class QuizDetailsPage extends StatelessWidget {
  final String quizId;
  const QuizDetailsPage({super.key, required this.quizId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz Details')),
      body: Center(child: Text('Details for Quiz #$quizId')),
    );
  }
}
