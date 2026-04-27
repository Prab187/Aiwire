import 'dart:convert';

class StarStory {
  final String id;
  final String question;
  final String answer;
  final int score;
  final String? feedback;
  final String role;
  final String type; // Behavioral / Technical / System Design
  final String createdAt;
  final List<String> tags;

  StarStory({
    required this.id,
    required this.question,
    required this.answer,
    required this.score,
    this.feedback,
    required this.role,
    required this.type,
    required this.createdAt,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'question': question, 'answer': answer, 'score': score,
    'feedback': feedback, 'role': role, 'type': type,
    'createdAt': createdAt, 'tags': tags,
  };

  factory StarStory.fromJson(Map<String, dynamic> j) => StarStory(
    id: j['id'] ?? '',
    question: j['question'] ?? '',
    answer: j['answer'] ?? '',
    score: j['score'] ?? 0,
    feedback: j['feedback'],
    role: j['role'] ?? '',
    type: j['type'] ?? '',
    createdAt: j['createdAt'] ?? '',
    tags: List<String>.from(j['tags'] ?? []),
  );

  String encode() => json.encode(toJson());
  static StarStory decode(String s) => StarStory.fromJson(json.decode(s));
}
