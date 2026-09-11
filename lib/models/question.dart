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
  final int order; // Not sensitive — needed to preserve question sequence
  final String? imageUrl; // Not sensitive — question illustration, if any

  Question({
    required this.id,
    required this.type,
    required this.stem,
    this.options,
    this.correctOptions,
    required this.marks,
    this.expectsLatex = false,
    this.order = 0,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'stem': stem,
        'options': options?.map((e) => e.toJson()).toList(),
        'correctOptions': correctOptions,
        'marks': marks,
        'expectsLatex': expectsLatex,
        'order': order,
        'imageUrl': imageUrl,
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
        order: (data['order'] as num?)?.toInt() ?? 0,
        imageUrl: data['imageUrl'] as String?,
      );

  // Security factory: sets correctOptions to null.
  // Everything else here (order, imageUrl, options text, stem, marks) is
  // safe to expose to students — only the answer key is withheld.
  factory Question.forStudent(String id, Map data) => Question(
        id: id,
        type: data['type'] ?? 'mcq_single',
        stem: data['stem'] ?? '',
        options: (data['options'] as List?)
            ?.map((e) => OptionItem.fromJson(Map.from(e)))
            .toList(),
        marks: data['marks'] ?? 1,
        expectsLatex: data['expectsLatex'] ?? false,
        order: (data['order'] as num?)?.toInt() ?? 0,
        imageUrl: data['imageUrl'] as String?,
        correctOptions: null,
      );
}