// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dto_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MixedSpanDto {

 String get text;
/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixedSpanDtoCopyWith<MixedSpanDto> get copyWith => _$MixedSpanDtoCopyWithImpl<MixedSpanDto>(this as MixedSpanDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MixedSpanDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixedSpanDto&&(identical(other.text, _this.text) || other.text == _this.text));
}


@override
int get hashCode {
  final _this = this as MixedSpanDto;
  return Object.hash(runtimeType,_this.text);
}

@override
String toString() {
  final _this = this as MixedSpanDto;
  return 'MixedSpanDto(text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $MixedSpanDtoCopyWith<$Res>  {
  factory $MixedSpanDtoCopyWith(MixedSpanDto value, $Res Function(MixedSpanDto) _then) = _$MixedSpanDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$MixedSpanDtoCopyWithImpl<$Res>
    implements $MixedSpanDtoCopyWith<$Res> {
  _$MixedSpanDtoCopyWithImpl(this._self, this._then);

  final MixedSpanDto _self;
  final $Res Function(MixedSpanDto) _then;

/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MixedSpanDto].
extension MixedSpanDtoPatterns on MixedSpanDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MixedSpanDto_Zh value)?  zh,TResult Function( MixedSpanDto_Ja value)?  ja,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MixedSpanDto_Zh() when zh != null:
return zh(_that);case MixedSpanDto_Ja() when ja != null:
return ja(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MixedSpanDto_Zh value)  zh,required TResult Function( MixedSpanDto_Ja value)  ja,}){
final _that = this;
switch (_that) {
case MixedSpanDto_Zh():
return zh(_that);case MixedSpanDto_Ja():
return ja(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MixedSpanDto_Zh value)?  zh,TResult? Function( MixedSpanDto_Ja value)?  ja,}){
final _that = this;
switch (_that) {
case MixedSpanDto_Zh() when zh != null:
return zh(_that);case MixedSpanDto_Ja() when ja != null:
return ja(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  zh,TResult Function( String text,  List<RubyPartDto> ruby)?  ja,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MixedSpanDto_Zh() when zh != null:
return zh(_that.text);case MixedSpanDto_Ja() when ja != null:
return ja(_that.text,_that.ruby);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  zh,required TResult Function( String text,  List<RubyPartDto> ruby)  ja,}) {final _that = this;
switch (_that) {
case MixedSpanDto_Zh():
return zh(_that.text);case MixedSpanDto_Ja():
return ja(_that.text,_that.ruby);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  zh,TResult? Function( String text,  List<RubyPartDto> ruby)?  ja,}) {final _that = this;
switch (_that) {
case MixedSpanDto_Zh() when zh != null:
return zh(_that.text);case MixedSpanDto_Ja() when ja != null:
return ja(_that.text,_that.ruby);case _:
  return null;

}
}

}

/// @nodoc


class MixedSpanDto_Zh extends MixedSpanDto {
  const MixedSpanDto_Zh({required this.text}): super._();
  

@override final  String text;

/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixedSpanDto_ZhCopyWith<MixedSpanDto_Zh> get copyWith => _$MixedSpanDto_ZhCopyWithImpl<MixedSpanDto_Zh>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MixedSpanDto_Zh&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'MixedSpanDto.zh(text: $text)';
}


}

/// @nodoc
abstract mixin class $MixedSpanDto_ZhCopyWith<$Res> implements $MixedSpanDtoCopyWith<$Res> {
  factory $MixedSpanDto_ZhCopyWith(MixedSpanDto_Zh value, $Res Function(MixedSpanDto_Zh) _then) = _$MixedSpanDto_ZhCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$MixedSpanDto_ZhCopyWithImpl<$Res>
    implements $MixedSpanDto_ZhCopyWith<$Res> {
  _$MixedSpanDto_ZhCopyWithImpl(this._self, this._then);

  final MixedSpanDto_Zh _self;
  final $Res Function(MixedSpanDto_Zh) _then;

/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(MixedSpanDto_Zh(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class MixedSpanDto_Ja extends MixedSpanDto {
  const MixedSpanDto_Ja({required this.text, required  List<RubyPartDto> ruby}): _ruby = ruby,super._();
  

@override final  String text;
 final  List<RubyPartDto> _ruby;
 List<RubyPartDto> get ruby {
  if (_ruby is EqualUnmodifiableListView) return _ruby;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ruby);
}


/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixedSpanDto_JaCopyWith<MixedSpanDto_Ja> get copyWith => _$MixedSpanDto_JaCopyWithImpl<MixedSpanDto_Ja>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MixedSpanDto_Ja&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.ruby, _ruby));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_ruby));
}

@override
String toString() {
    return 'MixedSpanDto.ja(text: $text, ruby: $ruby)';
}


}

/// @nodoc
abstract mixin class $MixedSpanDto_JaCopyWith<$Res> implements $MixedSpanDtoCopyWith<$Res> {
  factory $MixedSpanDto_JaCopyWith(MixedSpanDto_Ja value, $Res Function(MixedSpanDto_Ja) _then) = _$MixedSpanDto_JaCopyWithImpl;
@override @useResult
$Res call({
 String text, List<RubyPartDto> ruby
});




}
/// @nodoc
class _$MixedSpanDto_JaCopyWithImpl<$Res>
    implements $MixedSpanDto_JaCopyWith<$Res> {
  _$MixedSpanDto_JaCopyWithImpl(this._self, this._then);

  final MixedSpanDto_Ja _self;
  final $Res Function(MixedSpanDto_Ja) _then;

/// Create a copy of MixedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? ruby = null,}) {
  return _then(MixedSpanDto_Ja(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,ruby: null == ruby ? _self._ruby : ruby // ignore: cast_nullable_to_non_nullable
as List<RubyPartDto>,
  ));
}


}

/// @nodoc
mixin _$NoteDto {

 String get id;
/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDtoCopyWith<NoteDto> get copyWith => _$NoteDtoCopyWithImpl<NoteDto>(this as NoteDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NoteDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto&&(identical(other.id, _this.id) || other.id == _this.id));
}


@override
int get hashCode {
  final _this = this as NoteDto;
  return Object.hash(runtimeType,_this.id);
}

@override
String toString() {
  final _this = this as NoteDto;
  return 'NoteDto(id: ${_this.id})';
}


}

/// @nodoc
abstract mixin class $NoteDtoCopyWith<$Res>  {
  factory $NoteDtoCopyWith(NoteDto value, $Res Function(NoteDto) _then) = _$NoteDtoCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$NoteDtoCopyWithImpl<$Res>
    implements $NoteDtoCopyWith<$Res> {
  _$NoteDtoCopyWithImpl(this._self, this._then);

  final NoteDto _self;
  final $Res Function(NoteDto) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NoteDto].
extension NoteDtoPatterns on NoteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NoteDto_FalseFriend value)?  falseFriend,TResult Function( NoteDto_Shinjitai value)?  shinjitai,TResult Function( NoteDto_Reading value)?  reading,TResult Function( NoteDto_Transfer value)?  transfer,TResult Function( NoteDto_Term value)?  term,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NoteDto_FalseFriend() when falseFriend != null:
return falseFriend(_that);case NoteDto_Shinjitai() when shinjitai != null:
return shinjitai(_that);case NoteDto_Reading() when reading != null:
return reading(_that);case NoteDto_Transfer() when transfer != null:
return transfer(_that);case NoteDto_Term() when term != null:
return term(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NoteDto_FalseFriend value)  falseFriend,required TResult Function( NoteDto_Shinjitai value)  shinjitai,required TResult Function( NoteDto_Reading value)  reading,required TResult Function( NoteDto_Transfer value)  transfer,required TResult Function( NoteDto_Term value)  term,}){
final _that = this;
switch (_that) {
case NoteDto_FalseFriend():
return falseFriend(_that);case NoteDto_Shinjitai():
return shinjitai(_that);case NoteDto_Reading():
return reading(_that);case NoteDto_Transfer():
return transfer(_that);case NoteDto_Term():
return term(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NoteDto_FalseFriend value)?  falseFriend,TResult? Function( NoteDto_Shinjitai value)?  shinjitai,TResult? Function( NoteDto_Reading value)?  reading,TResult? Function( NoteDto_Transfer value)?  transfer,TResult? Function( NoteDto_Term value)?  term,}){
final _that = this;
switch (_that) {
case NoteDto_FalseFriend() when falseFriend != null:
return falseFriend(_that);case NoteDto_Shinjitai() when shinjitai != null:
return shinjitai(_that);case NoteDto_Reading() when reading != null:
return reading(_that);case NoteDto_Transfer() when transfer != null:
return transfer(_that);case NoteDto_Term() when term != null:
return term(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String surface,  String jaZh,  String misreadZh,  String? vocabId)?  falseFriend,TResult Function( String id,  String ja,  String zhTw,  String kind,  List<String> vocabIds)?  shinjitai,TResult Function( String id,  String titleZh,  String bodyZh,  List<ReadingExampleDto> examples,  String caveatZh)?  reading,TResult Function( String id,  String titleZh,  String zhPattern,  String wrong,  String right,  String explainZh)?  transfer,TResult Function( String id,  String term,  String? akaZh,  String bodyZh,  List<String> grammarIds)?  term,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NoteDto_FalseFriend() when falseFriend != null:
return falseFriend(_that.id,_that.surface,_that.jaZh,_that.misreadZh,_that.vocabId);case NoteDto_Shinjitai() when shinjitai != null:
return shinjitai(_that.id,_that.ja,_that.zhTw,_that.kind,_that.vocabIds);case NoteDto_Reading() when reading != null:
return reading(_that.id,_that.titleZh,_that.bodyZh,_that.examples,_that.caveatZh);case NoteDto_Transfer() when transfer != null:
return transfer(_that.id,_that.titleZh,_that.zhPattern,_that.wrong,_that.right,_that.explainZh);case NoteDto_Term() when term != null:
return term(_that.id,_that.term,_that.akaZh,_that.bodyZh,_that.grammarIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String surface,  String jaZh,  String misreadZh,  String? vocabId)  falseFriend,required TResult Function( String id,  String ja,  String zhTw,  String kind,  List<String> vocabIds)  shinjitai,required TResult Function( String id,  String titleZh,  String bodyZh,  List<ReadingExampleDto> examples,  String caveatZh)  reading,required TResult Function( String id,  String titleZh,  String zhPattern,  String wrong,  String right,  String explainZh)  transfer,required TResult Function( String id,  String term,  String? akaZh,  String bodyZh,  List<String> grammarIds)  term,}) {final _that = this;
switch (_that) {
case NoteDto_FalseFriend():
return falseFriend(_that.id,_that.surface,_that.jaZh,_that.misreadZh,_that.vocabId);case NoteDto_Shinjitai():
return shinjitai(_that.id,_that.ja,_that.zhTw,_that.kind,_that.vocabIds);case NoteDto_Reading():
return reading(_that.id,_that.titleZh,_that.bodyZh,_that.examples,_that.caveatZh);case NoteDto_Transfer():
return transfer(_that.id,_that.titleZh,_that.zhPattern,_that.wrong,_that.right,_that.explainZh);case NoteDto_Term():
return term(_that.id,_that.term,_that.akaZh,_that.bodyZh,_that.grammarIds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String surface,  String jaZh,  String misreadZh,  String? vocabId)?  falseFriend,TResult? Function( String id,  String ja,  String zhTw,  String kind,  List<String> vocabIds)?  shinjitai,TResult? Function( String id,  String titleZh,  String bodyZh,  List<ReadingExampleDto> examples,  String caveatZh)?  reading,TResult? Function( String id,  String titleZh,  String zhPattern,  String wrong,  String right,  String explainZh)?  transfer,TResult? Function( String id,  String term,  String? akaZh,  String bodyZh,  List<String> grammarIds)?  term,}) {final _that = this;
switch (_that) {
case NoteDto_FalseFriend() when falseFriend != null:
return falseFriend(_that.id,_that.surface,_that.jaZh,_that.misreadZh,_that.vocabId);case NoteDto_Shinjitai() when shinjitai != null:
return shinjitai(_that.id,_that.ja,_that.zhTw,_that.kind,_that.vocabIds);case NoteDto_Reading() when reading != null:
return reading(_that.id,_that.titleZh,_that.bodyZh,_that.examples,_that.caveatZh);case NoteDto_Transfer() when transfer != null:
return transfer(_that.id,_that.titleZh,_that.zhPattern,_that.wrong,_that.right,_that.explainZh);case NoteDto_Term() when term != null:
return term(_that.id,_that.term,_that.akaZh,_that.bodyZh,_that.grammarIds);case _:
  return null;

}
}

}

/// @nodoc


class NoteDto_FalseFriend extends NoteDto {
  const NoteDto_FalseFriend({required this.id, required this.surface, required this.jaZh, required this.misreadZh, this.vocabId}): super._();
  

@override final  String id;
 final  String surface;
 final  String jaZh;
 final  String misreadZh;
 final  String? vocabId;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDto_FalseFriendCopyWith<NoteDto_FalseFriend> get copyWith => _$NoteDto_FalseFriendCopyWithImpl<NoteDto_FalseFriend>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto_FalseFriend&&(identical(other.id, id) || other.id == id)&&(identical(other.surface, surface) || other.surface == surface)&&(identical(other.jaZh, jaZh) || other.jaZh == jaZh)&&(identical(other.misreadZh, misreadZh) || other.misreadZh == misreadZh)&&(identical(other.vocabId, vocabId) || other.vocabId == vocabId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,surface,jaZh,misreadZh,vocabId);
}

@override
String toString() {
    return 'NoteDto.falseFriend(id: $id, surface: $surface, jaZh: $jaZh, misreadZh: $misreadZh, vocabId: $vocabId)';
}


}

/// @nodoc
abstract mixin class $NoteDto_FalseFriendCopyWith<$Res> implements $NoteDtoCopyWith<$Res> {
  factory $NoteDto_FalseFriendCopyWith(NoteDto_FalseFriend value, $Res Function(NoteDto_FalseFriend) _then) = _$NoteDto_FalseFriendCopyWithImpl;
@override @useResult
$Res call({
 String id, String surface, String jaZh, String misreadZh, String? vocabId
});




}
/// @nodoc
class _$NoteDto_FalseFriendCopyWithImpl<$Res>
    implements $NoteDto_FalseFriendCopyWith<$Res> {
  _$NoteDto_FalseFriendCopyWithImpl(this._self, this._then);

  final NoteDto_FalseFriend _self;
  final $Res Function(NoteDto_FalseFriend) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? surface = null,Object? jaZh = null,Object? misreadZh = null,Object? vocabId = freezed,}) {
  return _then(NoteDto_FalseFriend(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as String,jaZh: null == jaZh ? _self.jaZh : jaZh // ignore: cast_nullable_to_non_nullable
as String,misreadZh: null == misreadZh ? _self.misreadZh : misreadZh // ignore: cast_nullable_to_non_nullable
as String,vocabId: freezed == vocabId ? _self.vocabId : vocabId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class NoteDto_Shinjitai extends NoteDto {
  const NoteDto_Shinjitai({required this.id, required this.ja, required this.zhTw, required this.kind, required  List<String> vocabIds}): _vocabIds = vocabIds,super._();
  

@override final  String id;
 final  String ja;
 final  String zhTw;
 final  String kind;
 final  List<String> _vocabIds;
 List<String> get vocabIds {
  if (_vocabIds is EqualUnmodifiableListView) return _vocabIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vocabIds);
}


/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDto_ShinjitaiCopyWith<NoteDto_Shinjitai> get copyWith => _$NoteDto_ShinjitaiCopyWithImpl<NoteDto_Shinjitai>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto_Shinjitai&&(identical(other.id, id) || other.id == id)&&(identical(other.ja, ja) || other.ja == ja)&&(identical(other.zhTw, zhTw) || other.zhTw == zhTw)&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.vocabIds, _vocabIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ja,zhTw,kind,const DeepCollectionEquality().hash(_vocabIds));
}

@override
String toString() {
    return 'NoteDto.shinjitai(id: $id, ja: $ja, zhTw: $zhTw, kind: $kind, vocabIds: $vocabIds)';
}


}

/// @nodoc
abstract mixin class $NoteDto_ShinjitaiCopyWith<$Res> implements $NoteDtoCopyWith<$Res> {
  factory $NoteDto_ShinjitaiCopyWith(NoteDto_Shinjitai value, $Res Function(NoteDto_Shinjitai) _then) = _$NoteDto_ShinjitaiCopyWithImpl;
@override @useResult
$Res call({
 String id, String ja, String zhTw, String kind, List<String> vocabIds
});




}
/// @nodoc
class _$NoteDto_ShinjitaiCopyWithImpl<$Res>
    implements $NoteDto_ShinjitaiCopyWith<$Res> {
  _$NoteDto_ShinjitaiCopyWithImpl(this._self, this._then);

  final NoteDto_Shinjitai _self;
  final $Res Function(NoteDto_Shinjitai) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ja = null,Object? zhTw = null,Object? kind = null,Object? vocabIds = null,}) {
  return _then(NoteDto_Shinjitai(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ja: null == ja ? _self.ja : ja // ignore: cast_nullable_to_non_nullable
as String,zhTw: null == zhTw ? _self.zhTw : zhTw // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,vocabIds: null == vocabIds ? _self._vocabIds : vocabIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class NoteDto_Reading extends NoteDto {
  const NoteDto_Reading({required this.id, required this.titleZh, required this.bodyZh, required  List<ReadingExampleDto> examples, required this.caveatZh}): _examples = examples,super._();
  

@override final  String id;
 final  String titleZh;
 final  String bodyZh;
 final  List<ReadingExampleDto> _examples;
 List<ReadingExampleDto> get examples {
  if (_examples is EqualUnmodifiableListView) return _examples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_examples);
}

 final  String caveatZh;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDto_ReadingCopyWith<NoteDto_Reading> get copyWith => _$NoteDto_ReadingCopyWithImpl<NoteDto_Reading>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto_Reading&&(identical(other.id, id) || other.id == id)&&(identical(other.titleZh, titleZh) || other.titleZh == titleZh)&&(identical(other.bodyZh, bodyZh) || other.bodyZh == bodyZh)&&const DeepCollectionEquality().equals(other.examples, _examples)&&(identical(other.caveatZh, caveatZh) || other.caveatZh == caveatZh));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,titleZh,bodyZh,const DeepCollectionEquality().hash(_examples),caveatZh);
}

@override
String toString() {
    return 'NoteDto.reading(id: $id, titleZh: $titleZh, bodyZh: $bodyZh, examples: $examples, caveatZh: $caveatZh)';
}


}

/// @nodoc
abstract mixin class $NoteDto_ReadingCopyWith<$Res> implements $NoteDtoCopyWith<$Res> {
  factory $NoteDto_ReadingCopyWith(NoteDto_Reading value, $Res Function(NoteDto_Reading) _then) = _$NoteDto_ReadingCopyWithImpl;
@override @useResult
$Res call({
 String id, String titleZh, String bodyZh, List<ReadingExampleDto> examples, String caveatZh
});




}
/// @nodoc
class _$NoteDto_ReadingCopyWithImpl<$Res>
    implements $NoteDto_ReadingCopyWith<$Res> {
  _$NoteDto_ReadingCopyWithImpl(this._self, this._then);

  final NoteDto_Reading _self;
  final $Res Function(NoteDto_Reading) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? titleZh = null,Object? bodyZh = null,Object? examples = null,Object? caveatZh = null,}) {
  return _then(NoteDto_Reading(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titleZh: null == titleZh ? _self.titleZh : titleZh // ignore: cast_nullable_to_non_nullable
as String,bodyZh: null == bodyZh ? _self.bodyZh : bodyZh // ignore: cast_nullable_to_non_nullable
as String,examples: null == examples ? _self._examples : examples // ignore: cast_nullable_to_non_nullable
as List<ReadingExampleDto>,caveatZh: null == caveatZh ? _self.caveatZh : caveatZh // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NoteDto_Transfer extends NoteDto {
  const NoteDto_Transfer({required this.id, required this.titleZh, required this.zhPattern, required this.wrong, required this.right, required this.explainZh}): super._();
  

@override final  String id;
 final  String titleZh;
 final  String zhPattern;
 final  String wrong;
 final  String right;
 final  String explainZh;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDto_TransferCopyWith<NoteDto_Transfer> get copyWith => _$NoteDto_TransferCopyWithImpl<NoteDto_Transfer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto_Transfer&&(identical(other.id, id) || other.id == id)&&(identical(other.titleZh, titleZh) || other.titleZh == titleZh)&&(identical(other.zhPattern, zhPattern) || other.zhPattern == zhPattern)&&(identical(other.wrong, wrong) || other.wrong == wrong)&&(identical(other.right, right) || other.right == right)&&(identical(other.explainZh, explainZh) || other.explainZh == explainZh));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,titleZh,zhPattern,wrong,right,explainZh);
}

@override
String toString() {
    return 'NoteDto.transfer(id: $id, titleZh: $titleZh, zhPattern: $zhPattern, wrong: $wrong, right: $right, explainZh: $explainZh)';
}


}

/// @nodoc
abstract mixin class $NoteDto_TransferCopyWith<$Res> implements $NoteDtoCopyWith<$Res> {
  factory $NoteDto_TransferCopyWith(NoteDto_Transfer value, $Res Function(NoteDto_Transfer) _then) = _$NoteDto_TransferCopyWithImpl;
@override @useResult
$Res call({
 String id, String titleZh, String zhPattern, String wrong, String right, String explainZh
});




}
/// @nodoc
class _$NoteDto_TransferCopyWithImpl<$Res>
    implements $NoteDto_TransferCopyWith<$Res> {
  _$NoteDto_TransferCopyWithImpl(this._self, this._then);

  final NoteDto_Transfer _self;
  final $Res Function(NoteDto_Transfer) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? titleZh = null,Object? zhPattern = null,Object? wrong = null,Object? right = null,Object? explainZh = null,}) {
  return _then(NoteDto_Transfer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titleZh: null == titleZh ? _self.titleZh : titleZh // ignore: cast_nullable_to_non_nullable
as String,zhPattern: null == zhPattern ? _self.zhPattern : zhPattern // ignore: cast_nullable_to_non_nullable
as String,wrong: null == wrong ? _self.wrong : wrong // ignore: cast_nullable_to_non_nullable
as String,right: null == right ? _self.right : right // ignore: cast_nullable_to_non_nullable
as String,explainZh: null == explainZh ? _self.explainZh : explainZh // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NoteDto_Term extends NoteDto {
  const NoteDto_Term({required this.id, required this.term, this.akaZh, required this.bodyZh, required  List<String> grammarIds}): _grammarIds = grammarIds,super._();
  

@override final  String id;
 final  String term;
 final  String? akaZh;
 final  String bodyZh;
 final  List<String> _grammarIds;
 List<String> get grammarIds {
  if (_grammarIds is EqualUnmodifiableListView) return _grammarIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_grammarIds);
}


/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDto_TermCopyWith<NoteDto_Term> get copyWith => _$NoteDto_TermCopyWithImpl<NoteDto_Term>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDto_Term&&(identical(other.id, id) || other.id == id)&&(identical(other.term, term) || other.term == term)&&(identical(other.akaZh, akaZh) || other.akaZh == akaZh)&&(identical(other.bodyZh, bodyZh) || other.bodyZh == bodyZh)&&const DeepCollectionEquality().equals(other.grammarIds, _grammarIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,term,akaZh,bodyZh,const DeepCollectionEquality().hash(_grammarIds));
}

@override
String toString() {
    return 'NoteDto.term(id: $id, term: $term, akaZh: $akaZh, bodyZh: $bodyZh, grammarIds: $grammarIds)';
}


}

/// @nodoc
abstract mixin class $NoteDto_TermCopyWith<$Res> implements $NoteDtoCopyWith<$Res> {
  factory $NoteDto_TermCopyWith(NoteDto_Term value, $Res Function(NoteDto_Term) _then) = _$NoteDto_TermCopyWithImpl;
@override @useResult
$Res call({
 String id, String term, String? akaZh, String bodyZh, List<String> grammarIds
});




}
/// @nodoc
class _$NoteDto_TermCopyWithImpl<$Res>
    implements $NoteDto_TermCopyWith<$Res> {
  _$NoteDto_TermCopyWithImpl(this._self, this._then);

  final NoteDto_Term _self;
  final $Res Function(NoteDto_Term) _then;

/// Create a copy of NoteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? term = null,Object? akaZh = freezed,Object? bodyZh = null,Object? grammarIds = null,}) {
  return _then(NoteDto_Term(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,term: null == term ? _self.term : term // ignore: cast_nullable_to_non_nullable
as String,akaZh: freezed == akaZh ? _self.akaZh : akaZh // ignore: cast_nullable_to_non_nullable
as String?,bodyZh: null == bodyZh ? _self.bodyZh : bodyZh // ignore: cast_nullable_to_non_nullable
as String,grammarIds: null == grammarIds ? _self._grammarIds : grammarIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
