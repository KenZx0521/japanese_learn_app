// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dto_study.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AnswerPayload {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AnswerPayload()';
}


}

/// @nodoc
class $AnswerPayloadCopyWith<$Res>  {
$AnswerPayloadCopyWith(AnswerPayload _, $Res Function(AnswerPayload) __);
}


/// Adds pattern-matching-related methods to [AnswerPayload].
extension AnswerPayloadPatterns on AnswerPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AnswerPayload_Choice value)?  choice,TResult Function( AnswerPayload_Reorder value)?  reorder,TResult Function( AnswerPayload_Typing value)?  typing,TResult Function( AnswerPayload_Match value)?  match,TResult Function( AnswerPayload_SelfGrade value)?  selfGrade,TResult Function( AnswerPayload_Shadow value)?  shadow,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AnswerPayload_Choice() when choice != null:
return choice(_that);case AnswerPayload_Reorder() when reorder != null:
return reorder(_that);case AnswerPayload_Typing() when typing != null:
return typing(_that);case AnswerPayload_Match() when match != null:
return match(_that);case AnswerPayload_SelfGrade() when selfGrade != null:
return selfGrade(_that);case AnswerPayload_Shadow() when shadow != null:
return shadow(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AnswerPayload_Choice value)  choice,required TResult Function( AnswerPayload_Reorder value)  reorder,required TResult Function( AnswerPayload_Typing value)  typing,required TResult Function( AnswerPayload_Match value)  match,required TResult Function( AnswerPayload_SelfGrade value)  selfGrade,required TResult Function( AnswerPayload_Shadow value)  shadow,}){
final _that = this;
switch (_that) {
case AnswerPayload_Choice():
return choice(_that);case AnswerPayload_Reorder():
return reorder(_that);case AnswerPayload_Typing():
return typing(_that);case AnswerPayload_Match():
return match(_that);case AnswerPayload_SelfGrade():
return selfGrade(_that);case AnswerPayload_Shadow():
return shadow(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AnswerPayload_Choice value)?  choice,TResult? Function( AnswerPayload_Reorder value)?  reorder,TResult? Function( AnswerPayload_Typing value)?  typing,TResult? Function( AnswerPayload_Match value)?  match,TResult? Function( AnswerPayload_SelfGrade value)?  selfGrade,TResult? Function( AnswerPayload_Shadow value)?  shadow,}){
final _that = this;
switch (_that) {
case AnswerPayload_Choice() when choice != null:
return choice(_that);case AnswerPayload_Reorder() when reorder != null:
return reorder(_that);case AnswerPayload_Typing() when typing != null:
return typing(_that);case AnswerPayload_Match() when match != null:
return match(_that);case AnswerPayload_SelfGrade() when selfGrade != null:
return selfGrade(_that);case AnswerPayload_Shadow() when shadow != null:
return shadow(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String optionId)?  choice,TResult Function( Uint32List order)?  reorder,TResult Function( String input)?  typing,TResult Function( bool allCorrect)?  match,TResult Function( Rating rating)?  selfGrade,TResult Function( ShadowLevel level)?  shadow,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AnswerPayload_Choice() when choice != null:
return choice(_that.optionId);case AnswerPayload_Reorder() when reorder != null:
return reorder(_that.order);case AnswerPayload_Typing() when typing != null:
return typing(_that.input);case AnswerPayload_Match() when match != null:
return match(_that.allCorrect);case AnswerPayload_SelfGrade() when selfGrade != null:
return selfGrade(_that.rating);case AnswerPayload_Shadow() when shadow != null:
return shadow(_that.level);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String optionId)  choice,required TResult Function( Uint32List order)  reorder,required TResult Function( String input)  typing,required TResult Function( bool allCorrect)  match,required TResult Function( Rating rating)  selfGrade,required TResult Function( ShadowLevel level)  shadow,}) {final _that = this;
switch (_that) {
case AnswerPayload_Choice():
return choice(_that.optionId);case AnswerPayload_Reorder():
return reorder(_that.order);case AnswerPayload_Typing():
return typing(_that.input);case AnswerPayload_Match():
return match(_that.allCorrect);case AnswerPayload_SelfGrade():
return selfGrade(_that.rating);case AnswerPayload_Shadow():
return shadow(_that.level);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String optionId)?  choice,TResult? Function( Uint32List order)?  reorder,TResult? Function( String input)?  typing,TResult? Function( bool allCorrect)?  match,TResult? Function( Rating rating)?  selfGrade,TResult? Function( ShadowLevel level)?  shadow,}) {final _that = this;
switch (_that) {
case AnswerPayload_Choice() when choice != null:
return choice(_that.optionId);case AnswerPayload_Reorder() when reorder != null:
return reorder(_that.order);case AnswerPayload_Typing() when typing != null:
return typing(_that.input);case AnswerPayload_Match() when match != null:
return match(_that.allCorrect);case AnswerPayload_SelfGrade() when selfGrade != null:
return selfGrade(_that.rating);case AnswerPayload_Shadow() when shadow != null:
return shadow(_that.level);case _:
  return null;

}
}

}

/// @nodoc


class AnswerPayload_Choice extends AnswerPayload {
  const AnswerPayload_Choice({required this.optionId}): super._();
  

 final  String optionId;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_ChoiceCopyWith<AnswerPayload_Choice> get copyWith => _$AnswerPayload_ChoiceCopyWithImpl<AnswerPayload_Choice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_Choice&&(identical(other.optionId, optionId) || other.optionId == optionId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,optionId);
}

@override
String toString() {
    return 'AnswerPayload.choice(optionId: $optionId)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_ChoiceCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_ChoiceCopyWith(AnswerPayload_Choice value, $Res Function(AnswerPayload_Choice) _then) = _$AnswerPayload_ChoiceCopyWithImpl;
@useResult
$Res call({
 String optionId
});




}
/// @nodoc
class _$AnswerPayload_ChoiceCopyWithImpl<$Res>
    implements $AnswerPayload_ChoiceCopyWith<$Res> {
  _$AnswerPayload_ChoiceCopyWithImpl(this._self, this._then);

  final AnswerPayload_Choice _self;
  final $Res Function(AnswerPayload_Choice) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? optionId = null,}) {
  return _then(AnswerPayload_Choice(
optionId: null == optionId ? _self.optionId : optionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AnswerPayload_Reorder extends AnswerPayload {
  const AnswerPayload_Reorder({required this.order}): super._();
  

 final  Uint32List order;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_ReorderCopyWith<AnswerPayload_Reorder> get copyWith => _$AnswerPayload_ReorderCopyWithImpl<AnswerPayload_Reorder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_Reorder&&const DeepCollectionEquality().equals(other.order, order));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(order));
}

@override
String toString() {
    return 'AnswerPayload.reorder(order: $order)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_ReorderCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_ReorderCopyWith(AnswerPayload_Reorder value, $Res Function(AnswerPayload_Reorder) _then) = _$AnswerPayload_ReorderCopyWithImpl;
@useResult
$Res call({
 Uint32List order
});




}
/// @nodoc
class _$AnswerPayload_ReorderCopyWithImpl<$Res>
    implements $AnswerPayload_ReorderCopyWith<$Res> {
  _$AnswerPayload_ReorderCopyWithImpl(this._self, this._then);

  final AnswerPayload_Reorder _self;
  final $Res Function(AnswerPayload_Reorder) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? order = null,}) {
  return _then(AnswerPayload_Reorder(
order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as Uint32List,
  ));
}


}

/// @nodoc


class AnswerPayload_Typing extends AnswerPayload {
  const AnswerPayload_Typing({required this.input}): super._();
  

 final  String input;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_TypingCopyWith<AnswerPayload_Typing> get copyWith => _$AnswerPayload_TypingCopyWithImpl<AnswerPayload_Typing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_Typing&&(identical(other.input, input) || other.input == input));
}


@override
int get hashCode {
    return Object.hash(runtimeType,input);
}

@override
String toString() {
    return 'AnswerPayload.typing(input: $input)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_TypingCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_TypingCopyWith(AnswerPayload_Typing value, $Res Function(AnswerPayload_Typing) _then) = _$AnswerPayload_TypingCopyWithImpl;
@useResult
$Res call({
 String input
});




}
/// @nodoc
class _$AnswerPayload_TypingCopyWithImpl<$Res>
    implements $AnswerPayload_TypingCopyWith<$Res> {
  _$AnswerPayload_TypingCopyWithImpl(this._self, this._then);

  final AnswerPayload_Typing _self;
  final $Res Function(AnswerPayload_Typing) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? input = null,}) {
  return _then(AnswerPayload_Typing(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AnswerPayload_Match extends AnswerPayload {
  const AnswerPayload_Match({required this.allCorrect}): super._();
  

 final  bool allCorrect;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_MatchCopyWith<AnswerPayload_Match> get copyWith => _$AnswerPayload_MatchCopyWithImpl<AnswerPayload_Match>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_Match&&(identical(other.allCorrect, allCorrect) || other.allCorrect == allCorrect));
}


@override
int get hashCode {
    return Object.hash(runtimeType,allCorrect);
}

@override
String toString() {
    return 'AnswerPayload.match(allCorrect: $allCorrect)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_MatchCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_MatchCopyWith(AnswerPayload_Match value, $Res Function(AnswerPayload_Match) _then) = _$AnswerPayload_MatchCopyWithImpl;
@useResult
$Res call({
 bool allCorrect
});




}
/// @nodoc
class _$AnswerPayload_MatchCopyWithImpl<$Res>
    implements $AnswerPayload_MatchCopyWith<$Res> {
  _$AnswerPayload_MatchCopyWithImpl(this._self, this._then);

  final AnswerPayload_Match _self;
  final $Res Function(AnswerPayload_Match) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? allCorrect = null,}) {
  return _then(AnswerPayload_Match(
allCorrect: null == allCorrect ? _self.allCorrect : allCorrect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class AnswerPayload_SelfGrade extends AnswerPayload {
  const AnswerPayload_SelfGrade({required this.rating}): super._();
  

 final  Rating rating;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_SelfGradeCopyWith<AnswerPayload_SelfGrade> get copyWith => _$AnswerPayload_SelfGradeCopyWithImpl<AnswerPayload_SelfGrade>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_SelfGrade&&(identical(other.rating, rating) || other.rating == rating));
}


@override
int get hashCode {
    return Object.hash(runtimeType,rating);
}

@override
String toString() {
    return 'AnswerPayload.selfGrade(rating: $rating)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_SelfGradeCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_SelfGradeCopyWith(AnswerPayload_SelfGrade value, $Res Function(AnswerPayload_SelfGrade) _then) = _$AnswerPayload_SelfGradeCopyWithImpl;
@useResult
$Res call({
 Rating rating
});




}
/// @nodoc
class _$AnswerPayload_SelfGradeCopyWithImpl<$Res>
    implements $AnswerPayload_SelfGradeCopyWith<$Res> {
  _$AnswerPayload_SelfGradeCopyWithImpl(this._self, this._then);

  final AnswerPayload_SelfGrade _self;
  final $Res Function(AnswerPayload_SelfGrade) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rating = null,}) {
  return _then(AnswerPayload_SelfGrade(
rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as Rating,
  ));
}


}

/// @nodoc


class AnswerPayload_Shadow extends AnswerPayload {
  const AnswerPayload_Shadow({required this.level}): super._();
  

 final  ShadowLevel level;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnswerPayload_ShadowCopyWith<AnswerPayload_Shadow> get copyWith => _$AnswerPayload_ShadowCopyWithImpl<AnswerPayload_Shadow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnswerPayload_Shadow&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode {
    return Object.hash(runtimeType,level);
}

@override
String toString() {
    return 'AnswerPayload.shadow(level: $level)';
}


}

/// @nodoc
abstract mixin class $AnswerPayload_ShadowCopyWith<$Res> implements $AnswerPayloadCopyWith<$Res> {
  factory $AnswerPayload_ShadowCopyWith(AnswerPayload_Shadow value, $Res Function(AnswerPayload_Shadow) _then) = _$AnswerPayload_ShadowCopyWithImpl;
@useResult
$Res call({
 ShadowLevel level
});




}
/// @nodoc
class _$AnswerPayload_ShadowCopyWithImpl<$Res>
    implements $AnswerPayload_ShadowCopyWith<$Res> {
  _$AnswerPayload_ShadowCopyWithImpl(this._self, this._then);

  final AnswerPayload_Shadow _self;
  final $Res Function(AnswerPayload_Shadow) _then;

/// Create a copy of AnswerPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,}) {
  return _then(AnswerPayload_Shadow(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as ShadowLevel,
  ));
}


}

/// @nodoc
mixin _$NewContentStepDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewContentStepDto()';
}


}

/// @nodoc
class $NewContentStepDtoCopyWith<$Res>  {
$NewContentStepDtoCopyWith(NewContentStepDto _, $Res Function(NewContentStepDto) __);
}


/// Adds pattern-matching-related methods to [NewContentStepDto].
extension NewContentStepDtoPatterns on NewContentStepDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NewContentStepDto_Kana value)?  kana,TResult Function( NewContentStepDto_Rule value)?  rule,TResult Function( NewContentStepDto_Confusable value)?  confusable,TResult Function( NewContentStepDto_KanaQuiz value)?  kanaQuiz,TResult Function( NewContentStepDto_Vocab value)?  vocab,TResult Function( NewContentStepDto_Grammar value)?  grammar,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NewContentStepDto_Kana() when kana != null:
return kana(_that);case NewContentStepDto_Rule() when rule != null:
return rule(_that);case NewContentStepDto_Confusable() when confusable != null:
return confusable(_that);case NewContentStepDto_KanaQuiz() when kanaQuiz != null:
return kanaQuiz(_that);case NewContentStepDto_Vocab() when vocab != null:
return vocab(_that);case NewContentStepDto_Grammar() when grammar != null:
return grammar(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NewContentStepDto_Kana value)  kana,required TResult Function( NewContentStepDto_Rule value)  rule,required TResult Function( NewContentStepDto_Confusable value)  confusable,required TResult Function( NewContentStepDto_KanaQuiz value)  kanaQuiz,required TResult Function( NewContentStepDto_Vocab value)  vocab,required TResult Function( NewContentStepDto_Grammar value)  grammar,}){
final _that = this;
switch (_that) {
case NewContentStepDto_Kana():
return kana(_that);case NewContentStepDto_Rule():
return rule(_that);case NewContentStepDto_Confusable():
return confusable(_that);case NewContentStepDto_KanaQuiz():
return kanaQuiz(_that);case NewContentStepDto_Vocab():
return vocab(_that);case NewContentStepDto_Grammar():
return grammar(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NewContentStepDto_Kana value)?  kana,TResult? Function( NewContentStepDto_Rule value)?  rule,TResult? Function( NewContentStepDto_Confusable value)?  confusable,TResult? Function( NewContentStepDto_KanaQuiz value)?  kanaQuiz,TResult? Function( NewContentStepDto_Vocab value)?  vocab,TResult? Function( NewContentStepDto_Grammar value)?  grammar,}){
final _that = this;
switch (_that) {
case NewContentStepDto_Kana() when kana != null:
return kana(_that);case NewContentStepDto_Rule() when rule != null:
return rule(_that);case NewContentStepDto_Confusable() when confusable != null:
return confusable(_that);case NewContentStepDto_KanaQuiz() when kanaQuiz != null:
return kanaQuiz(_that);case NewContentStepDto_Vocab() when vocab != null:
return vocab(_that);case NewContentStepDto_Grammar() when grammar != null:
return grammar(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( KanaDetailDto detail)?  kana,TResult Function( RuleCardDto card)?  rule,TResult Function( ConfusableDto group)?  confusable,TResult Function( List<QuestionDto> questions)?  kanaQuiz,TResult Function( VocabDetailDto detail,  SessionCardDto? firstCard)?  vocab,TResult Function( GrammarDetailDto detail,  SessionCardDto? firstCard)?  grammar,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NewContentStepDto_Kana() when kana != null:
return kana(_that.detail);case NewContentStepDto_Rule() when rule != null:
return rule(_that.card);case NewContentStepDto_Confusable() when confusable != null:
return confusable(_that.group);case NewContentStepDto_KanaQuiz() when kanaQuiz != null:
return kanaQuiz(_that.questions);case NewContentStepDto_Vocab() when vocab != null:
return vocab(_that.detail,_that.firstCard);case NewContentStepDto_Grammar() when grammar != null:
return grammar(_that.detail,_that.firstCard);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( KanaDetailDto detail)  kana,required TResult Function( RuleCardDto card)  rule,required TResult Function( ConfusableDto group)  confusable,required TResult Function( List<QuestionDto> questions)  kanaQuiz,required TResult Function( VocabDetailDto detail,  SessionCardDto? firstCard)  vocab,required TResult Function( GrammarDetailDto detail,  SessionCardDto? firstCard)  grammar,}) {final _that = this;
switch (_that) {
case NewContentStepDto_Kana():
return kana(_that.detail);case NewContentStepDto_Rule():
return rule(_that.card);case NewContentStepDto_Confusable():
return confusable(_that.group);case NewContentStepDto_KanaQuiz():
return kanaQuiz(_that.questions);case NewContentStepDto_Vocab():
return vocab(_that.detail,_that.firstCard);case NewContentStepDto_Grammar():
return grammar(_that.detail,_that.firstCard);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( KanaDetailDto detail)?  kana,TResult? Function( RuleCardDto card)?  rule,TResult? Function( ConfusableDto group)?  confusable,TResult? Function( List<QuestionDto> questions)?  kanaQuiz,TResult? Function( VocabDetailDto detail,  SessionCardDto? firstCard)?  vocab,TResult? Function( GrammarDetailDto detail,  SessionCardDto? firstCard)?  grammar,}) {final _that = this;
switch (_that) {
case NewContentStepDto_Kana() when kana != null:
return kana(_that.detail);case NewContentStepDto_Rule() when rule != null:
return rule(_that.card);case NewContentStepDto_Confusable() when confusable != null:
return confusable(_that.group);case NewContentStepDto_KanaQuiz() when kanaQuiz != null:
return kanaQuiz(_that.questions);case NewContentStepDto_Vocab() when vocab != null:
return vocab(_that.detail,_that.firstCard);case NewContentStepDto_Grammar() when grammar != null:
return grammar(_that.detail,_that.firstCard);case _:
  return null;

}
}

}

/// @nodoc


class NewContentStepDto_Kana extends NewContentStepDto {
  const NewContentStepDto_Kana({required this.detail}): super._();
  

 final  KanaDetailDto detail;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_KanaCopyWith<NewContentStepDto_Kana> get copyWith => _$NewContentStepDto_KanaCopyWithImpl<NewContentStepDto_Kana>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_Kana&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'NewContentStepDto.kana(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_KanaCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_KanaCopyWith(NewContentStepDto_Kana value, $Res Function(NewContentStepDto_Kana) _then) = _$NewContentStepDto_KanaCopyWithImpl;
@useResult
$Res call({
 KanaDetailDto detail
});




}
/// @nodoc
class _$NewContentStepDto_KanaCopyWithImpl<$Res>
    implements $NewContentStepDto_KanaCopyWith<$Res> {
  _$NewContentStepDto_KanaCopyWithImpl(this._self, this._then);

  final NewContentStepDto_Kana _self;
  final $Res Function(NewContentStepDto_Kana) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(NewContentStepDto_Kana(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as KanaDetailDto,
  ));
}


}

/// @nodoc


class NewContentStepDto_Rule extends NewContentStepDto {
  const NewContentStepDto_Rule({required this.card}): super._();
  

 final  RuleCardDto card;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_RuleCopyWith<NewContentStepDto_Rule> get copyWith => _$NewContentStepDto_RuleCopyWithImpl<NewContentStepDto_Rule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_Rule&&(identical(other.card, card) || other.card == card));
}


@override
int get hashCode {
    return Object.hash(runtimeType,card);
}

@override
String toString() {
    return 'NewContentStepDto.rule(card: $card)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_RuleCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_RuleCopyWith(NewContentStepDto_Rule value, $Res Function(NewContentStepDto_Rule) _then) = _$NewContentStepDto_RuleCopyWithImpl;
@useResult
$Res call({
 RuleCardDto card
});




}
/// @nodoc
class _$NewContentStepDto_RuleCopyWithImpl<$Res>
    implements $NewContentStepDto_RuleCopyWith<$Res> {
  _$NewContentStepDto_RuleCopyWithImpl(this._self, this._then);

  final NewContentStepDto_Rule _self;
  final $Res Function(NewContentStepDto_Rule) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? card = null,}) {
  return _then(NewContentStepDto_Rule(
card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as RuleCardDto,
  ));
}


}

/// @nodoc


class NewContentStepDto_Confusable extends NewContentStepDto {
  const NewContentStepDto_Confusable({required this.group}): super._();
  

 final  ConfusableDto group;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_ConfusableCopyWith<NewContentStepDto_Confusable> get copyWith => _$NewContentStepDto_ConfusableCopyWithImpl<NewContentStepDto_Confusable>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_Confusable&&(identical(other.group, group) || other.group == group));
}


@override
int get hashCode {
    return Object.hash(runtimeType,group);
}

@override
String toString() {
    return 'NewContentStepDto.confusable(group: $group)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_ConfusableCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_ConfusableCopyWith(NewContentStepDto_Confusable value, $Res Function(NewContentStepDto_Confusable) _then) = _$NewContentStepDto_ConfusableCopyWithImpl;
@useResult
$Res call({
 ConfusableDto group
});




}
/// @nodoc
class _$NewContentStepDto_ConfusableCopyWithImpl<$Res>
    implements $NewContentStepDto_ConfusableCopyWith<$Res> {
  _$NewContentStepDto_ConfusableCopyWithImpl(this._self, this._then);

  final NewContentStepDto_Confusable _self;
  final $Res Function(NewContentStepDto_Confusable) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? group = null,}) {
  return _then(NewContentStepDto_Confusable(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as ConfusableDto,
  ));
}


}

/// @nodoc


class NewContentStepDto_KanaQuiz extends NewContentStepDto {
  const NewContentStepDto_KanaQuiz({required  List<QuestionDto> questions}): _questions = questions,super._();
  

 final  List<QuestionDto> _questions;
 List<QuestionDto> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_KanaQuizCopyWith<NewContentStepDto_KanaQuiz> get copyWith => _$NewContentStepDto_KanaQuizCopyWithImpl<NewContentStepDto_KanaQuiz>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_KanaQuiz&&const DeepCollectionEquality().equals(other.questions, _questions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_questions));
}

@override
String toString() {
    return 'NewContentStepDto.kanaQuiz(questions: $questions)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_KanaQuizCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_KanaQuizCopyWith(NewContentStepDto_KanaQuiz value, $Res Function(NewContentStepDto_KanaQuiz) _then) = _$NewContentStepDto_KanaQuizCopyWithImpl;
@useResult
$Res call({
 List<QuestionDto> questions
});




}
/// @nodoc
class _$NewContentStepDto_KanaQuizCopyWithImpl<$Res>
    implements $NewContentStepDto_KanaQuizCopyWith<$Res> {
  _$NewContentStepDto_KanaQuizCopyWithImpl(this._self, this._then);

  final NewContentStepDto_KanaQuiz _self;
  final $Res Function(NewContentStepDto_KanaQuiz) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? questions = null,}) {
  return _then(NewContentStepDto_KanaQuiz(
questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionDto>,
  ));
}


}

/// @nodoc


class NewContentStepDto_Vocab extends NewContentStepDto {
  const NewContentStepDto_Vocab({required this.detail, this.firstCard}): super._();
  

 final  VocabDetailDto detail;
 final  SessionCardDto? firstCard;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_VocabCopyWith<NewContentStepDto_Vocab> get copyWith => _$NewContentStepDto_VocabCopyWithImpl<NewContentStepDto_Vocab>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_Vocab&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.firstCard, firstCard) || other.firstCard == firstCard));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail,firstCard);
}

@override
String toString() {
    return 'NewContentStepDto.vocab(detail: $detail, firstCard: $firstCard)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_VocabCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_VocabCopyWith(NewContentStepDto_Vocab value, $Res Function(NewContentStepDto_Vocab) _then) = _$NewContentStepDto_VocabCopyWithImpl;
@useResult
$Res call({
 VocabDetailDto detail, SessionCardDto? firstCard
});




}
/// @nodoc
class _$NewContentStepDto_VocabCopyWithImpl<$Res>
    implements $NewContentStepDto_VocabCopyWith<$Res> {
  _$NewContentStepDto_VocabCopyWithImpl(this._self, this._then);

  final NewContentStepDto_Vocab _self;
  final $Res Function(NewContentStepDto_Vocab) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? detail = null,Object? firstCard = freezed,}) {
  return _then(NewContentStepDto_Vocab(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as VocabDetailDto,firstCard: freezed == firstCard ? _self.firstCard : firstCard // ignore: cast_nullable_to_non_nullable
as SessionCardDto?,
  ));
}


}

/// @nodoc


class NewContentStepDto_Grammar extends NewContentStepDto {
  const NewContentStepDto_Grammar({required this.detail, this.firstCard}): super._();
  

 final  GrammarDetailDto detail;
 final  SessionCardDto? firstCard;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewContentStepDto_GrammarCopyWith<NewContentStepDto_Grammar> get copyWith => _$NewContentStepDto_GrammarCopyWithImpl<NewContentStepDto_Grammar>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewContentStepDto_Grammar&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.firstCard, firstCard) || other.firstCard == firstCard));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail,firstCard);
}

@override
String toString() {
    return 'NewContentStepDto.grammar(detail: $detail, firstCard: $firstCard)';
}


}

/// @nodoc
abstract mixin class $NewContentStepDto_GrammarCopyWith<$Res> implements $NewContentStepDtoCopyWith<$Res> {
  factory $NewContentStepDto_GrammarCopyWith(NewContentStepDto_Grammar value, $Res Function(NewContentStepDto_Grammar) _then) = _$NewContentStepDto_GrammarCopyWithImpl;
@useResult
$Res call({
 GrammarDetailDto detail, SessionCardDto? firstCard
});




}
/// @nodoc
class _$NewContentStepDto_GrammarCopyWithImpl<$Res>
    implements $NewContentStepDto_GrammarCopyWith<$Res> {
  _$NewContentStepDto_GrammarCopyWithImpl(this._self, this._then);

  final NewContentStepDto_Grammar _self;
  final $Res Function(NewContentStepDto_Grammar) _then;

/// Create a copy of NewContentStepDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? detail = null,Object? firstCard = freezed,}) {
  return _then(NewContentStepDto_Grammar(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as GrammarDetailDto,firstCard: freezed == firstCard ? _self.firstCard : firstCard // ignore: cast_nullable_to_non_nullable
as SessionCardDto?,
  ));
}


}

/// @nodoc
mixin _$QuestionBodyDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QuestionBodyDto()';
}


}

/// @nodoc
class $QuestionBodyDtoCopyWith<$Res>  {
$QuestionBodyDtoCopyWith(QuestionBodyDto _, $Res Function(QuestionBodyDto) __);
}


/// Adds pattern-matching-related methods to [QuestionBodyDto].
extension QuestionBodyDtoPatterns on QuestionBodyDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( QuestionBodyDto_Choice value)?  choice,TResult Function( QuestionBodyDto_Reorder value)?  reorder,TResult Function( QuestionBodyDto_Typing value)?  typing,TResult Function( QuestionBodyDto_Match value)?  match,TResult Function( QuestionBodyDto_SelfGrade value)?  selfGrade,TResult Function( QuestionBodyDto_Shadow value)?  shadow,required TResult orElse(),}){
final _that = this;
switch (_that) {
case QuestionBodyDto_Choice() when choice != null:
return choice(_that);case QuestionBodyDto_Reorder() when reorder != null:
return reorder(_that);case QuestionBodyDto_Typing() when typing != null:
return typing(_that);case QuestionBodyDto_Match() when match != null:
return match(_that);case QuestionBodyDto_SelfGrade() when selfGrade != null:
return selfGrade(_that);case QuestionBodyDto_Shadow() when shadow != null:
return shadow(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( QuestionBodyDto_Choice value)  choice,required TResult Function( QuestionBodyDto_Reorder value)  reorder,required TResult Function( QuestionBodyDto_Typing value)  typing,required TResult Function( QuestionBodyDto_Match value)  match,required TResult Function( QuestionBodyDto_SelfGrade value)  selfGrade,required TResult Function( QuestionBodyDto_Shadow value)  shadow,}){
final _that = this;
switch (_that) {
case QuestionBodyDto_Choice():
return choice(_that);case QuestionBodyDto_Reorder():
return reorder(_that);case QuestionBodyDto_Typing():
return typing(_that);case QuestionBodyDto_Match():
return match(_that);case QuestionBodyDto_SelfGrade():
return selfGrade(_that);case QuestionBodyDto_Shadow():
return shadow(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( QuestionBodyDto_Choice value)?  choice,TResult? Function( QuestionBodyDto_Reorder value)?  reorder,TResult? Function( QuestionBodyDto_Typing value)?  typing,TResult? Function( QuestionBodyDto_Match value)?  match,TResult? Function( QuestionBodyDto_SelfGrade value)?  selfGrade,TResult? Function( QuestionBodyDto_Shadow value)?  shadow,}){
final _that = this;
switch (_that) {
case QuestionBodyDto_Choice() when choice != null:
return choice(_that);case QuestionBodyDto_Reorder() when reorder != null:
return reorder(_that);case QuestionBodyDto_Typing() when typing != null:
return typing(_that);case QuestionBodyDto_Match() when match != null:
return match(_that);case QuestionBodyDto_SelfGrade() when selfGrade != null:
return selfGrade(_that);case QuestionBodyDto_Shadow() when shadow != null:
return shadow(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<OptionDto> options,  String correctOptionId,  int? blankWordIndex)?  choice,TResult Function( List<ChunkDto> chunks,  List<Uint32List> acceptOrders)?  reorder,TResult Function( String expectedReading,  String placeholderZh)?  typing,TResult Function( List<MatchPairDto> pairs)?  match,TResult Function( SentenceDto reveal)?  selfGrade,TResult Function( SentenceDto reveal)?  shadow,required TResult orElse(),}) {final _that = this;
switch (_that) {
case QuestionBodyDto_Choice() when choice != null:
return choice(_that.options,_that.correctOptionId,_that.blankWordIndex);case QuestionBodyDto_Reorder() when reorder != null:
return reorder(_that.chunks,_that.acceptOrders);case QuestionBodyDto_Typing() when typing != null:
return typing(_that.expectedReading,_that.placeholderZh);case QuestionBodyDto_Match() when match != null:
return match(_that.pairs);case QuestionBodyDto_SelfGrade() when selfGrade != null:
return selfGrade(_that.reveal);case QuestionBodyDto_Shadow() when shadow != null:
return shadow(_that.reveal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<OptionDto> options,  String correctOptionId,  int? blankWordIndex)  choice,required TResult Function( List<ChunkDto> chunks,  List<Uint32List> acceptOrders)  reorder,required TResult Function( String expectedReading,  String placeholderZh)  typing,required TResult Function( List<MatchPairDto> pairs)  match,required TResult Function( SentenceDto reveal)  selfGrade,required TResult Function( SentenceDto reveal)  shadow,}) {final _that = this;
switch (_that) {
case QuestionBodyDto_Choice():
return choice(_that.options,_that.correctOptionId,_that.blankWordIndex);case QuestionBodyDto_Reorder():
return reorder(_that.chunks,_that.acceptOrders);case QuestionBodyDto_Typing():
return typing(_that.expectedReading,_that.placeholderZh);case QuestionBodyDto_Match():
return match(_that.pairs);case QuestionBodyDto_SelfGrade():
return selfGrade(_that.reveal);case QuestionBodyDto_Shadow():
return shadow(_that.reveal);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<OptionDto> options,  String correctOptionId,  int? blankWordIndex)?  choice,TResult? Function( List<ChunkDto> chunks,  List<Uint32List> acceptOrders)?  reorder,TResult? Function( String expectedReading,  String placeholderZh)?  typing,TResult? Function( List<MatchPairDto> pairs)?  match,TResult? Function( SentenceDto reveal)?  selfGrade,TResult? Function( SentenceDto reveal)?  shadow,}) {final _that = this;
switch (_that) {
case QuestionBodyDto_Choice() when choice != null:
return choice(_that.options,_that.correctOptionId,_that.blankWordIndex);case QuestionBodyDto_Reorder() when reorder != null:
return reorder(_that.chunks,_that.acceptOrders);case QuestionBodyDto_Typing() when typing != null:
return typing(_that.expectedReading,_that.placeholderZh);case QuestionBodyDto_Match() when match != null:
return match(_that.pairs);case QuestionBodyDto_SelfGrade() when selfGrade != null:
return selfGrade(_that.reveal);case QuestionBodyDto_Shadow() when shadow != null:
return shadow(_that.reveal);case _:
  return null;

}
}

}

/// @nodoc


class QuestionBodyDto_Choice extends QuestionBodyDto {
  const QuestionBodyDto_Choice({required  List<OptionDto> options, required this.correctOptionId, this.blankWordIndex}): _options = options,super._();
  

 final  List<OptionDto> _options;
 List<OptionDto> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

 final  String correctOptionId;
 final  int? blankWordIndex;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_ChoiceCopyWith<QuestionBodyDto_Choice> get copyWith => _$QuestionBodyDto_ChoiceCopyWithImpl<QuestionBodyDto_Choice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_Choice&&const DeepCollectionEquality().equals(other.options, _options)&&(identical(other.correctOptionId, correctOptionId) || other.correctOptionId == correctOptionId)&&(identical(other.blankWordIndex, blankWordIndex) || other.blankWordIndex == blankWordIndex));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),correctOptionId,blankWordIndex);
}

@override
String toString() {
    return 'QuestionBodyDto.choice(options: $options, correctOptionId: $correctOptionId, blankWordIndex: $blankWordIndex)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_ChoiceCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_ChoiceCopyWith(QuestionBodyDto_Choice value, $Res Function(QuestionBodyDto_Choice) _then) = _$QuestionBodyDto_ChoiceCopyWithImpl;
@useResult
$Res call({
 List<OptionDto> options, String correctOptionId, int? blankWordIndex
});




}
/// @nodoc
class _$QuestionBodyDto_ChoiceCopyWithImpl<$Res>
    implements $QuestionBodyDto_ChoiceCopyWith<$Res> {
  _$QuestionBodyDto_ChoiceCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_Choice _self;
  final $Res Function(QuestionBodyDto_Choice) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? correctOptionId = null,Object? blankWordIndex = freezed,}) {
  return _then(QuestionBodyDto_Choice(
options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<OptionDto>,correctOptionId: null == correctOptionId ? _self.correctOptionId : correctOptionId // ignore: cast_nullable_to_non_nullable
as String,blankWordIndex: freezed == blankWordIndex ? _self.blankWordIndex : blankWordIndex // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class QuestionBodyDto_Reorder extends QuestionBodyDto {
  const QuestionBodyDto_Reorder({required  List<ChunkDto> chunks, required  List<Uint32List> acceptOrders}): _chunks = chunks,_acceptOrders = acceptOrders,super._();
  

 final  List<ChunkDto> _chunks;
 List<ChunkDto> get chunks {
  if (_chunks is EqualUnmodifiableListView) return _chunks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chunks);
}

 final  List<Uint32List> _acceptOrders;
 List<Uint32List> get acceptOrders {
  if (_acceptOrders is EqualUnmodifiableListView) return _acceptOrders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_acceptOrders);
}


/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_ReorderCopyWith<QuestionBodyDto_Reorder> get copyWith => _$QuestionBodyDto_ReorderCopyWithImpl<QuestionBodyDto_Reorder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_Reorder&&const DeepCollectionEquality().equals(other.chunks, _chunks)&&const DeepCollectionEquality().equals(other.acceptOrders, _acceptOrders));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_chunks),const DeepCollectionEquality().hash(_acceptOrders));
}

@override
String toString() {
    return 'QuestionBodyDto.reorder(chunks: $chunks, acceptOrders: $acceptOrders)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_ReorderCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_ReorderCopyWith(QuestionBodyDto_Reorder value, $Res Function(QuestionBodyDto_Reorder) _then) = _$QuestionBodyDto_ReorderCopyWithImpl;
@useResult
$Res call({
 List<ChunkDto> chunks, List<Uint32List> acceptOrders
});




}
/// @nodoc
class _$QuestionBodyDto_ReorderCopyWithImpl<$Res>
    implements $QuestionBodyDto_ReorderCopyWith<$Res> {
  _$QuestionBodyDto_ReorderCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_Reorder _self;
  final $Res Function(QuestionBodyDto_Reorder) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chunks = null,Object? acceptOrders = null,}) {
  return _then(QuestionBodyDto_Reorder(
chunks: null == chunks ? _self._chunks : chunks // ignore: cast_nullable_to_non_nullable
as List<ChunkDto>,acceptOrders: null == acceptOrders ? _self._acceptOrders : acceptOrders // ignore: cast_nullable_to_non_nullable
as List<Uint32List>,
  ));
}


}

/// @nodoc


class QuestionBodyDto_Typing extends QuestionBodyDto {
  const QuestionBodyDto_Typing({required this.expectedReading, required this.placeholderZh}): super._();
  

 final  String expectedReading;
 final  String placeholderZh;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_TypingCopyWith<QuestionBodyDto_Typing> get copyWith => _$QuestionBodyDto_TypingCopyWithImpl<QuestionBodyDto_Typing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_Typing&&(identical(other.expectedReading, expectedReading) || other.expectedReading == expectedReading)&&(identical(other.placeholderZh, placeholderZh) || other.placeholderZh == placeholderZh));
}


@override
int get hashCode {
    return Object.hash(runtimeType,expectedReading,placeholderZh);
}

@override
String toString() {
    return 'QuestionBodyDto.typing(expectedReading: $expectedReading, placeholderZh: $placeholderZh)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_TypingCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_TypingCopyWith(QuestionBodyDto_Typing value, $Res Function(QuestionBodyDto_Typing) _then) = _$QuestionBodyDto_TypingCopyWithImpl;
@useResult
$Res call({
 String expectedReading, String placeholderZh
});




}
/// @nodoc
class _$QuestionBodyDto_TypingCopyWithImpl<$Res>
    implements $QuestionBodyDto_TypingCopyWith<$Res> {
  _$QuestionBodyDto_TypingCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_Typing _self;
  final $Res Function(QuestionBodyDto_Typing) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? expectedReading = null,Object? placeholderZh = null,}) {
  return _then(QuestionBodyDto_Typing(
expectedReading: null == expectedReading ? _self.expectedReading : expectedReading // ignore: cast_nullable_to_non_nullable
as String,placeholderZh: null == placeholderZh ? _self.placeholderZh : placeholderZh // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class QuestionBodyDto_Match extends QuestionBodyDto {
  const QuestionBodyDto_Match({required  List<MatchPairDto> pairs}): _pairs = pairs,super._();
  

 final  List<MatchPairDto> _pairs;
 List<MatchPairDto> get pairs {
  if (_pairs is EqualUnmodifiableListView) return _pairs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pairs);
}


/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_MatchCopyWith<QuestionBodyDto_Match> get copyWith => _$QuestionBodyDto_MatchCopyWithImpl<QuestionBodyDto_Match>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_Match&&const DeepCollectionEquality().equals(other.pairs, _pairs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_pairs));
}

@override
String toString() {
    return 'QuestionBodyDto.match(pairs: $pairs)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_MatchCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_MatchCopyWith(QuestionBodyDto_Match value, $Res Function(QuestionBodyDto_Match) _then) = _$QuestionBodyDto_MatchCopyWithImpl;
@useResult
$Res call({
 List<MatchPairDto> pairs
});




}
/// @nodoc
class _$QuestionBodyDto_MatchCopyWithImpl<$Res>
    implements $QuestionBodyDto_MatchCopyWith<$Res> {
  _$QuestionBodyDto_MatchCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_Match _self;
  final $Res Function(QuestionBodyDto_Match) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pairs = null,}) {
  return _then(QuestionBodyDto_Match(
pairs: null == pairs ? _self._pairs : pairs // ignore: cast_nullable_to_non_nullable
as List<MatchPairDto>,
  ));
}


}

/// @nodoc


class QuestionBodyDto_SelfGrade extends QuestionBodyDto {
  const QuestionBodyDto_SelfGrade({required this.reveal}): super._();
  

 final  SentenceDto reveal;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_SelfGradeCopyWith<QuestionBodyDto_SelfGrade> get copyWith => _$QuestionBodyDto_SelfGradeCopyWithImpl<QuestionBodyDto_SelfGrade>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_SelfGrade&&(identical(other.reveal, reveal) || other.reveal == reveal));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reveal);
}

@override
String toString() {
    return 'QuestionBodyDto.selfGrade(reveal: $reveal)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_SelfGradeCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_SelfGradeCopyWith(QuestionBodyDto_SelfGrade value, $Res Function(QuestionBodyDto_SelfGrade) _then) = _$QuestionBodyDto_SelfGradeCopyWithImpl;
@useResult
$Res call({
 SentenceDto reveal
});




}
/// @nodoc
class _$QuestionBodyDto_SelfGradeCopyWithImpl<$Res>
    implements $QuestionBodyDto_SelfGradeCopyWith<$Res> {
  _$QuestionBodyDto_SelfGradeCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_SelfGrade _self;
  final $Res Function(QuestionBodyDto_SelfGrade) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reveal = null,}) {
  return _then(QuestionBodyDto_SelfGrade(
reveal: null == reveal ? _self.reveal : reveal // ignore: cast_nullable_to_non_nullable
as SentenceDto,
  ));
}


}

/// @nodoc


class QuestionBodyDto_Shadow extends QuestionBodyDto {
  const QuestionBodyDto_Shadow({required this.reveal}): super._();
  

 final  SentenceDto reveal;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionBodyDto_ShadowCopyWith<QuestionBodyDto_Shadow> get copyWith => _$QuestionBodyDto_ShadowCopyWithImpl<QuestionBodyDto_Shadow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionBodyDto_Shadow&&(identical(other.reveal, reveal) || other.reveal == reveal));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reveal);
}

@override
String toString() {
    return 'QuestionBodyDto.shadow(reveal: $reveal)';
}


}

/// @nodoc
abstract mixin class $QuestionBodyDto_ShadowCopyWith<$Res> implements $QuestionBodyDtoCopyWith<$Res> {
  factory $QuestionBodyDto_ShadowCopyWith(QuestionBodyDto_Shadow value, $Res Function(QuestionBodyDto_Shadow) _then) = _$QuestionBodyDto_ShadowCopyWithImpl;
@useResult
$Res call({
 SentenceDto reveal
});




}
/// @nodoc
class _$QuestionBodyDto_ShadowCopyWithImpl<$Res>
    implements $QuestionBodyDto_ShadowCopyWith<$Res> {
  _$QuestionBodyDto_ShadowCopyWithImpl(this._self, this._then);

  final QuestionBodyDto_Shadow _self;
  final $Res Function(QuestionBodyDto_Shadow) _then;

/// Create a copy of QuestionBodyDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reveal = null,}) {
  return _then(QuestionBodyDto_Shadow(
reveal: null == reveal ? _self.reveal : reveal // ignore: cast_nullable_to_non_nullable
as SentenceDto,
  ));
}


}

/// @nodoc
mixin _$SessionNextDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionNextDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionNextDto()';
}


}

/// @nodoc
class $SessionNextDtoCopyWith<$Res>  {
$SessionNextDtoCopyWith(SessionNextDto _, $Res Function(SessionNextDto) __);
}


/// Adds pattern-matching-related methods to [SessionNextDto].
extension SessionNextDtoPatterns on SessionNextDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionNextDto_Card value)?  card,TResult Function( SessionNextDto_Done value)?  done,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionNextDto_Card() when card != null:
return card(_that);case SessionNextDto_Done() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionNextDto_Card value)  card,required TResult Function( SessionNextDto_Done value)  done,}){
final _that = this;
switch (_that) {
case SessionNextDto_Card():
return card(_that);case SessionNextDto_Done():
return done(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionNextDto_Card value)?  card,TResult? Function( SessionNextDto_Done value)?  done,}){
final _that = this;
switch (_that) {
case SessionNextDto_Card() when card != null:
return card(_that);case SessionNextDto_Done() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SessionCardDto card)?  card,TResult Function( DateTime? nextDueAt)?  done,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionNextDto_Card() when card != null:
return card(_that.card);case SessionNextDto_Done() when done != null:
return done(_that.nextDueAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SessionCardDto card)  card,required TResult Function( DateTime? nextDueAt)  done,}) {final _that = this;
switch (_that) {
case SessionNextDto_Card():
return card(_that.card);case SessionNextDto_Done():
return done(_that.nextDueAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SessionCardDto card)?  card,TResult? Function( DateTime? nextDueAt)?  done,}) {final _that = this;
switch (_that) {
case SessionNextDto_Card() when card != null:
return card(_that.card);case SessionNextDto_Done() when done != null:
return done(_that.nextDueAt);case _:
  return null;

}
}

}

/// @nodoc


class SessionNextDto_Card extends SessionNextDto {
  const SessionNextDto_Card({required this.card}): super._();
  

 final  SessionCardDto card;

/// Create a copy of SessionNextDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionNextDto_CardCopyWith<SessionNextDto_Card> get copyWith => _$SessionNextDto_CardCopyWithImpl<SessionNextDto_Card>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionNextDto_Card&&(identical(other.card, card) || other.card == card));
}


@override
int get hashCode {
    return Object.hash(runtimeType,card);
}

@override
String toString() {
    return 'SessionNextDto.card(card: $card)';
}


}

/// @nodoc
abstract mixin class $SessionNextDto_CardCopyWith<$Res> implements $SessionNextDtoCopyWith<$Res> {
  factory $SessionNextDto_CardCopyWith(SessionNextDto_Card value, $Res Function(SessionNextDto_Card) _then) = _$SessionNextDto_CardCopyWithImpl;
@useResult
$Res call({
 SessionCardDto card
});




}
/// @nodoc
class _$SessionNextDto_CardCopyWithImpl<$Res>
    implements $SessionNextDto_CardCopyWith<$Res> {
  _$SessionNextDto_CardCopyWithImpl(this._self, this._then);

  final SessionNextDto_Card _self;
  final $Res Function(SessionNextDto_Card) _then;

/// Create a copy of SessionNextDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? card = null,}) {
  return _then(SessionNextDto_Card(
card: null == card ? _self.card : card // ignore: cast_nullable_to_non_nullable
as SessionCardDto,
  ));
}


}

/// @nodoc


class SessionNextDto_Done extends SessionNextDto {
  const SessionNextDto_Done({this.nextDueAt}): super._();
  

 final  DateTime? nextDueAt;

/// Create a copy of SessionNextDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionNextDto_DoneCopyWith<SessionNextDto_Done> get copyWith => _$SessionNextDto_DoneCopyWithImpl<SessionNextDto_Done>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionNextDto_Done&&(identical(other.nextDueAt, nextDueAt) || other.nextDueAt == nextDueAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,nextDueAt);
}

@override
String toString() {
    return 'SessionNextDto.done(nextDueAt: $nextDueAt)';
}


}

/// @nodoc
abstract mixin class $SessionNextDto_DoneCopyWith<$Res> implements $SessionNextDtoCopyWith<$Res> {
  factory $SessionNextDto_DoneCopyWith(SessionNextDto_Done value, $Res Function(SessionNextDto_Done) _then) = _$SessionNextDto_DoneCopyWithImpl;
@useResult
$Res call({
 DateTime? nextDueAt
});




}
/// @nodoc
class _$SessionNextDto_DoneCopyWithImpl<$Res>
    implements $SessionNextDto_DoneCopyWith<$Res> {
  _$SessionNextDto_DoneCopyWithImpl(this._self, this._then);

  final SessionNextDto_Done _self;
  final $Res Function(SessionNextDto_Done) _then;

/// Create a copy of SessionNextDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? nextDueAt = freezed,}) {
  return _then(SessionNextDto_Done(
nextDueAt: freezed == nextDueAt ? _self.nextDueAt : nextDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
