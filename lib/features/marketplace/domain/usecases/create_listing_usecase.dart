import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/listing_entity.dart';
import '../repositories/marketplace_repository.dart';

class CreateListingUseCase {
  final MarketplaceRepository repository;

  const CreateListingUseCase(this.repository);

  Future<Either<Failure, void>> call(ListingEntity listing) async {
    if (listing.title.trim().isEmpty) {
      return const Left(
          ValidationFailure(message: 'الرجاء إدخال عنوان الإعلان'));
    }
    if (listing.price.minorUnits <= 0) {
      return const Left(
          ValidationFailure(message: 'يجب أن يكون السعر أكبر من صفر'));
    }
    return repository.createListing(listing);
  }
}
