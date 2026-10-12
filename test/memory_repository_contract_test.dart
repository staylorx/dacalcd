import 'support/memory_backends.dart';
import 'support/shared_contract_suite.dart';

void main() {
  sharedRepositoryContractSuite(
    name: 'MemoryLibraryRepository',
    build: () async => MemoryLibraryRepository(),
  );
}
