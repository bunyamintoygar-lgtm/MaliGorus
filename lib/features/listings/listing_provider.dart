import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/listing_model.dart';
import '../../data/repositories/listing_repository.dart';


final listingListProvider = FutureProvider<List<ListingModel>>((ref) async {
  final repo = ref.watch(listingRepositoryProvider);
  return await repo.getListings();
});

// Moved to profile_provider.dart
