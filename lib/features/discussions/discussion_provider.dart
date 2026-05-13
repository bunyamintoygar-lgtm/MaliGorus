import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../data/models/discussion_model.dart';

final discussionRepliesProvider = FutureProvider.family<List<ReplyModel>, String>((ref, discussionId) async {
  return ref.watch(discussionRepositoryProvider).getReplies(discussionId);
});

final singleDiscussionProvider = FutureProvider.family<DiscussionModel?, String>((ref, id) async {
  return ref.watch(discussionRepositoryProvider).getDiscussionById(id);
});
