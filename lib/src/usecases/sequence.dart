import '../domain/domain.dart';
import 'package:fpdart/fpdart.dart';

/// Runs [tasks] in order, collecting their right values; the first failure
/// short-circuits and is preserved.
TaskEither<DecalFailure, List<T>> sequenceTaskEither<T>({
  required List<TaskEither<DecalFailure, T>> tasks,
}) => tasks.fold<TaskEither<DecalFailure, List<T>>>(
  TaskEither.of(const []),
  (acc, task) => acc.flatMap((list) => task.map((v) => [...list, v])),
);
