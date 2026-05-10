import 'package:equatable/equatable.dart';

class CommaInsertionPoint extends Equatable {
  const CommaInsertionPoint({
    required this.afterTokenIndex,
    required this.beforeToken,
    required this.afterToken,
  });

  final int afterTokenIndex;
  final String beforeToken;
  final String afterToken;

  @override
  List<Object> get props => <Object>[afterTokenIndex, beforeToken, afterToken];
}
