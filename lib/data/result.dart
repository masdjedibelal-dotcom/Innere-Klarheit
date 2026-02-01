class DataError implements Exception {
  final String message;
  final String? details;
  final String? hint;
  final String? code;
  final Object? cause;

  const DataError({
    required this.message,
    this.details,
    this.hint,
    this.code,
    this.cause,
  });

  @override
  String toString() {
    final extras = [
      if (code != null) 'code=$code',
      if (details != null) 'details=$details',
      if (hint != null) 'hint=$hint',
    ];
    return extras.isEmpty ? message : '$message (${extras.join(', ')})';
  }
}

class Result<T> {
  final T? data;
  final DataError? error;

  const Result._({this.data, this.error});

  bool get isSuccess => error == null;

  static Result<T> ok<T>(T data) => Result._(data: data);

  static Result<T> fail<T>(DataError error) => Result._(error: error);
}

