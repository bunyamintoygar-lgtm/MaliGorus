import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../data/repositories/listing_repository.dart';
import '../../data/models/discussion_model.dart';
import '../../data/models/listing_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

final profileProvider = FutureProvider<ProfileModel?>((ref) async {
  return ref.watch(profileRepositoryProvider).getMyProfile();
});

final userDiscussionsProvider = FutureProvider.family<List<DiscussionModel>, String>((ref, userId) async {
  return ref.watch(discussionRepositoryProvider).getDiscussionsByUser(userId);
});

final userListingsProvider = FutureProvider.family<List<ListingModel>, String>((ref, userId) async {
  return ref.watch(listingRepositoryProvider).getListingsByUser(userId);
});

final authorProfileProvider = FutureProvider.family<ProfileModel?, String>((ref, userId) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getProfile(userId);
});
