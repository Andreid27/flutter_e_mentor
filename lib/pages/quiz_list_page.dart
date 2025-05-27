import 'package:flutter/material.dart';

class QuizListPage extends StatelessWidget {
  const QuizListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10, // Example
      itemBuilder: (context, index) => ListTile(
        title: Text('Quiz #$index'),
        onTap: () {
          Navigator.pushNamed(context, '/quiz/$index');
        },
      ),
    );
  }
}
