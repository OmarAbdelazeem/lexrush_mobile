import 'package:equatable/equatable.dart';

class CommaToken extends Equatable {
  const CommaToken({
    required this.text,
    required this.index,
    required this.commaRequiredAfter,
    required this.commaPlacedAfter,
  });

  final String text;
  final int index;
  final bool commaRequiredAfter;
  final bool commaPlacedAfter;

  CommaToken copyWith({bool? commaPlacedAfter}) {
    return CommaToken(
      text: text,
      index: index,
      commaRequiredAfter: commaRequiredAfter,
      commaPlacedAfter: commaPlacedAfter ?? this.commaPlacedAfter,
    );
  }

  @override
  List<Object> get props => <Object>[
    text,
    index,
    commaRequiredAfter,
    commaPlacedAfter,
  ];
}
