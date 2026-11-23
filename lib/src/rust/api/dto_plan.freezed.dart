// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dto_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskDto {

 String get key; bool get done;
/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDtoCopyWith<TaskDto> get copyWith => _$TaskDtoCopyWithImpl<TaskDto>(this as TaskDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TaskDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.done, _this.done) || other.done == _this.done));
}


@override
int get hashCode {
  final _this = this as TaskDto;
  return Object.hash(runtimeType,_this.key,_this.done);
}

@override
String toString() {
  final _this = this as TaskDto;
  return 'TaskDto(key: ${_this.key}, done: ${_this.done})';
}


}

/// @nodoc
abstract mixin class $TaskDtoCopyWith<$Res>  {
  factory $TaskDtoCopyWith(TaskDto value, $Res Function(TaskDto) _then) = _$TaskDtoCopyWithImpl;
@useResult
$Res call({
 String key, bool done
});




}
/// @nodoc
class _$TaskDtoCopyWithImpl<$Res>
    implements $TaskDtoCopyWith<$Res> {
  _$TaskDtoCopyWithImpl(this._self, this._then);

  final TaskDto _self;
  final $Res Function(TaskDto) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? done = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskDto].
extension TaskDtoPatterns on TaskDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TaskDto_Review value)?  review,TResult Function( TaskDto_NewContent value)?  newContent,TResult Function( TaskDto_Integration value)?  integration,TResult Function( TaskDto_Drill value)?  drill,TResult Function( TaskDto_Listen value)?  listen,TResult Function( TaskDto_Checkpoint value)?  checkpoint,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TaskDto_Review() when review != null:
return review(_that);case TaskDto_NewContent() when newContent != null:
return newContent(_that);case TaskDto_Integration() when integration != null:
return integration(_that);case TaskDto_Drill() when drill != null:
return drill(_that);case TaskDto_Listen() when listen != null:
return listen(_that);case TaskDto_Checkpoint() when checkpoint != null:
return checkpoint(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TaskDto_Review value)  review,required TResult Function( TaskDto_NewContent value)  newContent,required TResult Function( TaskDto_Integration value)  integration,required TResult Function( TaskDto_Drill value)  drill,required TResult Function( TaskDto_Listen value)  listen,required TResult Function( TaskDto_Checkpoint value)  checkpoint,}){
final _that = this;
switch (_that) {
case TaskDto_Review():
return review(_that);case TaskDto_NewContent():
return newContent(_that);case TaskDto_Integration():
return integration(_that);case TaskDto_Drill():
return drill(_that);case TaskDto_Listen():
return listen(_that);case TaskDto_Checkpoint():
return checkpoint(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TaskDto_Review value)?  review,TResult? Function( TaskDto_NewContent value)?  newContent,TResult? Function( TaskDto_Integration value)?  integration,TResult? Function( TaskDto_Drill value)?  drill,TResult? Function( TaskDto_Listen value)?  listen,TResult? Function( TaskDto_Checkpoint value)?  checkpoint,}){
final _that = this;
switch (_that) {
case TaskDto_Review() when review != null:
return review(_that);case TaskDto_NewContent() when newContent != null:
return newContent(_that);case TaskDto_Integration() when integration != null:
return integration(_that);case TaskDto_Drill() when drill != null:
return drill(_that);case TaskDto_Listen() when listen != null:
return listen(_that);case TaskDto_Checkpoint() when checkpoint != null:
return checkpoint(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String key,  int due,  int learning,  int newCards,  double minutes,  bool done)?  review,TResult Function( String key,  String lessonId,  String titleZh,  int words,  int grammar,  int kana,  int rules,  double minutes,  bool done)?  newContent,TResult Function( String key,  String lessonId,  String titleZh,  String? dialogueId,  Uint32List phases,  double minutes,  bool done)?  integration,TResult Function( String key,  int questions,  double minutes,  bool done)?  drill,TResult Function( String key,  int sentences,  double minutes,  bool done)?  listen,TResult Function( String key,  String milestoneId,  bool done)?  checkpoint,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TaskDto_Review() when review != null:
return review(_that.key,_that.due,_that.learning,_that.newCards,_that.minutes,_that.done);case TaskDto_NewContent() when newContent != null:
return newContent(_that.key,_that.lessonId,_that.titleZh,_that.words,_that.grammar,_that.kana,_that.rules,_that.minutes,_that.done);case TaskDto_Integration() when integration != null:
return integration(_that.key,_that.lessonId,_that.titleZh,_that.dialogueId,_that.phases,_that.minutes,_that.done);case TaskDto_Drill() when drill != null:
return drill(_that.key,_that.questions,_that.minutes,_that.done);case TaskDto_Listen() when listen != null:
return listen(_that.key,_that.sentences,_that.minutes,_that.done);case TaskDto_Checkpoint() when checkpoint != null:
return checkpoint(_that.key,_that.milestoneId,_that.done);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String key,  int due,  int learning,  int newCards,  double minutes,  bool done)  review,required TResult Function( String key,  String lessonId,  String titleZh,  int words,  int grammar,  int kana,  int rules,  double minutes,  bool done)  newContent,required TResult Function( String key,  String lessonId,  String titleZh,  String? dialogueId,  Uint32List phases,  double minutes,  bool done)  integration,required TResult Function( String key,  int questions,  double minutes,  bool done)  drill,required TResult Function( String key,  int sentences,  double minutes,  bool done)  listen,required TResult Function( String key,  String milestoneId,  bool done)  checkpoint,}) {final _that = this;
switch (_that) {
case TaskDto_Review():
return review(_that.key,_that.due,_that.learning,_that.newCards,_that.minutes,_that.done);case TaskDto_NewContent():
return newContent(_that.key,_that.lessonId,_that.titleZh,_that.words,_that.grammar,_that.kana,_that.rules,_that.minutes,_that.done);case TaskDto_Integration():
return integration(_that.key,_that.lessonId,_that.titleZh,_that.dialogueId,_that.phases,_that.minutes,_that.done);case TaskDto_Drill():
return drill(_that.key,_that.questions,_that.minutes,_that.done);case TaskDto_Listen():
return listen(_that.key,_that.sentences,_that.minutes,_that.done);case TaskDto_Checkpoint():
return checkpoint(_that.key,_that.milestoneId,_that.done);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String key,  int due,  int learning,  int newCards,  double minutes,  bool done)?  review,TResult? Function( String key,  String lessonId,  String titleZh,  int words,  int grammar,  int kana,  int rules,  double minutes,  bool done)?  newContent,TResult? Function( String key,  String lessonId,  String titleZh,  String? dialogueId,  Uint32List phases,  double minutes,  bool done)?  integration,TResult? Function( String key,  int questions,  double minutes,  bool done)?  drill,TResult? Function( String key,  int sentences,  double minutes,  bool done)?  listen,TResult? Function( String key,  String milestoneId,  bool done)?  checkpoint,}) {final _that = this;
switch (_that) {
case TaskDto_Review() when review != null:
return review(_that.key,_that.due,_that.learning,_that.newCards,_that.minutes,_that.done);case TaskDto_NewContent() when newContent != null:
return newContent(_that.key,_that.lessonId,_that.titleZh,_that.words,_that.grammar,_that.kana,_that.rules,_that.minutes,_that.done);case TaskDto_Integration() when integration != null:
return integration(_that.key,_that.lessonId,_that.titleZh,_that.dialogueId,_that.phases,_that.minutes,_that.done);case TaskDto_Drill() when drill != null:
return drill(_that.key,_that.questions,_that.minutes,_that.done);case TaskDto_Listen() when listen != null:
return listen(_that.key,_that.sentences,_that.minutes,_that.done);case TaskDto_Checkpoint() when checkpoint != null:
return checkpoint(_that.key,_that.milestoneId,_that.done);case _:
  return null;

}
}

}

/// @nodoc


class TaskDto_Review extends TaskDto {
  const TaskDto_Review({required this.key, required this.due, required this.learning, required this.newCards, required this.minutes, required this.done}): super._();
  

@override final  String key;
 final  int due;
 final  int learning;
 final  int newCards;
 final  double minutes;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_ReviewCopyWith<TaskDto_Review> get copyWith => _$TaskDto_ReviewCopyWithImpl<TaskDto_Review>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_Review&&(identical(other.key, key) || other.key == key)&&(identical(other.due, due) || other.due == due)&&(identical(other.learning, learning) || other.learning == learning)&&(identical(other.newCards, newCards) || other.newCards == newCards)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,due,learning,newCards,minutes,done);
}

@override
String toString() {
    return 'TaskDto.review(key: $key, due: $due, learning: $learning, newCards: $newCards, minutes: $minutes, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_ReviewCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_ReviewCopyWith(TaskDto_Review value, $Res Function(TaskDto_Review) _then) = _$TaskDto_ReviewCopyWithImpl;
@override @useResult
$Res call({
 String key, int due, int learning, int newCards, double minutes, bool done
});




}
/// @nodoc
class _$TaskDto_ReviewCopyWithImpl<$Res>
    implements $TaskDto_ReviewCopyWith<$Res> {
  _$TaskDto_ReviewCopyWithImpl(this._self, this._then);

  final TaskDto_Review _self;
  final $Res Function(TaskDto_Review) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? due = null,Object? learning = null,Object? newCards = null,Object? minutes = null,Object? done = null,}) {
  return _then(TaskDto_Review(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,due: null == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as int,learning: null == learning ? _self.learning : learning // ignore: cast_nullable_to_non_nullable
as int,newCards: null == newCards ? _self.newCards : newCards // ignore: cast_nullable_to_non_nullable
as int,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as double,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class TaskDto_NewContent extends TaskDto {
  const TaskDto_NewContent({required this.key, required this.lessonId, required this.titleZh, required this.words, required this.grammar, required this.kana, required this.rules, required this.minutes, required this.done}): super._();
  

@override final  String key;
 final  String lessonId;
 final  String titleZh;
 final  int words;
 final  int grammar;
 final  int kana;
 final  int rules;
 final  double minutes;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_NewContentCopyWith<TaskDto_NewContent> get copyWith => _$TaskDto_NewContentCopyWithImpl<TaskDto_NewContent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_NewContent&&(identical(other.key, key) || other.key == key)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.titleZh, titleZh) || other.titleZh == titleZh)&&(identical(other.words, words) || other.words == words)&&(identical(other.grammar, grammar) || other.grammar == grammar)&&(identical(other.kana, kana) || other.kana == kana)&&(identical(other.rules, rules) || other.rules == rules)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,lessonId,titleZh,words,grammar,kana,rules,minutes,done);
}

@override
String toString() {
    return 'TaskDto.newContent(key: $key, lessonId: $lessonId, titleZh: $titleZh, words: $words, grammar: $grammar, kana: $kana, rules: $rules, minutes: $minutes, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_NewContentCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_NewContentCopyWith(TaskDto_NewContent value, $Res Function(TaskDto_NewContent) _then) = _$TaskDto_NewContentCopyWithImpl;
@override @useResult
$Res call({
 String key, String lessonId, String titleZh, int words, int grammar, int kana, int rules, double minutes, bool done
});




}
/// @nodoc
class _$TaskDto_NewContentCopyWithImpl<$Res>
    implements $TaskDto_NewContentCopyWith<$Res> {
  _$TaskDto_NewContentCopyWithImpl(this._self, this._then);

  final TaskDto_NewContent _self;
  final $Res Function(TaskDto_NewContent) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? lessonId = null,Object? titleZh = null,Object? words = null,Object? grammar = null,Object? kana = null,Object? rules = null,Object? minutes = null,Object? done = null,}) {
  return _then(TaskDto_NewContent(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,titleZh: null == titleZh ? _self.titleZh : titleZh // ignore: cast_nullable_to_non_nullable
as String,words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as int,grammar: null == grammar ? _self.grammar : grammar // ignore: cast_nullable_to_non_nullable
as int,kana: null == kana ? _self.kana : kana // ignore: cast_nullable_to_non_nullable
as int,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as int,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as double,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class TaskDto_Integration extends TaskDto {
  const TaskDto_Integration({required this.key, required this.lessonId, required this.titleZh, this.dialogueId, required this.phases, required this.minutes, required this.done}): super._();
  

@override final  String key;
 final  String lessonId;
 final  String titleZh;
 final  String? dialogueId;
 final  Uint32List phases;
 final  double minutes;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_IntegrationCopyWith<TaskDto_Integration> get copyWith => _$TaskDto_IntegrationCopyWithImpl<TaskDto_Integration>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_Integration&&(identical(other.key, key) || other.key == key)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.titleZh, titleZh) || other.titleZh == titleZh)&&(identical(other.dialogueId, dialogueId) || other.dialogueId == dialogueId)&&const DeepCollectionEquality().equals(other.phases, phases)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,lessonId,titleZh,dialogueId,const DeepCollectionEquality().hash(phases),minutes,done);
}

@override
String toString() {
    return 'TaskDto.integration(key: $key, lessonId: $lessonId, titleZh: $titleZh, dialogueId: $dialogueId, phases: $phases, minutes: $minutes, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_IntegrationCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_IntegrationCopyWith(TaskDto_Integration value, $Res Function(TaskDto_Integration) _then) = _$TaskDto_IntegrationCopyWithImpl;
@override @useResult
$Res call({
 String key, String lessonId, String titleZh, String? dialogueId, Uint32List phases, double minutes, bool done
});




}
/// @nodoc
class _$TaskDto_IntegrationCopyWithImpl<$Res>
    implements $TaskDto_IntegrationCopyWith<$Res> {
  _$TaskDto_IntegrationCopyWithImpl(this._self, this._then);

  final TaskDto_Integration _self;
  final $Res Function(TaskDto_Integration) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? lessonId = null,Object? titleZh = null,Object? dialogueId = freezed,Object? phases = null,Object? minutes = null,Object? done = null,}) {
  return _then(TaskDto_Integration(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,titleZh: null == titleZh ? _self.titleZh : titleZh // ignore: cast_nullable_to_non_nullable
as String,dialogueId: freezed == dialogueId ? _self.dialogueId : dialogueId // ignore: cast_nullable_to_non_nullable
as String?,phases: null == phases ? _self.phases : phases // ignore: cast_nullable_to_non_nullable
as Uint32List,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as double,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class TaskDto_Drill extends TaskDto {
  const TaskDto_Drill({required this.key, required this.questions, required this.minutes, required this.done}): super._();
  

@override final  String key;
 final  int questions;
 final  double minutes;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_DrillCopyWith<TaskDto_Drill> get copyWith => _$TaskDto_DrillCopyWithImpl<TaskDto_Drill>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_Drill&&(identical(other.key, key) || other.key == key)&&(identical(other.questions, questions) || other.questions == questions)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,questions,minutes,done);
}

@override
String toString() {
    return 'TaskDto.drill(key: $key, questions: $questions, minutes: $minutes, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_DrillCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_DrillCopyWith(TaskDto_Drill value, $Res Function(TaskDto_Drill) _then) = _$TaskDto_DrillCopyWithImpl;
@override @useResult
$Res call({
 String key, int questions, double minutes, bool done
});




}
/// @nodoc
class _$TaskDto_DrillCopyWithImpl<$Res>
    implements $TaskDto_DrillCopyWith<$Res> {
  _$TaskDto_DrillCopyWithImpl(this._self, this._then);

  final TaskDto_Drill _self;
  final $Res Function(TaskDto_Drill) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? questions = null,Object? minutes = null,Object? done = null,}) {
  return _then(TaskDto_Drill(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as int,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as double,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class TaskDto_Listen extends TaskDto {
  const TaskDto_Listen({required this.key, required this.sentences, required this.minutes, required this.done}): super._();
  

@override final  String key;
 final  int sentences;
 final  double minutes;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_ListenCopyWith<TaskDto_Listen> get copyWith => _$TaskDto_ListenCopyWithImpl<TaskDto_Listen>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_Listen&&(identical(other.key, key) || other.key == key)&&(identical(other.sentences, sentences) || other.sentences == sentences)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,sentences,minutes,done);
}

@override
String toString() {
    return 'TaskDto.listen(key: $key, sentences: $sentences, minutes: $minutes, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_ListenCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_ListenCopyWith(TaskDto_Listen value, $Res Function(TaskDto_Listen) _then) = _$TaskDto_ListenCopyWithImpl;
@override @useResult
$Res call({
 String key, int sentences, double minutes, bool done
});




}
/// @nodoc
class _$TaskDto_ListenCopyWithImpl<$Res>
    implements $TaskDto_ListenCopyWith<$Res> {
  _$TaskDto_ListenCopyWithImpl(this._self, this._then);

  final TaskDto_Listen _self;
  final $Res Function(TaskDto_Listen) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? sentences = null,Object? minutes = null,Object? done = null,}) {
  return _then(TaskDto_Listen(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,sentences: null == sentences ? _self.sentences : sentences // ignore: cast_nullable_to_non_nullable
as int,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as double,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class TaskDto_Checkpoint extends TaskDto {
  const TaskDto_Checkpoint({required this.key, required this.milestoneId, required this.done}): super._();
  

@override final  String key;
 final  String milestoneId;
@override final  bool done;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDto_CheckpointCopyWith<TaskDto_Checkpoint> get copyWith => _$TaskDto_CheckpointCopyWithImpl<TaskDto_Checkpoint>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto_Checkpoint&&(identical(other.key, key) || other.key == key)&&(identical(other.milestoneId, milestoneId) || other.milestoneId == milestoneId)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,milestoneId,done);
}

@override
String toString() {
    return 'TaskDto.checkpoint(key: $key, milestoneId: $milestoneId, done: $done)';
}


}

/// @nodoc
abstract mixin class $TaskDto_CheckpointCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory $TaskDto_CheckpointCopyWith(TaskDto_Checkpoint value, $Res Function(TaskDto_Checkpoint) _then) = _$TaskDto_CheckpointCopyWithImpl;
@override @useResult
$Res call({
 String key, String milestoneId, bool done
});




}
/// @nodoc
class _$TaskDto_CheckpointCopyWithImpl<$Res>
    implements $TaskDto_CheckpointCopyWith<$Res> {
  _$TaskDto_CheckpointCopyWithImpl(this._self, this._then);

  final TaskDto_Checkpoint _self;
  final $Res Function(TaskDto_Checkpoint) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? milestoneId = null,Object? done = null,}) {
  return _then(TaskDto_Checkpoint(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,milestoneId: null == milestoneId ? _self.milestoneId : milestoneId // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
