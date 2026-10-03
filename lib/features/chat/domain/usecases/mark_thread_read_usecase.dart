import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/chat_repository.dart';

class MarkThreadReadUseCase {
  final ChatRepository repository;

  const MarkThreadReadUseCase(this.repository);

  Future<Either<Failure, void>> call(
      {required String threadId, required String uid}) {
    return repository.markThreadRead(threadId: threadId, uid: uid);
  }
}
