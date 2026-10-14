import 'package:fpdart/fpdart.dart';

import '../domain/domain.dart';
import 'list_discs.dart';

/// Change a catalogued [Disc]'s attributes.
///
/// Updates the [skuId], [label] and/or [serialNumber] of the disc identified by
/// [discId]. Fields passed as `null` are left unchanged. Returns
/// [NotFoundFailure] when the disc is not catalogued and [AlreadyExistsFailure]
/// when the new sku id would collide with a *different* disc (each sku is
/// catalogued at most once). A blank sku id is refused with
/// [InvalidInputFailure].
///
/// The disc's [Meta.updatedAt] is refreshed, and if the disc is currently
/// placed in a carousel slot that slot's inline copy is updated in the same
/// step so the catalog and the machine stay in lockstep. Pass a [IUnitOfWork]
/// to make the catalog write and the slot write a single atomic transaction.
class ChangeDiscInLibrary {
  /// Creates a [ChangeDiscInLibrary] use case.
  const ChangeDiscInLibrary({
    required ILibraryRepository repository,
    IUnitOfWork? unitOfWork,
    DateTime Function()? clock,
  }) : _repository = repository,
       _unitOfWork = unitOfWork ?? const NoOpUnitOfWork(),
       _clock = clock ?? _systemNow;

  final ILibraryRepository _repository;
  final IUnitOfWork _unitOfWork;
  final DateTime Function() _clock;

  /// The default clock: the current UTC wall-clock time.
  static DateTime _systemNow() => DateTime.now();

  /// Executes the use case, returning the changed [Disc].
  TaskEither<DecalFailure, Disc> call({
    required String discId,
    String? skuId,
    String? label,
    String? serialNumber,
  }) {
    final catalog = ListDiscs(_repository).call();
    final currentTask = _repository.fetchDisc(discId: discId);

    return currentTask.flatMap((current) {
      final newSku = skuId ?? current.skuId;
      if (newSku.trim().isEmpty) {
        return TaskEither.left(
          InvalidInputFailure('A disc must have a non-empty sku id'),
        );
      }
      return catalog.flatMap((discs) {
        final clash = discs.any((d) => d.meta.id != discId && d.skuId == newSku);
        if (clash) {
          return TaskEither.left(
            AlreadyExistsFailure('Another disc already uses sku "$newSku"'),
          );
        }
        final updated = Disc(
          meta: Meta(
            id: current.meta.id,
            notes: current.meta.notes,
            createdAt: current.meta.createdAt,
            updatedAt: _clock().toUtc().toIso8601String(),
          ).asCatalog,
          skuId: newSku,
          name: label ?? current.label ?? '',
          serialNumber: serialNumber ?? current.serialNumber,
          attributeValues: current.attributeValues,
          discSku: current.discSku,
        );
        return _persist(updated);
      });
    });
  }

  /// Saves the changed disc to the catalog and, when it is placed, syncs the
  /// slot's inline copy — atomically when a real unit of work is supplied.
  TaskEither<DecalFailure, Disc> _persist(Disc updated) {
    final saveCatalog = _repository.saveDisc(disc: updated);
    final syncSlot = _repository.locateDisc(discId: updated.meta.id).flatMap(
      (slot) => (slot == null)
          ? TaskEither<DecalFailure, void>.of(null)
          : _repository
                .updateSlot(slot: slot.copyWith(disc: updated))
                .map((_) => null),
    );
    return TaskEither<DecalFailure, Disc>(
      () => _unitOfWork.runEither<DecalFailure, Disc>(
        body: () => saveCatalog
            .flatMap((_) => syncSlot)
            .map((_) => updated)
            .run(),
      ),
    );
  }
}
