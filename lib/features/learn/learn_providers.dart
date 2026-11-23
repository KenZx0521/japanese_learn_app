import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';

/// L1 的課綱與進度。
final learnCourseProvider = FutureProvider.autoDispose<CourseOverviewDto>(
  (ref) => ref.watch(courseRepositoryProvider).overview(),
);

/// L2 單課內容。
final lessonDetailProvider = FutureProvider.autoDispose
    .family<LessonDetailDto, String>(
      (ref, lessonId) => ref.watch(courseRepositoryProvider).lesson(lessonId),
    );
