// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoreError {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError()';
}


}

/// @nodoc
class $CoreErrorCopyWith<$Res>  {
$CoreErrorCopyWith(CoreError _, $Res Function(CoreError) __);
}


/// Adds pattern-matching-related methods to [CoreError].
extension CoreErrorPatterns on CoreError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CoreError_NotFound value)?  notFound,TResult Function( CoreError_InvalidInput value)?  invalidInput,TResult Function( CoreError_StaleCard value)?  staleCard,TResult Function( CoreError_NoActivePlan value)?  noActivePlan,TResult Function( CoreError_ContentCorrupt value)?  contentCorrupt,TResult Function( CoreError_MigrationFailed value)?  migrationFailed,TResult Function( CoreError_Storage value)?  storage,TResult Function( CoreError_Internal value)?  internal,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CoreError_NotFound() when notFound != null:
return notFound(_that);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case CoreError_StaleCard() when staleCard != null:
return staleCard(_that);case CoreError_NoActivePlan() when noActivePlan != null:
return noActivePlan(_that);case CoreError_ContentCorrupt() when contentCorrupt != null:
return contentCorrupt(_that);case CoreError_MigrationFailed() when migrationFailed != null:
return migrationFailed(_that);case CoreError_Storage() when storage != null:
return storage(_that);case CoreError_Internal() when internal != null:
return internal(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CoreError_NotFound value)  notFound,required TResult Function( CoreError_InvalidInput value)  invalidInput,required TResult Function( CoreError_StaleCard value)  staleCard,required TResult Function( CoreError_NoActivePlan value)  noActivePlan,required TResult Function( CoreError_ContentCorrupt value)  contentCorrupt,required TResult Function( CoreError_MigrationFailed value)  migrationFailed,required TResult Function( CoreError_Storage value)  storage,required TResult Function( CoreError_Internal value)  internal,}){
final _that = this;
switch (_that) {
case CoreError_NotFound():
return notFound(_that);case CoreError_InvalidInput():
return invalidInput(_that);case CoreError_StaleCard():
return staleCard(_that);case CoreError_NoActivePlan():
return noActivePlan(_that);case CoreError_ContentCorrupt():
return contentCorrupt(_that);case CoreError_MigrationFailed():
return migrationFailed(_that);case CoreError_Storage():
return storage(_that);case CoreError_Internal():
return internal(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CoreError_NotFound value)?  notFound,TResult? Function( CoreError_InvalidInput value)?  invalidInput,TResult? Function( CoreError_StaleCard value)?  staleCard,TResult? Function( CoreError_NoActivePlan value)?  noActivePlan,TResult? Function( CoreError_ContentCorrupt value)?  contentCorrupt,TResult? Function( CoreError_MigrationFailed value)?  migrationFailed,TResult? Function( CoreError_Storage value)?  storage,TResult? Function( CoreError_Internal value)?  internal,}){
final _that = this;
switch (_that) {
case CoreError_NotFound() when notFound != null:
return notFound(_that);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case CoreError_StaleCard() when staleCard != null:
return staleCard(_that);case CoreError_NoActivePlan() when noActivePlan != null:
return noActivePlan(_that);case CoreError_ContentCorrupt() when contentCorrupt != null:
return contentCorrupt(_that);case CoreError_MigrationFailed() when migrationFailed != null:
return migrationFailed(_that);case CoreError_Storage() when storage != null:
return storage(_that);case CoreError_Internal() when internal != null:
return internal(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String entity,  String id)?  notFound,TResult Function( String field,  String reason)?  invalidInput,TResult Function( String cardId)?  staleCard,TResult Function()?  noActivePlan,TResult Function( String file,  String detail)?  contentCorrupt,TResult Function( int fromVersion,  String message)?  migrationFailed,TResult Function( String message)?  storage,TResult Function( String message)?  internal,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CoreError_NotFound() when notFound != null:
return notFound(_that.entity,_that.id);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that.field,_that.reason);case CoreError_StaleCard() when staleCard != null:
return staleCard(_that.cardId);case CoreError_NoActivePlan() when noActivePlan != null:
return noActivePlan();case CoreError_ContentCorrupt() when contentCorrupt != null:
return contentCorrupt(_that.file,_that.detail);case CoreError_MigrationFailed() when migrationFailed != null:
return migrationFailed(_that.fromVersion,_that.message);case CoreError_Storage() when storage != null:
return storage(_that.message);case CoreError_Internal() when internal != null:
return internal(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String entity,  String id)  notFound,required TResult Function( String field,  String reason)  invalidInput,required TResult Function( String cardId)  staleCard,required TResult Function()  noActivePlan,required TResult Function( String file,  String detail)  contentCorrupt,required TResult Function( int fromVersion,  String message)  migrationFailed,required TResult Function( String message)  storage,required TResult Function( String message)  internal,}) {final _that = this;
switch (_that) {
case CoreError_NotFound():
return notFound(_that.entity,_that.id);case CoreError_InvalidInput():
return invalidInput(_that.field,_that.reason);case CoreError_StaleCard():
return staleCard(_that.cardId);case CoreError_NoActivePlan():
return noActivePlan();case CoreError_ContentCorrupt():
return contentCorrupt(_that.file,_that.detail);case CoreError_MigrationFailed():
return migrationFailed(_that.fromVersion,_that.message);case CoreError_Storage():
return storage(_that.message);case CoreError_Internal():
return internal(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String entity,  String id)?  notFound,TResult? Function( String field,  String reason)?  invalidInput,TResult? Function( String cardId)?  staleCard,TResult? Function()?  noActivePlan,TResult? Function( String file,  String detail)?  contentCorrupt,TResult? Function( int fromVersion,  String message)?  migrationFailed,TResult? Function( String message)?  storage,TResult? Function( String message)?  internal,}) {final _that = this;
switch (_that) {
case CoreError_NotFound() when notFound != null:
return notFound(_that.entity,_that.id);case CoreError_InvalidInput() when invalidInput != null:
return invalidInput(_that.field,_that.reason);case CoreError_StaleCard() when staleCard != null:
return staleCard(_that.cardId);case CoreError_NoActivePlan() when noActivePlan != null:
return noActivePlan();case CoreError_ContentCorrupt() when contentCorrupt != null:
return contentCorrupt(_that.file,_that.detail);case CoreError_MigrationFailed() when migrationFailed != null:
return migrationFailed(_that.fromVersion,_that.message);case CoreError_Storage() when storage != null:
return storage(_that.message);case CoreError_Internal() when internal != null:
return internal(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class CoreError_NotFound extends CoreError {
  const CoreError_NotFound({required this.entity, required this.id}): super._();
  

 final  String entity;
 final  String id;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_NotFoundCopyWith<CoreError_NotFound> get copyWith => _$CoreError_NotFoundCopyWithImpl<CoreError_NotFound>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NotFound&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entity,id);
}

@override
String toString() {
    return 'CoreError.notFound(entity: $entity, id: $id)';
}


}

/// @nodoc
abstract mixin class $CoreError_NotFoundCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_NotFoundCopyWith(CoreError_NotFound value, $Res Function(CoreError_NotFound) _then) = _$CoreError_NotFoundCopyWithImpl;
@useResult
$Res call({
 String entity, String id
});




}
/// @nodoc
class _$CoreError_NotFoundCopyWithImpl<$Res>
    implements $CoreError_NotFoundCopyWith<$Res> {
  _$CoreError_NotFoundCopyWithImpl(this._self, this._then);

  final CoreError_NotFound _self;
  final $Res Function(CoreError_NotFound) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? id = null,}) {
  return _then(CoreError_NotFound(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_InvalidInput extends CoreError {
  const CoreError_InvalidInput({required this.field, required this.reason}): super._();
  

 final  String field;
 final  String reason;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_InvalidInputCopyWith<CoreError_InvalidInput> get copyWith => _$CoreError_InvalidInputCopyWithImpl<CoreError_InvalidInput>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_InvalidInput&&(identical(other.field, field) || other.field == field)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field,reason);
}

@override
String toString() {
    return 'CoreError.invalidInput(field: $field, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CoreError_InvalidInputCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_InvalidInputCopyWith(CoreError_InvalidInput value, $Res Function(CoreError_InvalidInput) _then) = _$CoreError_InvalidInputCopyWithImpl;
@useResult
$Res call({
 String field, String reason
});




}
/// @nodoc
class _$CoreError_InvalidInputCopyWithImpl<$Res>
    implements $CoreError_InvalidInputCopyWith<$Res> {
  _$CoreError_InvalidInputCopyWithImpl(this._self, this._then);

  final CoreError_InvalidInput _self;
  final $Res Function(CoreError_InvalidInput) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field = null,Object? reason = null,}) {
  return _then(CoreError_InvalidInput(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_StaleCard extends CoreError {
  const CoreError_StaleCard({required this.cardId}): super._();
  

 final  String cardId;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_StaleCardCopyWith<CoreError_StaleCard> get copyWith => _$CoreError_StaleCardCopyWithImpl<CoreError_StaleCard>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_StaleCard&&(identical(other.cardId, cardId) || other.cardId == cardId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,cardId);
}

@override
String toString() {
    return 'CoreError.staleCard(cardId: $cardId)';
}


}

/// @nodoc
abstract mixin class $CoreError_StaleCardCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_StaleCardCopyWith(CoreError_StaleCard value, $Res Function(CoreError_StaleCard) _then) = _$CoreError_StaleCardCopyWithImpl;
@useResult
$Res call({
 String cardId
});




}
/// @nodoc
class _$CoreError_StaleCardCopyWithImpl<$Res>
    implements $CoreError_StaleCardCopyWith<$Res> {
  _$CoreError_StaleCardCopyWithImpl(this._self, this._then);

  final CoreError_StaleCard _self;
  final $Res Function(CoreError_StaleCard) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cardId = null,}) {
  return _then(CoreError_StaleCard(
cardId: null == cardId ? _self.cardId : cardId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_NoActivePlan extends CoreError {
  const CoreError_NoActivePlan(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_NoActivePlan);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CoreError.noActivePlan()';
}


}




/// @nodoc


class CoreError_ContentCorrupt extends CoreError {
  const CoreError_ContentCorrupt({required this.file, required this.detail}): super._();
  

 final  String file;
 final  String detail;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_ContentCorruptCopyWith<CoreError_ContentCorrupt> get copyWith => _$CoreError_ContentCorruptCopyWithImpl<CoreError_ContentCorrupt>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_ContentCorrupt&&(identical(other.file, file) || other.file == file)&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,file,detail);
}

@override
String toString() {
    return 'CoreError.contentCorrupt(file: $file, detail: $detail)';
}


}

/// @nodoc
abstract mixin class $CoreError_ContentCorruptCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_ContentCorruptCopyWith(CoreError_ContentCorrupt value, $Res Function(CoreError_ContentCorrupt) _then) = _$CoreError_ContentCorruptCopyWithImpl;
@useResult
$Res call({
 String file, String detail
});




}
/// @nodoc
class _$CoreError_ContentCorruptCopyWithImpl<$Res>
    implements $CoreError_ContentCorruptCopyWith<$Res> {
  _$CoreError_ContentCorruptCopyWithImpl(this._self, this._then);

  final CoreError_ContentCorrupt _self;
  final $Res Function(CoreError_ContentCorrupt) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? file = null,Object? detail = null,}) {
  return _then(CoreError_ContentCorrupt(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_MigrationFailed extends CoreError {
  const CoreError_MigrationFailed({required this.fromVersion, required this.message}): super._();
  

 final  int fromVersion;
 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_MigrationFailedCopyWith<CoreError_MigrationFailed> get copyWith => _$CoreError_MigrationFailedCopyWithImpl<CoreError_MigrationFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_MigrationFailed&&(identical(other.fromVersion, fromVersion) || other.fromVersion == fromVersion)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fromVersion,message);
}

@override
String toString() {
    return 'CoreError.migrationFailed(fromVersion: $fromVersion, message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_MigrationFailedCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_MigrationFailedCopyWith(CoreError_MigrationFailed value, $Res Function(CoreError_MigrationFailed) _then) = _$CoreError_MigrationFailedCopyWithImpl;
@useResult
$Res call({
 int fromVersion, String message
});




}
/// @nodoc
class _$CoreError_MigrationFailedCopyWithImpl<$Res>
    implements $CoreError_MigrationFailedCopyWith<$Res> {
  _$CoreError_MigrationFailedCopyWithImpl(this._self, this._then);

  final CoreError_MigrationFailed _self;
  final $Res Function(CoreError_MigrationFailed) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fromVersion = null,Object? message = null,}) {
  return _then(CoreError_MigrationFailed(
fromVersion: null == fromVersion ? _self.fromVersion : fromVersion // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Storage extends CoreError {
  const CoreError_Storage({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_StorageCopyWith<CoreError_Storage> get copyWith => _$CoreError_StorageCopyWithImpl<CoreError_Storage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Storage&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.storage(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_StorageCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_StorageCopyWith(CoreError_Storage value, $Res Function(CoreError_Storage) _then) = _$CoreError_StorageCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_StorageCopyWithImpl<$Res>
    implements $CoreError_StorageCopyWith<$Res> {
  _$CoreError_StorageCopyWithImpl(this._self, this._then);

  final CoreError_Storage _self;
  final $Res Function(CoreError_Storage) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Storage(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CoreError_Internal extends CoreError {
  const CoreError_Internal({required this.message}): super._();
  

 final  String message;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_InternalCopyWith<CoreError_Internal> get copyWith => _$CoreError_InternalCopyWithImpl<CoreError_Internal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Internal&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'CoreError.internal(message: $message)';
}


}

/// @nodoc
abstract mixin class $CoreError_InternalCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_InternalCopyWith(CoreError_Internal value, $Res Function(CoreError_Internal) _then) = _$CoreError_InternalCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$CoreError_InternalCopyWithImpl<$Res>
    implements $CoreError_InternalCopyWith<$Res> {
  _$CoreError_InternalCopyWithImpl(this._self, this._then);

  final CoreError_Internal _self;
  final $Res Function(CoreError_Internal) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(CoreError_Internal(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
