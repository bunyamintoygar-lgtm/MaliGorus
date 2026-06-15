import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/follower_repository.dart';

class FollowCounts {
  final int followersCount;
  final int followingCount;
  FollowCounts({required this.followersCount, required this.followingCount});
}

final followCountsProvider = FutureProvider.family<FollowCounts, String>((ref, userId) async {
  final repo = ref.watch(followerRepositoryProvider);
  final counts = await Future.wait([
    repo.getFollowersCount(userId),
    repo.getFollowingCount(userId),
  ]);
  return FollowCounts(
    followersCount: counts[0],
    followingCount: counts[1],
  );
});

final followersListProvider = FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  return ref.watch(followerRepositoryProvider).getFollowersList(userId);
});

final followingListProvider = FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  return ref.watch(followerRepositoryProvider).getFollowingList(userId);
});

final isFollowingProvider = FutureProvider.family<bool, String>((ref, targetUserId) async {
  return ref.watch(followerRepositoryProvider).isFollowing(targetUserId);
});
