import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/survey_model.dart';
import '../../data/repositories/survey_repository.dart';

final surveyListProvider = FutureProvider<List<SurveyModel>>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return await repo.getSurveys();
});
