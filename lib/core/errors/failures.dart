/// Simple failure hierarchy used across repositories.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

String friendlyAuthMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'The email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
      return 'No account found for this email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for this email.';
    case 'weak-password':
      return 'Password is too weak (min 6 characters).';
    case 'network-request-failed':
      return 'Network error. Check your connection and retry.';
    case 'too-many-requests':
      return 'Too many attempts. Try again later.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled in the Firebase console.';
    default:
      return 'Authentication failed. Please try again.';
  }
}
