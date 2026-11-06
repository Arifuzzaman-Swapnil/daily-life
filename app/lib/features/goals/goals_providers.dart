// Riverpod access to goals and the Goals screen's tab and category filter
// (prototype `goalTab`, `goalCat`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/goals_dao.dart';
import '../../core/db/db_providers.dart';

@immutable
class GoalFilter {
  const GoalFilter({this.achieved = false, this.category});

  /// The Achieved tab instead of Active.
  final bool achieved;

  /// Null = all categories.
  final GoalCategory? category;
}

final goalFilterProvider = NotifierProvider<GoalFilterController, GoalFilter>(GoalFilterController.new);

class GoalFilterController extends Notifier<GoalFilter> {
  @override
  GoalFilter build() => const GoalFilter();

  void setAchieved(bool achieved) => state = GoalFilter(achieved: achieved, category: state.category);

  void setCategory(GoalCategory? c) => state = GoalFilter(achieved: state.achieved, category: c);
}

/// Every goal with its milestones, newest first.
final goalsProvider = StreamProvider<List<GoalWithMilestones>>((ref) => ref.watch(goalsDaoProvider).watchGoals());

/// One goal; null once deleted.
final goalProvider = StreamProvider.family<GoalWithMilestones?, String>((ref, id) => ref.watch(goalsDaoProvider).watchGoal(id));
