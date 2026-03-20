class OptionItem {
  final String id;
  final String text;
  OptionItem({required this.id, required this.text});

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
  factory OptionItem.fromJson(Map data) => OptionItem(
        id: data['id'] ?? '', 
        text: data['text'] ?? '',
      );
}

class Question {
  final String id;
  final String type; 
  final String stem;
  final List<OptionItem>? options; 
  final List<String>? correctOptions; 
  final int marks;
  final bool expectsLatex; 

  Question({
    required this.id,
    required this.type,
    required this.stem,
    this.options,
    this.correctOptions,
    required this.marks,
    this.expectsLatex = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'stem': stem,
        'options': options?.map((e) => e.toJson()).toList(),
        'correctOptions': correctOptions,
        'marks': marks,
        'expectsLatex': expectsLatex,
      };

  factory Question.fromJson(String id, Map data) => Question(
        id: id,
        type: data['type'] ?? 'mcq_single',
        stem: data['stem'] ?? '',
        options: (data['options'] as List?)
            ?.map((e) => OptionItem.fromJson(Map.from(e)))
            .toList(),
        correctOptions: (data['correctOptions'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        marks: data['marks'] ?? 1,
        expectsLatex: data['expectsLatex'] ?? false,
      );

  // Security factory: sets correctOptions to null
  factory Question.forStudent(String id, Map data) => Question(
        id: id,
        type: data['type'] ?? 'mcq_single',
        stem: data['stem'] ?? '',
        options: (data['options'] as List?)
            ?.map((e) => OptionItem.fromJson(Map.from(e)))
            .toList(),
        marks: data['marks'] ?? 1,
        expectsLatex: data['expectsLatex'] ?? false,
        correctOptions: null, 
      );
}