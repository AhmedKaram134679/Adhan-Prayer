// Simple clean Result pattern
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  const Failure(this.message, [this.exception]);
}

class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
