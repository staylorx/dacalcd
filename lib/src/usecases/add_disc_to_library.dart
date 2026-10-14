import 'package:fpdart/fpdart.dart';
import 'package:sku_catalog/sku_catalog.dart' as cat;

import '../domain/domain.dart';
import 'id_generator.dart';
import 'list_discs.dart';
import 'new_meta.dart';

/// Add a new [Disc] to the library catalog.
///
/// The catalog is the library's own collection of discs, independent of
/// whether a disc is currently placed in a carousel slot. This use case
/// catalogues a disc by its [skuId] plus optional physical attributes
/// ([label], [serialNumber]); it does **not** place the disc in the machine —
/// use [InsertDisc] for that.
///
/// A duplicate — an existing catalogued disc with the same sku id — is refused
/// with [AlreadyExistsFailure], so each SKU is catalogued at most once. A
/// blank sku id is refused with [InvalidInputFailure].
///
/// The disc's [Meta] is minted internally via [newMeta]; pass [idGenerator] to
/// control the id (tests use a deterministic generator).
class AddDiscToLibrary {
  /// Creates an [AddDiscToLibrary] use case.
  const AddDiscToLibrary({
    required ILibraryRepository repository,
    IdGenerator? idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final ILibraryRepository _repository;
  final IdGenerator? _idGenerator;

  /// Executes the use case, returning the newly catalogued [Disc].
  ///
  /// [mediaTrait] is the disc's media kind ([kDcCdTrait] by default,
  /// [kDcDvdTrait] for a DVD); it classifies the synthesised media SKU the
  /// disc is an instance of.
  TaskEither<DecalFailure, Disc> call({
    required String skuId,
    String? label,
    String? serialNumber,
    String notes = '',
    cat.Trait mediaTrait = kDcCdTrait,
  }) {
    if (skuId.trim().isEmpty) {
      return TaskEither.left(
        InvalidInputFailure('A disc must have a non-empty sku id'),
      );
    }

    final catalog = ListDiscs(_repository).call();
    return catalog.flatMap((discs) {
      final duplicate = discs.any((d) => d.skuId == skuId);
      if (duplicate) {
        return TaskEither.left(
          AlreadyExistsFailure('A disc for sku "$skuId" is already catalogued'),
        );
      }
      final disc = Disc(
        meta: newMeta(notes: notes, idGenerator: _idGenerator).asCatalog,
        skuId: skuId,
        name: label ?? '',
        serialNumber: serialNumber,
        discSku: dacalDiscSku(
          skuId: skuId,
          mediaTrait: mediaTrait,
          modelNumber: label ?? skuId,
        ),
      );
      return _repository.saveDisc(disc: disc);
    });
  }
}
