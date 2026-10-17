// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TrackerRowsTable extends TrackerRows
    with TableInfo<$TrackerRowsTable, TrackerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackerRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _blurbMeta = const VerificationMeta('blurb');
  @override
  late final GeneratedColumn<String> blurb = GeneratedColumn<String>(
      'blurb', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _insightMeta =
      const VerificationMeta('insight');
  @override
  late final GeneratedColumn<String> insight = GeneratedColumn<String>(
      'insight', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<int> accent = GeneratedColumn<int>(
      'accent', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _accent2Meta =
      const VerificationMeta('accent2');
  @override
  late final GeneratedColumn<int> accent2 = GeneratedColumn<int>(
      'accent2', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<double> goal = GeneratedColumn<double>(
      'goal', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<double> step = GeneratedColumn<double>(
      'step', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _heroMeta = const VerificationMeta('hero');
  @override
  late final GeneratedColumn<bool> hero = GeneratedColumn<bool>(
      'hero', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("hero" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
      'hidden', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
      'sort', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        emoji,
        kind,
        unit,
        blurb,
        insight,
        accent,
        accent2,
        goal,
        step,
        hero,
        hidden,
        sort
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracker_rows';
  @override
  VerificationContext validateIntegrity(Insertable<TrackerRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('blurb')) {
      context.handle(
          _blurbMeta, blurb.isAcceptableOrUnknown(data['blurb']!, _blurbMeta));
    } else if (isInserting) {
      context.missing(_blurbMeta);
    }
    if (data.containsKey('insight')) {
      context.handle(_insightMeta,
          insight.isAcceptableOrUnknown(data['insight']!, _insightMeta));
    } else if (isInserting) {
      context.missing(_insightMeta);
    }
    if (data.containsKey('accent')) {
      context.handle(_accentMeta,
          accent.isAcceptableOrUnknown(data['accent']!, _accentMeta));
    } else if (isInserting) {
      context.missing(_accentMeta);
    }
    if (data.containsKey('accent2')) {
      context.handle(_accent2Meta,
          accent2.isAcceptableOrUnknown(data['accent2']!, _accent2Meta));
    } else if (isInserting) {
      context.missing(_accent2Meta);
    }
    if (data.containsKey('goal')) {
      context.handle(
          _goalMeta, goal.isAcceptableOrUnknown(data['goal']!, _goalMeta));
    } else if (isInserting) {
      context.missing(_goalMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
          _stepMeta, step.isAcceptableOrUnknown(data['step']!, _stepMeta));
    } else if (isInserting) {
      context.missing(_stepMeta);
    }
    if (data.containsKey('hero')) {
      context.handle(
          _heroMeta, hero.isAcceptableOrUnknown(data['hero']!, _heroMeta));
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta,
          hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('sort')) {
      context.handle(
          _sortMeta, sort.isAcceptableOrUnknown(data['sort']!, _sortMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackerRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      blurb: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blurb'])!,
      insight: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}insight'])!,
      accent: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}accent'])!,
      accent2: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}accent2'])!,
      goal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}goal'])!,
      step: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}step'])!,
      hero: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hero'])!,
      hidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
      sort: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort'])!,
    );
  }

  @override
  $TrackerRowsTable createAlias(String alias) {
    return $TrackerRowsTable(attachedDatabase, alias);
  }
}

class TrackerRow extends DataClass implements Insertable<TrackerRow> {
  final String id;
  final String name;
  final String emoji;
  final String kind;
  final String unit;
  final String blurb;
  final String insight;
  final int accent;
  final int accent2;
  final double goal;
  final double step;
  final bool hero;
  final bool hidden;
  final int sort;
  const TrackerRow(
      {required this.id,
      required this.name,
      required this.emoji,
      required this.kind,
      required this.unit,
      required this.blurb,
      required this.insight,
      required this.accent,
      required this.accent2,
      required this.goal,
      required this.step,
      required this.hero,
      required this.hidden,
      required this.sort});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['kind'] = Variable<String>(kind);
    map['unit'] = Variable<String>(unit);
    map['blurb'] = Variable<String>(blurb);
    map['insight'] = Variable<String>(insight);
    map['accent'] = Variable<int>(accent);
    map['accent2'] = Variable<int>(accent2);
    map['goal'] = Variable<double>(goal);
    map['step'] = Variable<double>(step);
    map['hero'] = Variable<bool>(hero);
    map['hidden'] = Variable<bool>(hidden);
    map['sort'] = Variable<int>(sort);
    return map;
  }

  TrackerRowsCompanion toCompanion(bool nullToAbsent) {
    return TrackerRowsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      kind: Value(kind),
      unit: Value(unit),
      blurb: Value(blurb),
      insight: Value(insight),
      accent: Value(accent),
      accent2: Value(accent2),
      goal: Value(goal),
      step: Value(step),
      hero: Value(hero),
      hidden: Value(hidden),
      sort: Value(sort),
    );
  }

  factory TrackerRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      kind: serializer.fromJson<String>(json['kind']),
      unit: serializer.fromJson<String>(json['unit']),
      blurb: serializer.fromJson<String>(json['blurb']),
      insight: serializer.fromJson<String>(json['insight']),
      accent: serializer.fromJson<int>(json['accent']),
      accent2: serializer.fromJson<int>(json['accent2']),
      goal: serializer.fromJson<double>(json['goal']),
      step: serializer.fromJson<double>(json['step']),
      hero: serializer.fromJson<bool>(json['hero']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'kind': serializer.toJson<String>(kind),
      'unit': serializer.toJson<String>(unit),
      'blurb': serializer.toJson<String>(blurb),
      'insight': serializer.toJson<String>(insight),
      'accent': serializer.toJson<int>(accent),
      'accent2': serializer.toJson<int>(accent2),
      'goal': serializer.toJson<double>(goal),
      'step': serializer.toJson<double>(step),
      'hero': serializer.toJson<bool>(hero),
      'hidden': serializer.toJson<bool>(hidden),
      'sort': serializer.toJson<int>(sort),
    };
  }

  TrackerRow copyWith(
          {String? id,
          String? name,
          String? emoji,
          String? kind,
          String? unit,
          String? blurb,
          String? insight,
          int? accent,
          int? accent2,
          double? goal,
          double? step,
          bool? hero,
          bool? hidden,
          int? sort}) =>
      TrackerRow(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        kind: kind ?? this.kind,
        unit: unit ?? this.unit,
        blurb: blurb ?? this.blurb,
        insight: insight ?? this.insight,
        accent: accent ?? this.accent,
        accent2: accent2 ?? this.accent2,
        goal: goal ?? this.goal,
        step: step ?? this.step,
        hero: hero ?? this.hero,
        hidden: hidden ?? this.hidden,
        sort: sort ?? this.sort,
      );
  TrackerRow copyWithCompanion(TrackerRowsCompanion data) {
    return TrackerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      kind: data.kind.present ? data.kind.value : this.kind,
      unit: data.unit.present ? data.unit.value : this.unit,
      blurb: data.blurb.present ? data.blurb.value : this.blurb,
      insight: data.insight.present ? data.insight.value : this.insight,
      accent: data.accent.present ? data.accent.value : this.accent,
      accent2: data.accent2.present ? data.accent2.value : this.accent2,
      goal: data.goal.present ? data.goal.value : this.goal,
      step: data.step.present ? data.step.value : this.step,
      hero: data.hero.present ? data.hero.value : this.hero,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('kind: $kind, ')
          ..write('unit: $unit, ')
          ..write('blurb: $blurb, ')
          ..write('insight: $insight, ')
          ..write('accent: $accent, ')
          ..write('accent2: $accent2, ')
          ..write('goal: $goal, ')
          ..write('step: $step, ')
          ..write('hero: $hero, ')
          ..write('hidden: $hidden, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, emoji, kind, unit, blurb, insight,
      accent, accent2, goal, step, hero, hidden, sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.kind == this.kind &&
          other.unit == this.unit &&
          other.blurb == this.blurb &&
          other.insight == this.insight &&
          other.accent == this.accent &&
          other.accent2 == this.accent2 &&
          other.goal == this.goal &&
          other.step == this.step &&
          other.hero == this.hero &&
          other.hidden == this.hidden &&
          other.sort == this.sort);
}

class TrackerRowsCompanion extends UpdateCompanion<TrackerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<String> kind;
  final Value<String> unit;
  final Value<String> blurb;
  final Value<String> insight;
  final Value<int> accent;
  final Value<int> accent2;
  final Value<double> goal;
  final Value<double> step;
  final Value<bool> hero;
  final Value<bool> hidden;
  final Value<int> sort;
  final Value<int> rowid;
  const TrackerRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.kind = const Value.absent(),
    this.unit = const Value.absent(),
    this.blurb = const Value.absent(),
    this.insight = const Value.absent(),
    this.accent = const Value.absent(),
    this.accent2 = const Value.absent(),
    this.goal = const Value.absent(),
    this.step = const Value.absent(),
    this.hero = const Value.absent(),
    this.hidden = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackerRowsCompanion.insert({
    required String id,
    required String name,
    required String emoji,
    required String kind,
    required String unit,
    required String blurb,
    required String insight,
    required int accent,
    required int accent2,
    required double goal,
    required double step,
    this.hero = const Value.absent(),
    this.hidden = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        emoji = Value(emoji),
        kind = Value(kind),
        unit = Value(unit),
        blurb = Value(blurb),
        insight = Value(insight),
        accent = Value(accent),
        accent2 = Value(accent2),
        goal = Value(goal),
        step = Value(step);
  static Insertable<TrackerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<String>? kind,
    Expression<String>? unit,
    Expression<String>? blurb,
    Expression<String>? insight,
    Expression<int>? accent,
    Expression<int>? accent2,
    Expression<double>? goal,
    Expression<double>? step,
    Expression<bool>? hero,
    Expression<bool>? hidden,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (kind != null) 'kind': kind,
      if (unit != null) 'unit': unit,
      if (blurb != null) 'blurb': blurb,
      if (insight != null) 'insight': insight,
      if (accent != null) 'accent': accent,
      if (accent2 != null) 'accent2': accent2,
      if (goal != null) 'goal': goal,
      if (step != null) 'step': step,
      if (hero != null) 'hero': hero,
      if (hidden != null) 'hidden': hidden,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackerRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? emoji,
      Value<String>? kind,
      Value<String>? unit,
      Value<String>? blurb,
      Value<String>? insight,
      Value<int>? accent,
      Value<int>? accent2,
      Value<double>? goal,
      Value<double>? step,
      Value<bool>? hero,
      Value<bool>? hidden,
      Value<int>? sort,
      Value<int>? rowid}) {
    return TrackerRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      kind: kind ?? this.kind,
      unit: unit ?? this.unit,
      blurb: blurb ?? this.blurb,
      insight: insight ?? this.insight,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      goal: goal ?? this.goal,
      step: step ?? this.step,
      hero: hero ?? this.hero,
      hidden: hidden ?? this.hidden,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (blurb.present) {
      map['blurb'] = Variable<String>(blurb.value);
    }
    if (insight.present) {
      map['insight'] = Variable<String>(insight.value);
    }
    if (accent.present) {
      map['accent'] = Variable<int>(accent.value);
    }
    if (accent2.present) {
      map['accent2'] = Variable<int>(accent2.value);
    }
    if (goal.present) {
      map['goal'] = Variable<double>(goal.value);
    }
    if (step.present) {
      map['step'] = Variable<double>(step.value);
    }
    if (hero.present) {
      map['hero'] = Variable<bool>(hero.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackerRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('kind: $kind, ')
          ..write('unit: $unit, ')
          ..write('blurb: $blurb, ')
          ..write('insight: $insight, ')
          ..write('accent: $accent, ')
          ..write('accent2: $accent2, ')
          ..write('goal: $goal, ')
          ..write('step: $step, ')
          ..write('hero: $hero, ')
          ..write('hidden: $hidden, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyEntriesTable extends DailyEntries
    with TableInfo<$DailyEntriesTable, DailyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trackerIdMeta =
      const VerificationMeta('trackerId');
  @override
  late final GeneratedColumn<String> trackerId = GeneratedColumn<String>(
      'tracker_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracker_rows (id) ON DELETE CASCADE'));
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
      'meta', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, trackerId, day, updatedAt, value, source, meta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_entries';
  @override
  VerificationContext validateIntegrity(Insertable<DailyEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tracker_id')) {
      context.handle(_trackerIdMeta,
          trackerId.isAcceptableOrUnknown(data['tracker_id']!, _trackerIdMeta));
    } else if (isInserting) {
      context.missing(_trackerIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {trackerId, day, source},
      ];
  @override
  DailyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trackerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tracker_id'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      meta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta']),
    );
  }

  @override
  $DailyEntriesTable createAlias(String alias) {
    return $DailyEntriesTable(attachedDatabase, alias);
  }
}

class DailyEntry extends DataClass implements Insertable<DailyEntry> {
  final int id;
  final String trackerId;

  /// Local day as yyyymmdd — an int key sorts and ranges cheaper than a date.
  final int day;
  final DateTime updatedAt;
  final double value;

  /// manual | health | widget | demo | import — user data always wins over sync.
  final String source;
  final String? meta;
  const DailyEntry(
      {required this.id,
      required this.trackerId,
      required this.day,
      required this.updatedAt,
      required this.value,
      required this.source,
      this.meta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tracker_id'] = Variable<String>(trackerId);
    map['day'] = Variable<int>(day);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['value'] = Variable<double>(value);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    return map;
  }

  DailyEntriesCompanion toCompanion(bool nullToAbsent) {
    return DailyEntriesCompanion(
      id: Value(id),
      trackerId: Value(trackerId),
      day: Value(day),
      updatedAt: Value(updatedAt),
      value: Value(value),
      source: Value(source),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
    );
  }

  factory DailyEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyEntry(
      id: serializer.fromJson<int>(json['id']),
      trackerId: serializer.fromJson<String>(json['trackerId']),
      day: serializer.fromJson<int>(json['day']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      value: serializer.fromJson<double>(json['value']),
      source: serializer.fromJson<String>(json['source']),
      meta: serializer.fromJson<String?>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackerId': serializer.toJson<String>(trackerId),
      'day': serializer.toJson<int>(day),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'value': serializer.toJson<double>(value),
      'source': serializer.toJson<String>(source),
      'meta': serializer.toJson<String?>(meta),
    };
  }

  DailyEntry copyWith(
          {int? id,
          String? trackerId,
          int? day,
          DateTime? updatedAt,
          double? value,
          String? source,
          Value<String?> meta = const Value.absent()}) =>
      DailyEntry(
        id: id ?? this.id,
        trackerId: trackerId ?? this.trackerId,
        day: day ?? this.day,
        updatedAt: updatedAt ?? this.updatedAt,
        value: value ?? this.value,
        source: source ?? this.source,
        meta: meta.present ? meta.value : this.meta,
      );
  DailyEntry copyWithCompanion(DailyEntriesCompanion data) {
    return DailyEntry(
      id: data.id.present ? data.id.value : this.id,
      trackerId: data.trackerId.present ? data.trackerId.value : this.trackerId,
      day: data.day.present ? data.day.value : this.day,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      value: data.value.present ? data.value.value : this.value,
      source: data.source.present ? data.source.value : this.source,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyEntry(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('day: $day, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trackerId, day, updatedAt, value, source, meta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyEntry &&
          other.id == this.id &&
          other.trackerId == this.trackerId &&
          other.day == this.day &&
          other.updatedAt == this.updatedAt &&
          other.value == this.value &&
          other.source == this.source &&
          other.meta == this.meta);
}

class DailyEntriesCompanion extends UpdateCompanion<DailyEntry> {
  final Value<int> id;
  final Value<String> trackerId;
  final Value<int> day;
  final Value<DateTime> updatedAt;
  final Value<double> value;
  final Value<String> source;
  final Value<String?> meta;
  const DailyEntriesCompanion({
    this.id = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.day = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.value = const Value.absent(),
    this.source = const Value.absent(),
    this.meta = const Value.absent(),
  });
  DailyEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String trackerId,
    required int day,
    required DateTime updatedAt,
    required double value,
    this.source = const Value.absent(),
    this.meta = const Value.absent(),
  })  : trackerId = Value(trackerId),
        day = Value(day),
        updatedAt = Value(updatedAt),
        value = Value(value);
  static Insertable<DailyEntry> custom({
    Expression<int>? id,
    Expression<String>? trackerId,
    Expression<int>? day,
    Expression<DateTime>? updatedAt,
    Expression<double>? value,
    Expression<String>? source,
    Expression<String>? meta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackerId != null) 'tracker_id': trackerId,
      if (day != null) 'day': day,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (value != null) 'value': value,
      if (source != null) 'source': source,
      if (meta != null) 'meta': meta,
    });
  }

  DailyEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? trackerId,
      Value<int>? day,
      Value<DateTime>? updatedAt,
      Value<double>? value,
      Value<String>? source,
      Value<String?>? meta}) {
    return DailyEntriesCompanion(
      id: id ?? this.id,
      trackerId: trackerId ?? this.trackerId,
      day: day ?? this.day,
      updatedAt: updatedAt ?? this.updatedAt,
      value: value ?? this.value,
      source: source ?? this.source,
      meta: meta ?? this.meta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackerId.present) {
      map['tracker_id'] = Variable<String>(trackerId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('day: $day, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trackerIdMeta =
      const VerificationMeta('trackerId');
  @override
  late final GeneratedColumn<String> trackerId = GeneratedColumn<String>(
      'tracker_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracker_rows (id) ON DELETE CASCADE'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<DateTime> ts = GeneratedColumn<DateTime>(
      'ts', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
      'meta', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, trackerId, ts, day, value, source, meta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(Insertable<EventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tracker_id')) {
      context.handle(_trackerIdMeta,
          trackerId.isAcceptableOrUnknown(data['tracker_id']!, _trackerIdMeta));
    } else if (isInserting) {
      context.missing(_trackerIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trackerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tracker_id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ts'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      meta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta']),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;
  final String trackerId;
  final DateTime ts;
  final int day;
  final double value;
  final String source;
  final String? meta;
  const EventRow(
      {required this.id,
      required this.trackerId,
      required this.ts,
      required this.day,
      required this.value,
      required this.source,
      this.meta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tracker_id'] = Variable<String>(trackerId);
    map['ts'] = Variable<DateTime>(ts);
    map['day'] = Variable<int>(day);
    map['value'] = Variable<double>(value);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      trackerId: Value(trackerId),
      ts: Value(ts),
      day: Value(day),
      value: Value(value),
      source: Value(source),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
    );
  }

  factory EventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      trackerId: serializer.fromJson<String>(json['trackerId']),
      ts: serializer.fromJson<DateTime>(json['ts']),
      day: serializer.fromJson<int>(json['day']),
      value: serializer.fromJson<double>(json['value']),
      source: serializer.fromJson<String>(json['source']),
      meta: serializer.fromJson<String?>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackerId': serializer.toJson<String>(trackerId),
      'ts': serializer.toJson<DateTime>(ts),
      'day': serializer.toJson<int>(day),
      'value': serializer.toJson<double>(value),
      'source': serializer.toJson<String>(source),
      'meta': serializer.toJson<String?>(meta),
    };
  }

  EventRow copyWith(
          {int? id,
          String? trackerId,
          DateTime? ts,
          int? day,
          double? value,
          String? source,
          Value<String?> meta = const Value.absent()}) =>
      EventRow(
        id: id ?? this.id,
        trackerId: trackerId ?? this.trackerId,
        ts: ts ?? this.ts,
        day: day ?? this.day,
        value: value ?? this.value,
        source: source ?? this.source,
        meta: meta.present ? meta.value : this.meta,
      );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      trackerId: data.trackerId.present ? data.trackerId.value : this.trackerId,
      ts: data.ts.present ? data.ts.value : this.ts,
      day: data.day.present ? data.day.value : this.day,
      value: data.value.present ? data.value.value : this.value,
      source: data.source.present ? data.source.value : this.source,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('ts: $ts, ')
          ..write('day: $day, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackerId, ts, day, value, source, meta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.trackerId == this.trackerId &&
          other.ts == this.ts &&
          other.day == this.day &&
          other.value == this.value &&
          other.source == this.source &&
          other.meta == this.meta);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<String> trackerId;
  final Value<DateTime> ts;
  final Value<int> day;
  final Value<double> value;
  final Value<String> source;
  final Value<String?> meta;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.ts = const Value.absent(),
    this.day = const Value.absent(),
    this.value = const Value.absent(),
    this.source = const Value.absent(),
    this.meta = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String trackerId,
    required DateTime ts,
    required int day,
    required double value,
    this.source = const Value.absent(),
    this.meta = const Value.absent(),
  })  : trackerId = Value(trackerId),
        ts = Value(ts),
        day = Value(day),
        value = Value(value);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<String>? trackerId,
    Expression<DateTime>? ts,
    Expression<int>? day,
    Expression<double>? value,
    Expression<String>? source,
    Expression<String>? meta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackerId != null) 'tracker_id': trackerId,
      if (ts != null) 'ts': ts,
      if (day != null) 'day': day,
      if (value != null) 'value': value,
      if (source != null) 'source': source,
      if (meta != null) 'meta': meta,
    });
  }

  EventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? trackerId,
      Value<DateTime>? ts,
      Value<int>? day,
      Value<double>? value,
      Value<String>? source,
      Value<String?>? meta}) {
    return EventsCompanion(
      id: id ?? this.id,
      trackerId: trackerId ?? this.trackerId,
      ts: ts ?? this.ts,
      day: day ?? this.day,
      value: value ?? this.value,
      source: source ?? this.source,
      meta: meta ?? this.meta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackerId.present) {
      map['tracker_id'] = Variable<String>(trackerId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<DateTime>(ts.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('ts: $ts, ')
          ..write('day: $day, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) => AppSettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchasesTable extends Purchases
    with TableInfo<$PurchasesTable, PurchaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _purchaseTokenMeta =
      const VerificationMeta('purchaseToken');
  @override
  late final GeneratedColumn<String> purchaseToken = GeneratedColumn<String>(
      'purchase_token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _purchasedAtMeta =
      const VerificationMeta('purchasedAt');
  @override
  late final GeneratedColumn<DateTime> purchasedAt = GeneratedColumn<DateTime>(
      'purchased_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _autoRenewMeta =
      const VerificationMeta('autoRenew');
  @override
  late final GeneratedColumn<bool> autoRenew = GeneratedColumn<bool>(
      'auto_renew', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("auto_renew" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _acknowledgedMeta =
      const VerificationMeta('acknowledged');
  @override
  late final GeneratedColumn<bool> acknowledged = GeneratedColumn<bool>(
      'acknowledged', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("acknowledged" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _serverVerifiedMeta =
      const VerificationMeta('serverVerified');
  @override
  late final GeneratedColumn<bool> serverVerified = GeneratedColumn<bool>(
      'server_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("server_verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _trialMeta = const VerificationMeta('trial');
  @override
  late final GeneratedColumn<bool> trial = GeneratedColumn<bool>(
      'trial', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("trial" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<String> raw = GeneratedColumn<String>(
      'raw', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        purchaseToken,
        status,
        purchasedAt,
        expiresAt,
        autoRenew,
        acknowledged,
        serverVerified,
        trial,
        raw
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchases';
  @override
  VerificationContext validateIntegrity(Insertable<PurchaseRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('purchase_token')) {
      context.handle(
          _purchaseTokenMeta,
          purchaseToken.isAcceptableOrUnknown(
              data['purchase_token']!, _purchaseTokenMeta));
    } else if (isInserting) {
      context.missing(_purchaseTokenMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('purchased_at')) {
      context.handle(
          _purchasedAtMeta,
          purchasedAt.isAcceptableOrUnknown(
              data['purchased_at']!, _purchasedAtMeta));
    } else if (isInserting) {
      context.missing(_purchasedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    if (data.containsKey('auto_renew')) {
      context.handle(_autoRenewMeta,
          autoRenew.isAcceptableOrUnknown(data['auto_renew']!, _autoRenewMeta));
    }
    if (data.containsKey('acknowledged')) {
      context.handle(
          _acknowledgedMeta,
          acknowledged.isAcceptableOrUnknown(
              data['acknowledged']!, _acknowledgedMeta));
    }
    if (data.containsKey('server_verified')) {
      context.handle(
          _serverVerifiedMeta,
          serverVerified.isAcceptableOrUnknown(
              data['server_verified']!, _serverVerifiedMeta));
    }
    if (data.containsKey('trial')) {
      context.handle(
          _trialMeta, trial.isAcceptableOrUnknown(data['trial']!, _trialMeta));
    }
    if (data.containsKey('raw')) {
      context.handle(
          _rawMeta, raw.isAcceptableOrUnknown(data['raw']!, _rawMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {purchaseToken, productId},
      ];
  @override
  PurchaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      purchaseToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purchase_token'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      purchasedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}purchased_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
      autoRenew: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}auto_renew'])!,
      acknowledged: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}acknowledged'])!,
      serverVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}server_verified'])!,
      trial: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}trial'])!,
      raw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw']),
    );
  }

  @override
  $PurchasesTable createAlias(String alias) {
    return $PurchasesTable(attachedDatabase, alias);
  }
}

class PurchaseRow extends DataClass implements Insertable<PurchaseRow> {
  final int id;
  final String productId;

  /// Play purchase token — the key the backend verifies against the Developer API.
  final String purchaseToken;

  /// purchased | restored | pending | canceled | error | expired | refunded
  final String status;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final bool acknowledged;
  final bool serverVerified;
  final bool trial;
  final String? raw;
  const PurchaseRow(
      {required this.id,
      required this.productId,
      required this.purchaseToken,
      required this.status,
      required this.purchasedAt,
      this.expiresAt,
      required this.autoRenew,
      required this.acknowledged,
      required this.serverVerified,
      required this.trial,
      this.raw});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<String>(productId);
    map['purchase_token'] = Variable<String>(purchaseToken);
    map['status'] = Variable<String>(status);
    map['purchased_at'] = Variable<DateTime>(purchasedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['auto_renew'] = Variable<bool>(autoRenew);
    map['acknowledged'] = Variable<bool>(acknowledged);
    map['server_verified'] = Variable<bool>(serverVerified);
    map['trial'] = Variable<bool>(trial);
    if (!nullToAbsent || raw != null) {
      map['raw'] = Variable<String>(raw);
    }
    return map;
  }

  PurchasesCompanion toCompanion(bool nullToAbsent) {
    return PurchasesCompanion(
      id: Value(id),
      productId: Value(productId),
      purchaseToken: Value(purchaseToken),
      status: Value(status),
      purchasedAt: Value(purchasedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      autoRenew: Value(autoRenew),
      acknowledged: Value(acknowledged),
      serverVerified: Value(serverVerified),
      trial: Value(trial),
      raw: raw == null && nullToAbsent ? const Value.absent() : Value(raw),
    );
  }

  factory PurchaseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseRow(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      purchaseToken: serializer.fromJson<String>(json['purchaseToken']),
      status: serializer.fromJson<String>(json['status']),
      purchasedAt: serializer.fromJson<DateTime>(json['purchasedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      autoRenew: serializer.fromJson<bool>(json['autoRenew']),
      acknowledged: serializer.fromJson<bool>(json['acknowledged']),
      serverVerified: serializer.fromJson<bool>(json['serverVerified']),
      trial: serializer.fromJson<bool>(json['trial']),
      raw: serializer.fromJson<String?>(json['raw']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<String>(productId),
      'purchaseToken': serializer.toJson<String>(purchaseToken),
      'status': serializer.toJson<String>(status),
      'purchasedAt': serializer.toJson<DateTime>(purchasedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'autoRenew': serializer.toJson<bool>(autoRenew),
      'acknowledged': serializer.toJson<bool>(acknowledged),
      'serverVerified': serializer.toJson<bool>(serverVerified),
      'trial': serializer.toJson<bool>(trial),
      'raw': serializer.toJson<String?>(raw),
    };
  }

  PurchaseRow copyWith(
          {int? id,
          String? productId,
          String? purchaseToken,
          String? status,
          DateTime? purchasedAt,
          Value<DateTime?> expiresAt = const Value.absent(),
          bool? autoRenew,
          bool? acknowledged,
          bool? serverVerified,
          bool? trial,
          Value<String?> raw = const Value.absent()}) =>
      PurchaseRow(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        purchaseToken: purchaseToken ?? this.purchaseToken,
        status: status ?? this.status,
        purchasedAt: purchasedAt ?? this.purchasedAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
        autoRenew: autoRenew ?? this.autoRenew,
        acknowledged: acknowledged ?? this.acknowledged,
        serverVerified: serverVerified ?? this.serverVerified,
        trial: trial ?? this.trial,
        raw: raw.present ? raw.value : this.raw,
      );
  PurchaseRow copyWithCompanion(PurchasesCompanion data) {
    return PurchaseRow(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      purchaseToken: data.purchaseToken.present
          ? data.purchaseToken.value
          : this.purchaseToken,
      status: data.status.present ? data.status.value : this.status,
      purchasedAt:
          data.purchasedAt.present ? data.purchasedAt.value : this.purchasedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      autoRenew: data.autoRenew.present ? data.autoRenew.value : this.autoRenew,
      acknowledged: data.acknowledged.present
          ? data.acknowledged.value
          : this.acknowledged,
      serverVerified: data.serverVerified.present
          ? data.serverVerified.value
          : this.serverVerified,
      trial: data.trial.present ? data.trial.value : this.trial,
      raw: data.raw.present ? data.raw.value : this.raw,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseRow(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('purchaseToken: $purchaseToken, ')
          ..write('status: $status, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('autoRenew: $autoRenew, ')
          ..write('acknowledged: $acknowledged, ')
          ..write('serverVerified: $serverVerified, ')
          ..write('trial: $trial, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      productId,
      purchaseToken,
      status,
      purchasedAt,
      expiresAt,
      autoRenew,
      acknowledged,
      serverVerified,
      trial,
      raw);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseRow &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.purchaseToken == this.purchaseToken &&
          other.status == this.status &&
          other.purchasedAt == this.purchasedAt &&
          other.expiresAt == this.expiresAt &&
          other.autoRenew == this.autoRenew &&
          other.acknowledged == this.acknowledged &&
          other.serverVerified == this.serverVerified &&
          other.trial == this.trial &&
          other.raw == this.raw);
}

class PurchasesCompanion extends UpdateCompanion<PurchaseRow> {
  final Value<int> id;
  final Value<String> productId;
  final Value<String> purchaseToken;
  final Value<String> status;
  final Value<DateTime> purchasedAt;
  final Value<DateTime?> expiresAt;
  final Value<bool> autoRenew;
  final Value<bool> acknowledged;
  final Value<bool> serverVerified;
  final Value<bool> trial;
  final Value<String?> raw;
  const PurchasesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.purchaseToken = const Value.absent(),
    this.status = const Value.absent(),
    this.purchasedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.autoRenew = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.serverVerified = const Value.absent(),
    this.trial = const Value.absent(),
    this.raw = const Value.absent(),
  });
  PurchasesCompanion.insert({
    this.id = const Value.absent(),
    required String productId,
    required String purchaseToken,
    required String status,
    required DateTime purchasedAt,
    this.expiresAt = const Value.absent(),
    this.autoRenew = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.serverVerified = const Value.absent(),
    this.trial = const Value.absent(),
    this.raw = const Value.absent(),
  })  : productId = Value(productId),
        purchaseToken = Value(purchaseToken),
        status = Value(status),
        purchasedAt = Value(purchasedAt);
  static Insertable<PurchaseRow> custom({
    Expression<int>? id,
    Expression<String>? productId,
    Expression<String>? purchaseToken,
    Expression<String>? status,
    Expression<DateTime>? purchasedAt,
    Expression<DateTime>? expiresAt,
    Expression<bool>? autoRenew,
    Expression<bool>? acknowledged,
    Expression<bool>? serverVerified,
    Expression<bool>? trial,
    Expression<String>? raw,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (purchaseToken != null) 'purchase_token': purchaseToken,
      if (status != null) 'status': status,
      if (purchasedAt != null) 'purchased_at': purchasedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (autoRenew != null) 'auto_renew': autoRenew,
      if (acknowledged != null) 'acknowledged': acknowledged,
      if (serverVerified != null) 'server_verified': serverVerified,
      if (trial != null) 'trial': trial,
      if (raw != null) 'raw': raw,
    });
  }

  PurchasesCompanion copyWith(
      {Value<int>? id,
      Value<String>? productId,
      Value<String>? purchaseToken,
      Value<String>? status,
      Value<DateTime>? purchasedAt,
      Value<DateTime?>? expiresAt,
      Value<bool>? autoRenew,
      Value<bool>? acknowledged,
      Value<bool>? serverVerified,
      Value<bool>? trial,
      Value<String?>? raw}) {
    return PurchasesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      status: status ?? this.status,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
      acknowledged: acknowledged ?? this.acknowledged,
      serverVerified: serverVerified ?? this.serverVerified,
      trial: trial ?? this.trial,
      raw: raw ?? this.raw,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (purchaseToken.present) {
      map['purchase_token'] = Variable<String>(purchaseToken.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (purchasedAt.present) {
      map['purchased_at'] = Variable<DateTime>(purchasedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (autoRenew.present) {
      map['auto_renew'] = Variable<bool>(autoRenew.value);
    }
    if (acknowledged.present) {
      map['acknowledged'] = Variable<bool>(acknowledged.value);
    }
    if (serverVerified.present) {
      map['server_verified'] = Variable<bool>(serverVerified.value);
    }
    if (trial.present) {
      map['trial'] = Variable<bool>(trial.value);
    }
    if (raw.present) {
      map['raw'] = Variable<String>(raw.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchasesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('purchaseToken: $purchaseToken, ')
          ..write('status: $status, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('autoRenew: $autoRenew, ')
          ..write('acknowledged: $acknowledged, ')
          ..write('serverVerified: $serverVerified, ')
          ..write('trial: $trial, ')
          ..write('raw: $raw')
          ..write(')'))
        .toString();
  }
}

class $TrackEventsTable extends TrackEvents
    with TableInfo<$TrackEventsTable, TrackEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
      'at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
      'meta', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, at, meta];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_events';
  @override
  VerificationContext validateIntegrity(Insertable<TrackEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      at: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
      meta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta']),
    );
  }

  @override
  $TrackEventsTable createAlias(String alias) {
    return $TrackEventsTable(attachedDatabase, alias);
  }
}

class TrackEventRow extends DataClass implements Insertable<TrackEventRow> {
  final int id;
  final String name;
  final DateTime at;
  final String? meta;
  const TrackEventRow(
      {required this.id, required this.name, required this.at, this.meta});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['at'] = Variable<DateTime>(at);
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    return map;
  }

  TrackEventsCompanion toCompanion(bool nullToAbsent) {
    return TrackEventsCompanion(
      id: Value(id),
      name: Value(name),
      at: Value(at),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
    );
  }

  factory TrackEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackEventRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      at: serializer.fromJson<DateTime>(json['at']),
      meta: serializer.fromJson<String?>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'at': serializer.toJson<DateTime>(at),
      'meta': serializer.toJson<String?>(meta),
    };
  }

  TrackEventRow copyWith(
          {int? id,
          String? name,
          DateTime? at,
          Value<String?> meta = const Value.absent()}) =>
      TrackEventRow(
        id: id ?? this.id,
        name: name ?? this.name,
        at: at ?? this.at,
        meta: meta.present ? meta.value : this.meta,
      );
  TrackEventRow copyWithCompanion(TrackEventsCompanion data) {
    return TrackEventRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      at: data.at.present ? data.at.value : this.at,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackEventRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('at: $at, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, at, meta);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackEventRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.at == this.at &&
          other.meta == this.meta);
}

class TrackEventsCompanion extends UpdateCompanion<TrackEventRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> at;
  final Value<String?> meta;
  const TrackEventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.at = const Value.absent(),
    this.meta = const Value.absent(),
  });
  TrackEventsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime at,
    this.meta = const Value.absent(),
  })  : name = Value(name),
        at = Value(at);
  static Insertable<TrackEventRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? at,
    Expression<String>? meta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (at != null) 'at': at,
      if (meta != null) 'meta': meta,
    });
  }

  TrackEventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<DateTime>? at,
      Value<String?>? meta}) {
    return TrackEventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      at: at ?? this.at,
      meta: meta ?? this.meta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackEventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('at: $at, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }
}

class $CommitmentRowsTable extends CommitmentRows
    with TableInfo<$CommitmentRowsTable, CommitmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommitmentRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _minimumActionMeta =
      const VerificationMeta('minimumAction');
  @override
  late final GeneratedColumn<String> minimumAction = GeneratedColumn<String>(
      'minimum_action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fullActionMeta =
      const VerificationMeta('fullAction');
  @override
  late final GeneratedColumn<String> fullAction = GeneratedColumn<String>(
      'full_action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduleJsonMeta =
      const VerificationMeta('scheduleJson');
  @override
  late final GeneratedColumn<String> scheduleJson = GeneratedColumn<String>(
      'schedule_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDayMeta =
      const VerificationMeta('createdDay');
  @override
  late final GeneratedColumn<int> createdDay = GeneratedColumn<int>(
      'created_day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _archivedDayMeta =
      const VerificationMeta('archivedDay');
  @override
  late final GeneratedColumn<int> archivedDay = GeneratedColumn<int>(
      'archived_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
      'sort', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        emoji,
        color,
        outcome,
        minimumAction,
        fullAction,
        scheduleJson,
        createdDay,
        archived,
        archivedDay,
        sort
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commitment_rows';
  @override
  VerificationContext validateIntegrity(Insertable<CommitmentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('minimum_action')) {
      context.handle(
          _minimumActionMeta,
          minimumAction.isAcceptableOrUnknown(
              data['minimum_action']!, _minimumActionMeta));
    } else if (isInserting) {
      context.missing(_minimumActionMeta);
    }
    if (data.containsKey('full_action')) {
      context.handle(
          _fullActionMeta,
          fullAction.isAcceptableOrUnknown(
              data['full_action']!, _fullActionMeta));
    } else if (isInserting) {
      context.missing(_fullActionMeta);
    }
    if (data.containsKey('schedule_json')) {
      context.handle(
          _scheduleJsonMeta,
          scheduleJson.isAcceptableOrUnknown(
              data['schedule_json']!, _scheduleJsonMeta));
    } else if (isInserting) {
      context.missing(_scheduleJsonMeta);
    }
    if (data.containsKey('created_day')) {
      context.handle(
          _createdDayMeta,
          createdDay.isAcceptableOrUnknown(
              data['created_day']!, _createdDayMeta));
    } else if (isInserting) {
      context.missing(_createdDayMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('archived_day')) {
      context.handle(
          _archivedDayMeta,
          archivedDay.isAcceptableOrUnknown(
              data['archived_day']!, _archivedDayMeta));
    }
    if (data.containsKey('sort')) {
      context.handle(
          _sortMeta, sort.isAcceptableOrUnknown(data['sort']!, _sortMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommitmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommitmentRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      minimumAction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}minimum_action'])!,
      fullAction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}full_action'])!,
      scheduleJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}schedule_json'])!,
      createdDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_day'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      archivedDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}archived_day']),
      sort: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort'])!,
    );
  }

  @override
  $CommitmentRowsTable createAlias(String alias) {
    return $CommitmentRowsTable(attachedDatabase, alias);
  }
}

class CommitmentRow extends DataClass implements Insertable<CommitmentRow> {
  final String id;
  final String name;
  final String emoji;
  final int color;

  /// The desired outcome, in the user's words. Never scored.
  final String outcome;
  final String minimumAction;
  final String fullAction;

  /// `[[fromDay,[weekdays...]], ...]`, oldest first. Always at least one entry.
  final String scheduleJson;

  /// Nothing before this day is ever counted, planned or judged.
  final int createdDay;
  final bool archived;
  final int? archivedDay;
  final int sort;
  const CommitmentRow(
      {required this.id,
      required this.name,
      required this.emoji,
      required this.color,
      required this.outcome,
      required this.minimumAction,
      required this.fullAction,
      required this.scheduleJson,
      required this.createdDay,
      required this.archived,
      this.archivedDay,
      required this.sort});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['color'] = Variable<int>(color);
    map['outcome'] = Variable<String>(outcome);
    map['minimum_action'] = Variable<String>(minimumAction);
    map['full_action'] = Variable<String>(fullAction);
    map['schedule_json'] = Variable<String>(scheduleJson);
    map['created_day'] = Variable<int>(createdDay);
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || archivedDay != null) {
      map['archived_day'] = Variable<int>(archivedDay);
    }
    map['sort'] = Variable<int>(sort);
    return map;
  }

  CommitmentRowsCompanion toCompanion(bool nullToAbsent) {
    return CommitmentRowsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      color: Value(color),
      outcome: Value(outcome),
      minimumAction: Value(minimumAction),
      fullAction: Value(fullAction),
      scheduleJson: Value(scheduleJson),
      createdDay: Value(createdDay),
      archived: Value(archived),
      archivedDay: archivedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedDay),
      sort: Value(sort),
    );
  }

  factory CommitmentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommitmentRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      color: serializer.fromJson<int>(json['color']),
      outcome: serializer.fromJson<String>(json['outcome']),
      minimumAction: serializer.fromJson<String>(json['minimumAction']),
      fullAction: serializer.fromJson<String>(json['fullAction']),
      scheduleJson: serializer.fromJson<String>(json['scheduleJson']),
      createdDay: serializer.fromJson<int>(json['createdDay']),
      archived: serializer.fromJson<bool>(json['archived']),
      archivedDay: serializer.fromJson<int?>(json['archivedDay']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'color': serializer.toJson<int>(color),
      'outcome': serializer.toJson<String>(outcome),
      'minimumAction': serializer.toJson<String>(minimumAction),
      'fullAction': serializer.toJson<String>(fullAction),
      'scheduleJson': serializer.toJson<String>(scheduleJson),
      'createdDay': serializer.toJson<int>(createdDay),
      'archived': serializer.toJson<bool>(archived),
      'archivedDay': serializer.toJson<int?>(archivedDay),
      'sort': serializer.toJson<int>(sort),
    };
  }

  CommitmentRow copyWith(
          {String? id,
          String? name,
          String? emoji,
          int? color,
          String? outcome,
          String? minimumAction,
          String? fullAction,
          String? scheduleJson,
          int? createdDay,
          bool? archived,
          Value<int?> archivedDay = const Value.absent(),
          int? sort}) =>
      CommitmentRow(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        outcome: outcome ?? this.outcome,
        minimumAction: minimumAction ?? this.minimumAction,
        fullAction: fullAction ?? this.fullAction,
        scheduleJson: scheduleJson ?? this.scheduleJson,
        createdDay: createdDay ?? this.createdDay,
        archived: archived ?? this.archived,
        archivedDay: archivedDay.present ? archivedDay.value : this.archivedDay,
        sort: sort ?? this.sort,
      );
  CommitmentRow copyWithCompanion(CommitmentRowsCompanion data) {
    return CommitmentRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      color: data.color.present ? data.color.value : this.color,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      minimumAction: data.minimumAction.present
          ? data.minimumAction.value
          : this.minimumAction,
      fullAction:
          data.fullAction.present ? data.fullAction.value : this.fullAction,
      scheduleJson: data.scheduleJson.present
          ? data.scheduleJson.value
          : this.scheduleJson,
      createdDay:
          data.createdDay.present ? data.createdDay.value : this.createdDay,
      archived: data.archived.present ? data.archived.value : this.archived,
      archivedDay:
          data.archivedDay.present ? data.archivedDay.value : this.archivedDay,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('color: $color, ')
          ..write('outcome: $outcome, ')
          ..write('minimumAction: $minimumAction, ')
          ..write('fullAction: $fullAction, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('createdDay: $createdDay, ')
          ..write('archived: $archived, ')
          ..write('archivedDay: $archivedDay, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      emoji,
      color,
      outcome,
      minimumAction,
      fullAction,
      scheduleJson,
      createdDay,
      archived,
      archivedDay,
      sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommitmentRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.color == this.color &&
          other.outcome == this.outcome &&
          other.minimumAction == this.minimumAction &&
          other.fullAction == this.fullAction &&
          other.scheduleJson == this.scheduleJson &&
          other.createdDay == this.createdDay &&
          other.archived == this.archived &&
          other.archivedDay == this.archivedDay &&
          other.sort == this.sort);
}

class CommitmentRowsCompanion extends UpdateCompanion<CommitmentRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<int> color;
  final Value<String> outcome;
  final Value<String> minimumAction;
  final Value<String> fullAction;
  final Value<String> scheduleJson;
  final Value<int> createdDay;
  final Value<bool> archived;
  final Value<int?> archivedDay;
  final Value<int> sort;
  final Value<int> rowid;
  const CommitmentRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.color = const Value.absent(),
    this.outcome = const Value.absent(),
    this.minimumAction = const Value.absent(),
    this.fullAction = const Value.absent(),
    this.scheduleJson = const Value.absent(),
    this.createdDay = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedDay = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommitmentRowsCompanion.insert({
    required String id,
    required String name,
    required String emoji,
    required int color,
    required String outcome,
    required String minimumAction,
    required String fullAction,
    required String scheduleJson,
    required int createdDay,
    this.archived = const Value.absent(),
    this.archivedDay = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        emoji = Value(emoji),
        color = Value(color),
        outcome = Value(outcome),
        minimumAction = Value(minimumAction),
        fullAction = Value(fullAction),
        scheduleJson = Value(scheduleJson),
        createdDay = Value(createdDay);
  static Insertable<CommitmentRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? color,
    Expression<String>? outcome,
    Expression<String>? minimumAction,
    Expression<String>? fullAction,
    Expression<String>? scheduleJson,
    Expression<int>? createdDay,
    Expression<bool>? archived,
    Expression<int>? archivedDay,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (color != null) 'color': color,
      if (outcome != null) 'outcome': outcome,
      if (minimumAction != null) 'minimum_action': minimumAction,
      if (fullAction != null) 'full_action': fullAction,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
      if (createdDay != null) 'created_day': createdDay,
      if (archived != null) 'archived': archived,
      if (archivedDay != null) 'archived_day': archivedDay,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommitmentRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? emoji,
      Value<int>? color,
      Value<String>? outcome,
      Value<String>? minimumAction,
      Value<String>? fullAction,
      Value<String>? scheduleJson,
      Value<int>? createdDay,
      Value<bool>? archived,
      Value<int?>? archivedDay,
      Value<int>? sort,
      Value<int>? rowid}) {
    return CommitmentRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      outcome: outcome ?? this.outcome,
      minimumAction: minimumAction ?? this.minimumAction,
      fullAction: fullAction ?? this.fullAction,
      scheduleJson: scheduleJson ?? this.scheduleJson,
      createdDay: createdDay ?? this.createdDay,
      archived: archived ?? this.archived,
      archivedDay: archivedDay ?? this.archivedDay,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (minimumAction.present) {
      map['minimum_action'] = Variable<String>(minimumAction.value);
    }
    if (fullAction.present) {
      map['full_action'] = Variable<String>(fullAction.value);
    }
    if (scheduleJson.present) {
      map['schedule_json'] = Variable<String>(scheduleJson.value);
    }
    if (createdDay.present) {
      map['created_day'] = Variable<int>(createdDay.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (archivedDay.present) {
      map['archived_day'] = Variable<int>(archivedDay.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('color: $color, ')
          ..write('outcome: $outcome, ')
          ..write('minimumAction: $minimumAction, ')
          ..write('fullAction: $fullAction, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('createdDay: $createdDay, ')
          ..write('archived: $archived, ')
          ..write('archivedDay: $archivedDay, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommitmentEntriesTable extends CommitmentEntries
    with TableInfo<$CommitmentEntriesTable, CommitmentEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommitmentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _commitmentIdMeta =
      const VerificationMeta('commitmentId');
  @override
  late final GeneratedColumn<String> commitmentId = GeneratedColumn<String>(
      'commitment_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES commitment_rows (id) ON DELETE CASCADE'));
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, commitmentId, day, outcome, value, note, recordedAt, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commitment_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CommitmentEntryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('commitment_id')) {
      context.handle(
          _commitmentIdMeta,
          commitmentId.isAcceptableOrUnknown(
              data['commitment_id']!, _commitmentIdMeta));
    } else if (isInserting) {
      context.missing(_commitmentIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {commitmentId, day},
      ];
  @override
  CommitmentEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommitmentEntryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      commitmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}commitment_id'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $CommitmentEntriesTable createAlias(String alias) {
    return $CommitmentEntriesTable(attachedDatabase, alias);
  }
}

class CommitmentEntryRow extends DataClass
    implements Insertable<CommitmentEntryRow> {
  final int id;
  final String commitmentId;

  /// Local day as yyyymmdd, same convention as `daily_entries`.
  final int day;

  /// full | minimum | missed | rest | skipped
  final String outcome;

  /// What was actually completed, when the user typed an amount. Nullable: absent
  /// is not zero.
  final double? value;
  final String? note;
  final DateTime recordedAt;

  /// manual | import — for symmetry with the tracker tables. Note that no seeder
  /// can write here: there is no seeder.
  final String source;
  const CommitmentEntryRow(
      {required this.id,
      required this.commitmentId,
      required this.day,
      required this.outcome,
      this.value,
      this.note,
      required this.recordedAt,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['commitment_id'] = Variable<String>(commitmentId);
    map['day'] = Variable<int>(day);
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['source'] = Variable<String>(source);
    return map;
  }

  CommitmentEntriesCompanion toCompanion(bool nullToAbsent) {
    return CommitmentEntriesCompanion(
      id: Value(id),
      commitmentId: Value(commitmentId),
      day: Value(day),
      outcome: Value(outcome),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedAt: Value(recordedAt),
      source: Value(source),
    );
  }

  factory CommitmentEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommitmentEntryRow(
      id: serializer.fromJson<int>(json['id']),
      commitmentId: serializer.fromJson<String>(json['commitmentId']),
      day: serializer.fromJson<int>(json['day']),
      outcome: serializer.fromJson<String>(json['outcome']),
      value: serializer.fromJson<double?>(json['value']),
      note: serializer.fromJson<String?>(json['note']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'commitmentId': serializer.toJson<String>(commitmentId),
      'day': serializer.toJson<int>(day),
      'outcome': serializer.toJson<String>(outcome),
      'value': serializer.toJson<double?>(value),
      'note': serializer.toJson<String?>(note),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'source': serializer.toJson<String>(source),
    };
  }

  CommitmentEntryRow copyWith(
          {int? id,
          String? commitmentId,
          int? day,
          String? outcome,
          Value<double?> value = const Value.absent(),
          Value<String?> note = const Value.absent(),
          DateTime? recordedAt,
          String? source}) =>
      CommitmentEntryRow(
        id: id ?? this.id,
        commitmentId: commitmentId ?? this.commitmentId,
        day: day ?? this.day,
        outcome: outcome ?? this.outcome,
        value: value.present ? value.value : this.value,
        note: note.present ? note.value : this.note,
        recordedAt: recordedAt ?? this.recordedAt,
        source: source ?? this.source,
      );
  CommitmentEntryRow copyWithCompanion(CommitmentEntriesCompanion data) {
    return CommitmentEntryRow(
      id: data.id.present ? data.id.value : this.id,
      commitmentId: data.commitmentId.present
          ? data.commitmentId.value
          : this.commitmentId,
      day: data.day.present ? data.day.value : this.day,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentEntryRow(')
          ..write('id: $id, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('day: $day, ')
          ..write('outcome: $outcome, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, commitmentId, day, outcome, value, note, recordedAt, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommitmentEntryRow &&
          other.id == this.id &&
          other.commitmentId == this.commitmentId &&
          other.day == this.day &&
          other.outcome == this.outcome &&
          other.value == this.value &&
          other.note == this.note &&
          other.recordedAt == this.recordedAt &&
          other.source == this.source);
}

class CommitmentEntriesCompanion extends UpdateCompanion<CommitmentEntryRow> {
  final Value<int> id;
  final Value<String> commitmentId;
  final Value<int> day;
  final Value<String> outcome;
  final Value<double?> value;
  final Value<String?> note;
  final Value<DateTime> recordedAt;
  final Value<String> source;
  const CommitmentEntriesCompanion({
    this.id = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.day = const Value.absent(),
    this.outcome = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.source = const Value.absent(),
  });
  CommitmentEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String commitmentId,
    required int day,
    required String outcome,
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime recordedAt,
    this.source = const Value.absent(),
  })  : commitmentId = Value(commitmentId),
        day = Value(day),
        outcome = Value(outcome),
        recordedAt = Value(recordedAt);
  static Insertable<CommitmentEntryRow> custom({
    Expression<int>? id,
    Expression<String>? commitmentId,
    Expression<int>? day,
    Expression<String>? outcome,
    Expression<double>? value,
    Expression<String>? note,
    Expression<DateTime>? recordedAt,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commitmentId != null) 'commitment_id': commitmentId,
      if (day != null) 'day': day,
      if (outcome != null) 'outcome': outcome,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (source != null) 'source': source,
    });
  }

  CommitmentEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? commitmentId,
      Value<int>? day,
      Value<String>? outcome,
      Value<double?>? value,
      Value<String?>? note,
      Value<DateTime>? recordedAt,
      Value<String>? source}) {
    return CommitmentEntriesCompanion(
      id: id ?? this.id,
      commitmentId: commitmentId ?? this.commitmentId,
      day: day ?? this.day,
      outcome: outcome ?? this.outcome,
      value: value ?? this.value,
      note: note ?? this.note,
      recordedAt: recordedAt ?? this.recordedAt,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (commitmentId.present) {
      map['commitment_id'] = Variable<String>(commitmentId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentEntriesCompanion(')
          ..write('id: $id, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('day: $day, ')
          ..write('outcome: $outcome, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $CommitmentPausesTable extends CommitmentPauses
    with TableInfo<$CommitmentPausesTable, CommitmentPauseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommitmentPausesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _commitmentIdMeta =
      const VerificationMeta('commitmentId');
  @override
  late final GeneratedColumn<String> commitmentId = GeneratedColumn<String>(
      'commitment_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES commitment_rows (id) ON DELETE CASCADE'));
  static const VerificationMeta _fromDayMeta =
      const VerificationMeta('fromDay');
  @override
  late final GeneratedColumn<int> fromDay = GeneratedColumn<int>(
      'from_day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _toDayMeta = const VerificationMeta('toDay');
  @override
  late final GeneratedColumn<int> toDay = GeneratedColumn<int>(
      'to_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, commitmentId, fromDay, toDay, reason];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commitment_pauses';
  @override
  VerificationContext validateIntegrity(Insertable<CommitmentPauseRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('commitment_id')) {
      context.handle(
          _commitmentIdMeta,
          commitmentId.isAcceptableOrUnknown(
              data['commitment_id']!, _commitmentIdMeta));
    } else if (isInserting) {
      context.missing(_commitmentIdMeta);
    }
    if (data.containsKey('from_day')) {
      context.handle(_fromDayMeta,
          fromDay.isAcceptableOrUnknown(data['from_day']!, _fromDayMeta));
    } else if (isInserting) {
      context.missing(_fromDayMeta);
    }
    if (data.containsKey('to_day')) {
      context.handle(
          _toDayMeta, toDay.isAcceptableOrUnknown(data['to_day']!, _toDayMeta));
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommitmentPauseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommitmentPauseRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      commitmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}commitment_id'])!,
      fromDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}from_day'])!,
      toDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_day']),
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
    );
  }

  @override
  $CommitmentPausesTable createAlias(String alias) {
    return $CommitmentPausesTable(attachedDatabase, alias);
  }
}

class CommitmentPauseRow extends DataClass
    implements Insertable<CommitmentPauseRow> {
  final int id;
  final String commitmentId;
  final int fromDay;
  final int? toDay;
  final String? reason;
  const CommitmentPauseRow(
      {required this.id,
      required this.commitmentId,
      required this.fromDay,
      this.toDay,
      this.reason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['commitment_id'] = Variable<String>(commitmentId);
    map['from_day'] = Variable<int>(fromDay);
    if (!nullToAbsent || toDay != null) {
      map['to_day'] = Variable<int>(toDay);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  CommitmentPausesCompanion toCompanion(bool nullToAbsent) {
    return CommitmentPausesCompanion(
      id: Value(id),
      commitmentId: Value(commitmentId),
      fromDay: Value(fromDay),
      toDay:
          toDay == null && nullToAbsent ? const Value.absent() : Value(toDay),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
    );
  }

  factory CommitmentPauseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommitmentPauseRow(
      id: serializer.fromJson<int>(json['id']),
      commitmentId: serializer.fromJson<String>(json['commitmentId']),
      fromDay: serializer.fromJson<int>(json['fromDay']),
      toDay: serializer.fromJson<int?>(json['toDay']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'commitmentId': serializer.toJson<String>(commitmentId),
      'fromDay': serializer.toJson<int>(fromDay),
      'toDay': serializer.toJson<int?>(toDay),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  CommitmentPauseRow copyWith(
          {int? id,
          String? commitmentId,
          int? fromDay,
          Value<int?> toDay = const Value.absent(),
          Value<String?> reason = const Value.absent()}) =>
      CommitmentPauseRow(
        id: id ?? this.id,
        commitmentId: commitmentId ?? this.commitmentId,
        fromDay: fromDay ?? this.fromDay,
        toDay: toDay.present ? toDay.value : this.toDay,
        reason: reason.present ? reason.value : this.reason,
      );
  CommitmentPauseRow copyWithCompanion(CommitmentPausesCompanion data) {
    return CommitmentPauseRow(
      id: data.id.present ? data.id.value : this.id,
      commitmentId: data.commitmentId.present
          ? data.commitmentId.value
          : this.commitmentId,
      fromDay: data.fromDay.present ? data.fromDay.value : this.fromDay,
      toDay: data.toDay.present ? data.toDay.value : this.toDay,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentPauseRow(')
          ..write('id: $id, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('fromDay: $fromDay, ')
          ..write('toDay: $toDay, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, commitmentId, fromDay, toDay, reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommitmentPauseRow &&
          other.id == this.id &&
          other.commitmentId == this.commitmentId &&
          other.fromDay == this.fromDay &&
          other.toDay == this.toDay &&
          other.reason == this.reason);
}

class CommitmentPausesCompanion extends UpdateCompanion<CommitmentPauseRow> {
  final Value<int> id;
  final Value<String> commitmentId;
  final Value<int> fromDay;
  final Value<int?> toDay;
  final Value<String?> reason;
  const CommitmentPausesCompanion({
    this.id = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.fromDay = const Value.absent(),
    this.toDay = const Value.absent(),
    this.reason = const Value.absent(),
  });
  CommitmentPausesCompanion.insert({
    this.id = const Value.absent(),
    required String commitmentId,
    required int fromDay,
    this.toDay = const Value.absent(),
    this.reason = const Value.absent(),
  })  : commitmentId = Value(commitmentId),
        fromDay = Value(fromDay);
  static Insertable<CommitmentPauseRow> custom({
    Expression<int>? id,
    Expression<String>? commitmentId,
    Expression<int>? fromDay,
    Expression<int>? toDay,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commitmentId != null) 'commitment_id': commitmentId,
      if (fromDay != null) 'from_day': fromDay,
      if (toDay != null) 'to_day': toDay,
      if (reason != null) 'reason': reason,
    });
  }

  CommitmentPausesCompanion copyWith(
      {Value<int>? id,
      Value<String>? commitmentId,
      Value<int>? fromDay,
      Value<int?>? toDay,
      Value<String?>? reason}) {
    return CommitmentPausesCompanion(
      id: id ?? this.id,
      commitmentId: commitmentId ?? this.commitmentId,
      fromDay: fromDay ?? this.fromDay,
      toDay: toDay ?? this.toDay,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (commitmentId.present) {
      map['commitment_id'] = Variable<String>(commitmentId.value);
    }
    if (fromDay.present) {
      map['from_day'] = Variable<int>(fromDay.value);
    }
    if (toDay.present) {
      map['to_day'] = Variable<int>(toDay.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentPausesCompanion(')
          ..write('id: $id, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('fromDay: $fromDay, ')
          ..write('toDay: $toDay, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plannedMinutesMeta =
      const VerificationMeta('plannedMinutes');
  @override
  late final GeneratedColumn<int> plannedMinutes = GeneratedColumn<int>(
      'planned_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _goalLabelMeta =
      const VerificationMeta('goalLabel');
  @override
  late final GeneratedColumn<String> goalLabel = GeneratedColumn<String>(
      'goal_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commitmentIdMeta =
      const VerificationMeta('commitmentId');
  @override
  late final GeneratedColumn<String> commitmentId = GeneratedColumn<String>(
      'commitment_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES commitment_rows (id) ON DELETE SET NULL'));
  static const VerificationMeta _startedAtWallMsMeta =
      const VerificationMeta('startedAtWallMs');
  @override
  late final GeneratedColumn<int> startedAtWallMs = GeneratedColumn<int>(
      'started_at_wall_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startedAtRealtimeMsMeta =
      const VerificationMeta('startedAtRealtimeMs');
  @override
  late final GeneratedColumn<int> startedAtRealtimeMs = GeneratedColumn<int>(
      'started_at_realtime_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _segmentStartedAtRealtimeMsMeta =
      const VerificationMeta('segmentStartedAtRealtimeMs');
  @override
  late final GeneratedColumn<int> segmentStartedAtRealtimeMs =
      GeneratedColumn<int>('segment_started_at_realtime_ms', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _pausedAtWallMsMeta =
      const VerificationMeta('pausedAtWallMs');
  @override
  late final GeneratedColumn<int> pausedAtWallMs = GeneratedColumn<int>(
      'paused_at_wall_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _focusMsMeta =
      const VerificationMeta('focusMs');
  @override
  late final GeneratedColumn<int> focusMs = GeneratedColumn<int>(
      'focus_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _pausedMsMeta =
      const VerificationMeta('pausedMs');
  @override
  late final GeneratedColumn<int> pausedMs = GeneratedColumn<int>(
      'paused_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enforcementMeta =
      const VerificationMeta('enforcement');
  @override
  late final GeneratedColumn<String> enforcement = GeneratedColumn<String>(
      'enforcement', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endReasonMeta =
      const VerificationMeta('endReason');
  @override
  late final GeneratedColumn<String> endReason = GeneratedColumn<String>(
      'end_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _blockedAttemptsMeta =
      const VerificationMeta('blockedAttempts');
  @override
  late final GeneratedColumn<int> blockedAttempts = GeneratedColumn<int>(
      'blocked_attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _overlayShowsMeta =
      const VerificationMeta('overlayShows');
  @override
  late final GeneratedColumn<int> overlayShows = GeneratedColumn<int>(
      'overlay_shows', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _detectionEventsMeta =
      const VerificationMeta('detectionEvents');
  @override
  late final GeneratedColumn<int> detectionEvents = GeneratedColumn<int>(
      'detection_events', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timingVerifiedMeta =
      const VerificationMeta('timingVerified');
  @override
  late final GeneratedColumn<bool> timingVerified = GeneratedColumn<bool>(
      'timing_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("timing_verified" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _blockedPackagesJsonMeta =
      const VerificationMeta('blockedPackagesJson');
  @override
  late final GeneratedColumn<String> blockedPackagesJson =
      GeneratedColumn<String>('blocked_packages_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _endedAtWallMsMeta =
      const VerificationMeta('endedAtWallMs');
  @override
  late final GeneratedColumn<int> endedAtWallMs = GeneratedColumn<int>(
      'ended_at_wall_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reflectionMeta =
      const VerificationMeta('reflection');
  @override
  late final GeneratedColumn<String> reflection = GeneratedColumn<String>(
      'reflection', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mode,
        plannedMinutes,
        goalLabel,
        commitmentId,
        startedAtWallMs,
        startedAtRealtimeMs,
        segmentStartedAtRealtimeMs,
        pausedAtWallMs,
        focusMs,
        pausedMs,
        state,
        outcome,
        enforcement,
        endReason,
        blockedAttempts,
        overlayShows,
        detectionEvents,
        timingVerified,
        blockedPackagesJson,
        endedAtWallMs,
        reflection,
        day,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<FocusSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('planned_minutes')) {
      context.handle(
          _plannedMinutesMeta,
          plannedMinutes.isAcceptableOrUnknown(
              data['planned_minutes']!, _plannedMinutesMeta));
    } else if (isInserting) {
      context.missing(_plannedMinutesMeta);
    }
    if (data.containsKey('goal_label')) {
      context.handle(_goalLabelMeta,
          goalLabel.isAcceptableOrUnknown(data['goal_label']!, _goalLabelMeta));
    } else if (isInserting) {
      context.missing(_goalLabelMeta);
    }
    if (data.containsKey('commitment_id')) {
      context.handle(
          _commitmentIdMeta,
          commitmentId.isAcceptableOrUnknown(
              data['commitment_id']!, _commitmentIdMeta));
    }
    if (data.containsKey('started_at_wall_ms')) {
      context.handle(
          _startedAtWallMsMeta,
          startedAtWallMs.isAcceptableOrUnknown(
              data['started_at_wall_ms']!, _startedAtWallMsMeta));
    } else if (isInserting) {
      context.missing(_startedAtWallMsMeta);
    }
    if (data.containsKey('started_at_realtime_ms')) {
      context.handle(
          _startedAtRealtimeMsMeta,
          startedAtRealtimeMs.isAcceptableOrUnknown(
              data['started_at_realtime_ms']!, _startedAtRealtimeMsMeta));
    } else if (isInserting) {
      context.missing(_startedAtRealtimeMsMeta);
    }
    if (data.containsKey('segment_started_at_realtime_ms')) {
      context.handle(
          _segmentStartedAtRealtimeMsMeta,
          segmentStartedAtRealtimeMs.isAcceptableOrUnknown(
              data['segment_started_at_realtime_ms']!,
              _segmentStartedAtRealtimeMsMeta));
    }
    if (data.containsKey('paused_at_wall_ms')) {
      context.handle(
          _pausedAtWallMsMeta,
          pausedAtWallMs.isAcceptableOrUnknown(
              data['paused_at_wall_ms']!, _pausedAtWallMsMeta));
    }
    if (data.containsKey('focus_ms')) {
      context.handle(_focusMsMeta,
          focusMs.isAcceptableOrUnknown(data['focus_ms']!, _focusMsMeta));
    }
    if (data.containsKey('paused_ms')) {
      context.handle(_pausedMsMeta,
          pausedMs.isAcceptableOrUnknown(data['paused_ms']!, _pausedMsMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    }
    if (data.containsKey('enforcement')) {
      context.handle(
          _enforcementMeta,
          enforcement.isAcceptableOrUnknown(
              data['enforcement']!, _enforcementMeta));
    } else if (isInserting) {
      context.missing(_enforcementMeta);
    }
    if (data.containsKey('end_reason')) {
      context.handle(_endReasonMeta,
          endReason.isAcceptableOrUnknown(data['end_reason']!, _endReasonMeta));
    }
    if (data.containsKey('blocked_attempts')) {
      context.handle(
          _blockedAttemptsMeta,
          blockedAttempts.isAcceptableOrUnknown(
              data['blocked_attempts']!, _blockedAttemptsMeta));
    }
    if (data.containsKey('overlay_shows')) {
      context.handle(
          _overlayShowsMeta,
          overlayShows.isAcceptableOrUnknown(
              data['overlay_shows']!, _overlayShowsMeta));
    }
    if (data.containsKey('detection_events')) {
      context.handle(
          _detectionEventsMeta,
          detectionEvents.isAcceptableOrUnknown(
              data['detection_events']!, _detectionEventsMeta));
    }
    if (data.containsKey('timing_verified')) {
      context.handle(
          _timingVerifiedMeta,
          timingVerified.isAcceptableOrUnknown(
              data['timing_verified']!, _timingVerifiedMeta));
    }
    if (data.containsKey('blocked_packages_json')) {
      context.handle(
          _blockedPackagesJsonMeta,
          blockedPackagesJson.isAcceptableOrUnknown(
              data['blocked_packages_json']!, _blockedPackagesJsonMeta));
    }
    if (data.containsKey('ended_at_wall_ms')) {
      context.handle(
          _endedAtWallMsMeta,
          endedAtWallMs.isAcceptableOrUnknown(
              data['ended_at_wall_ms']!, _endedAtWallMsMeta));
    }
    if (data.containsKey('reflection')) {
      context.handle(
          _reflectionMeta,
          reflection.isAcceptableOrUnknown(
              data['reflection']!, _reflectionMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      plannedMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}planned_minutes'])!,
      goalLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_label'])!,
      commitmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}commitment_id']),
      startedAtWallMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}started_at_wall_ms'])!,
      startedAtRealtimeMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}started_at_realtime_ms'])!,
      segmentStartedAtRealtimeMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}segment_started_at_realtime_ms']),
      pausedAtWallMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paused_at_wall_ms']),
      focusMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}focus_ms'])!,
      pausedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paused_ms'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome']),
      enforcement: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}enforcement'])!,
      endReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_reason']),
      blockedAttempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}blocked_attempts'])!,
      overlayShows: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}overlay_shows'])!,
      detectionEvents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}detection_events'])!,
      timingVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}timing_verified'])!,
      blockedPackagesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}blocked_packages_json'])!,
      endedAtWallMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ended_at_wall_ms']),
      reflection: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reflection']),
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSessionRow extends DataClass implements Insertable<FocusSessionRow> {
  final String id;

  /// standard | blocking | deep
  final String mode;
  final int plannedMinutes;

  /// What the user said they were focusing on, in their words.
  final String goalLabel;

  /// The routine this was started from, when there was one. `SET NULL`, not
  /// cascade: deleting a routine must never delete time the user actually spent.
  final String? commitmentId;
  final int startedAtWallMs;
  final int startedAtRealtimeMs;

  /// Realtime clock when the current run segment began. Null while paused.
  final int? segmentStartedAtRealtimeMs;

  /// Wall clock when the current pause began, or null when running. A pause has to
  /// have a definite start: without it, a session paused and then killed by the OS
  /// could not tell a one-minute pause from an hour-long one.
  final int? pausedAtWallMs;

  /// Focus time banked before the current segment. Excludes paused time.
  final int focusMs;
  final int pausedMs;

  /// running | paused | ended
  final String state;

  /// completed | completedDegraded | interrupted | cancelled — null while live.
  final String? outcome;

  /// timerOnly | unavailable | armed | verified | lost
  final String enforcement;

  /// timer | userEnded | cancelled | serviceLost | deviceRestarted |
  /// permissionRevoked | appUpdated
  final String? endReason;
  final int blockedAttempts;
  final int overlayShows;

  /// Foreground-app events the monitor reported during this session. Zero on a
  /// device that refuses to report usage — the evidence behind "unconfirmed".
  final int detectionEvents;

  /// False when the session had to be timed with the wall clock.
  final bool timingVerified;

  /// JSON array of the package ids that were restricted. Package ids only: no
  /// usage times, no content, and nothing leaves the device.
  final String blockedPackagesJson;
  final int? endedAtWallMs;

  /// The user's own words about how it went. Optional, never prompted twice.
  final String? reflection;

  /// Local day key of the start, for the history and the streak maths.
  final int day;

  /// manual | import — symmetry with the other tables.
  final String source;
  const FocusSessionRow(
      {required this.id,
      required this.mode,
      required this.plannedMinutes,
      required this.goalLabel,
      this.commitmentId,
      required this.startedAtWallMs,
      required this.startedAtRealtimeMs,
      this.segmentStartedAtRealtimeMs,
      this.pausedAtWallMs,
      required this.focusMs,
      required this.pausedMs,
      required this.state,
      this.outcome,
      required this.enforcement,
      this.endReason,
      required this.blockedAttempts,
      required this.overlayShows,
      required this.detectionEvents,
      required this.timingVerified,
      required this.blockedPackagesJson,
      this.endedAtWallMs,
      this.reflection,
      required this.day,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mode'] = Variable<String>(mode);
    map['planned_minutes'] = Variable<int>(plannedMinutes);
    map['goal_label'] = Variable<String>(goalLabel);
    if (!nullToAbsent || commitmentId != null) {
      map['commitment_id'] = Variable<String>(commitmentId);
    }
    map['started_at_wall_ms'] = Variable<int>(startedAtWallMs);
    map['started_at_realtime_ms'] = Variable<int>(startedAtRealtimeMs);
    if (!nullToAbsent || segmentStartedAtRealtimeMs != null) {
      map['segment_started_at_realtime_ms'] =
          Variable<int>(segmentStartedAtRealtimeMs);
    }
    if (!nullToAbsent || pausedAtWallMs != null) {
      map['paused_at_wall_ms'] = Variable<int>(pausedAtWallMs);
    }
    map['focus_ms'] = Variable<int>(focusMs);
    map['paused_ms'] = Variable<int>(pausedMs);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    map['enforcement'] = Variable<String>(enforcement);
    if (!nullToAbsent || endReason != null) {
      map['end_reason'] = Variable<String>(endReason);
    }
    map['blocked_attempts'] = Variable<int>(blockedAttempts);
    map['overlay_shows'] = Variable<int>(overlayShows);
    map['detection_events'] = Variable<int>(detectionEvents);
    map['timing_verified'] = Variable<bool>(timingVerified);
    map['blocked_packages_json'] = Variable<String>(blockedPackagesJson);
    if (!nullToAbsent || endedAtWallMs != null) {
      map['ended_at_wall_ms'] = Variable<int>(endedAtWallMs);
    }
    if (!nullToAbsent || reflection != null) {
      map['reflection'] = Variable<String>(reflection);
    }
    map['day'] = Variable<int>(day);
    map['source'] = Variable<String>(source);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      mode: Value(mode),
      plannedMinutes: Value(plannedMinutes),
      goalLabel: Value(goalLabel),
      commitmentId: commitmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(commitmentId),
      startedAtWallMs: Value(startedAtWallMs),
      startedAtRealtimeMs: Value(startedAtRealtimeMs),
      segmentStartedAtRealtimeMs:
          segmentStartedAtRealtimeMs == null && nullToAbsent
              ? const Value.absent()
              : Value(segmentStartedAtRealtimeMs),
      pausedAtWallMs: pausedAtWallMs == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAtWallMs),
      focusMs: Value(focusMs),
      pausedMs: Value(pausedMs),
      state: Value(state),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      enforcement: Value(enforcement),
      endReason: endReason == null && nullToAbsent
          ? const Value.absent()
          : Value(endReason),
      blockedAttempts: Value(blockedAttempts),
      overlayShows: Value(overlayShows),
      detectionEvents: Value(detectionEvents),
      timingVerified: Value(timingVerified),
      blockedPackagesJson: Value(blockedPackagesJson),
      endedAtWallMs: endedAtWallMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtWallMs),
      reflection: reflection == null && nullToAbsent
          ? const Value.absent()
          : Value(reflection),
      day: Value(day),
      source: Value(source),
    );
  }

  factory FocusSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSessionRow(
      id: serializer.fromJson<String>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      plannedMinutes: serializer.fromJson<int>(json['plannedMinutes']),
      goalLabel: serializer.fromJson<String>(json['goalLabel']),
      commitmentId: serializer.fromJson<String?>(json['commitmentId']),
      startedAtWallMs: serializer.fromJson<int>(json['startedAtWallMs']),
      startedAtRealtimeMs:
          serializer.fromJson<int>(json['startedAtRealtimeMs']),
      segmentStartedAtRealtimeMs:
          serializer.fromJson<int?>(json['segmentStartedAtRealtimeMs']),
      pausedAtWallMs: serializer.fromJson<int?>(json['pausedAtWallMs']),
      focusMs: serializer.fromJson<int>(json['focusMs']),
      pausedMs: serializer.fromJson<int>(json['pausedMs']),
      state: serializer.fromJson<String>(json['state']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      enforcement: serializer.fromJson<String>(json['enforcement']),
      endReason: serializer.fromJson<String?>(json['endReason']),
      blockedAttempts: serializer.fromJson<int>(json['blockedAttempts']),
      overlayShows: serializer.fromJson<int>(json['overlayShows']),
      detectionEvents: serializer.fromJson<int>(json['detectionEvents']),
      timingVerified: serializer.fromJson<bool>(json['timingVerified']),
      blockedPackagesJson:
          serializer.fromJson<String>(json['blockedPackagesJson']),
      endedAtWallMs: serializer.fromJson<int?>(json['endedAtWallMs']),
      reflection: serializer.fromJson<String?>(json['reflection']),
      day: serializer.fromJson<int>(json['day']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mode': serializer.toJson<String>(mode),
      'plannedMinutes': serializer.toJson<int>(plannedMinutes),
      'goalLabel': serializer.toJson<String>(goalLabel),
      'commitmentId': serializer.toJson<String?>(commitmentId),
      'startedAtWallMs': serializer.toJson<int>(startedAtWallMs),
      'startedAtRealtimeMs': serializer.toJson<int>(startedAtRealtimeMs),
      'segmentStartedAtRealtimeMs':
          serializer.toJson<int?>(segmentStartedAtRealtimeMs),
      'pausedAtWallMs': serializer.toJson<int?>(pausedAtWallMs),
      'focusMs': serializer.toJson<int>(focusMs),
      'pausedMs': serializer.toJson<int>(pausedMs),
      'state': serializer.toJson<String>(state),
      'outcome': serializer.toJson<String?>(outcome),
      'enforcement': serializer.toJson<String>(enforcement),
      'endReason': serializer.toJson<String?>(endReason),
      'blockedAttempts': serializer.toJson<int>(blockedAttempts),
      'overlayShows': serializer.toJson<int>(overlayShows),
      'detectionEvents': serializer.toJson<int>(detectionEvents),
      'timingVerified': serializer.toJson<bool>(timingVerified),
      'blockedPackagesJson': serializer.toJson<String>(blockedPackagesJson),
      'endedAtWallMs': serializer.toJson<int?>(endedAtWallMs),
      'reflection': serializer.toJson<String?>(reflection),
      'day': serializer.toJson<int>(day),
      'source': serializer.toJson<String>(source),
    };
  }

  FocusSessionRow copyWith(
          {String? id,
          String? mode,
          int? plannedMinutes,
          String? goalLabel,
          Value<String?> commitmentId = const Value.absent(),
          int? startedAtWallMs,
          int? startedAtRealtimeMs,
          Value<int?> segmentStartedAtRealtimeMs = const Value.absent(),
          Value<int?> pausedAtWallMs = const Value.absent(),
          int? focusMs,
          int? pausedMs,
          String? state,
          Value<String?> outcome = const Value.absent(),
          String? enforcement,
          Value<String?> endReason = const Value.absent(),
          int? blockedAttempts,
          int? overlayShows,
          int? detectionEvents,
          bool? timingVerified,
          String? blockedPackagesJson,
          Value<int?> endedAtWallMs = const Value.absent(),
          Value<String?> reflection = const Value.absent(),
          int? day,
          String? source}) =>
      FocusSessionRow(
        id: id ?? this.id,
        mode: mode ?? this.mode,
        plannedMinutes: plannedMinutes ?? this.plannedMinutes,
        goalLabel: goalLabel ?? this.goalLabel,
        commitmentId:
            commitmentId.present ? commitmentId.value : this.commitmentId,
        startedAtWallMs: startedAtWallMs ?? this.startedAtWallMs,
        startedAtRealtimeMs: startedAtRealtimeMs ?? this.startedAtRealtimeMs,
        segmentStartedAtRealtimeMs: segmentStartedAtRealtimeMs.present
            ? segmentStartedAtRealtimeMs.value
            : this.segmentStartedAtRealtimeMs,
        pausedAtWallMs:
            pausedAtWallMs.present ? pausedAtWallMs.value : this.pausedAtWallMs,
        focusMs: focusMs ?? this.focusMs,
        pausedMs: pausedMs ?? this.pausedMs,
        state: state ?? this.state,
        outcome: outcome.present ? outcome.value : this.outcome,
        enforcement: enforcement ?? this.enforcement,
        endReason: endReason.present ? endReason.value : this.endReason,
        blockedAttempts: blockedAttempts ?? this.blockedAttempts,
        overlayShows: overlayShows ?? this.overlayShows,
        detectionEvents: detectionEvents ?? this.detectionEvents,
        timingVerified: timingVerified ?? this.timingVerified,
        blockedPackagesJson: blockedPackagesJson ?? this.blockedPackagesJson,
        endedAtWallMs:
            endedAtWallMs.present ? endedAtWallMs.value : this.endedAtWallMs,
        reflection: reflection.present ? reflection.value : this.reflection,
        day: day ?? this.day,
        source: source ?? this.source,
      );
  FocusSessionRow copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSessionRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      plannedMinutes: data.plannedMinutes.present
          ? data.plannedMinutes.value
          : this.plannedMinutes,
      goalLabel: data.goalLabel.present ? data.goalLabel.value : this.goalLabel,
      commitmentId: data.commitmentId.present
          ? data.commitmentId.value
          : this.commitmentId,
      startedAtWallMs: data.startedAtWallMs.present
          ? data.startedAtWallMs.value
          : this.startedAtWallMs,
      startedAtRealtimeMs: data.startedAtRealtimeMs.present
          ? data.startedAtRealtimeMs.value
          : this.startedAtRealtimeMs,
      segmentStartedAtRealtimeMs: data.segmentStartedAtRealtimeMs.present
          ? data.segmentStartedAtRealtimeMs.value
          : this.segmentStartedAtRealtimeMs,
      pausedAtWallMs: data.pausedAtWallMs.present
          ? data.pausedAtWallMs.value
          : this.pausedAtWallMs,
      focusMs: data.focusMs.present ? data.focusMs.value : this.focusMs,
      pausedMs: data.pausedMs.present ? data.pausedMs.value : this.pausedMs,
      state: data.state.present ? data.state.value : this.state,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      enforcement:
          data.enforcement.present ? data.enforcement.value : this.enforcement,
      endReason: data.endReason.present ? data.endReason.value : this.endReason,
      blockedAttempts: data.blockedAttempts.present
          ? data.blockedAttempts.value
          : this.blockedAttempts,
      overlayShows: data.overlayShows.present
          ? data.overlayShows.value
          : this.overlayShows,
      detectionEvents: data.detectionEvents.present
          ? data.detectionEvents.value
          : this.detectionEvents,
      timingVerified: data.timingVerified.present
          ? data.timingVerified.value
          : this.timingVerified,
      blockedPackagesJson: data.blockedPackagesJson.present
          ? data.blockedPackagesJson.value
          : this.blockedPackagesJson,
      endedAtWallMs: data.endedAtWallMs.present
          ? data.endedAtWallMs.value
          : this.endedAtWallMs,
      reflection:
          data.reflection.present ? data.reflection.value : this.reflection,
      day: data.day.present ? data.day.value : this.day,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('goalLabel: $goalLabel, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('startedAtWallMs: $startedAtWallMs, ')
          ..write('startedAtRealtimeMs: $startedAtRealtimeMs, ')
          ..write('segmentStartedAtRealtimeMs: $segmentStartedAtRealtimeMs, ')
          ..write('pausedAtWallMs: $pausedAtWallMs, ')
          ..write('focusMs: $focusMs, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('state: $state, ')
          ..write('outcome: $outcome, ')
          ..write('enforcement: $enforcement, ')
          ..write('endReason: $endReason, ')
          ..write('blockedAttempts: $blockedAttempts, ')
          ..write('overlayShows: $overlayShows, ')
          ..write('detectionEvents: $detectionEvents, ')
          ..write('timingVerified: $timingVerified, ')
          ..write('blockedPackagesJson: $blockedPackagesJson, ')
          ..write('endedAtWallMs: $endedAtWallMs, ')
          ..write('reflection: $reflection, ')
          ..write('day: $day, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        mode,
        plannedMinutes,
        goalLabel,
        commitmentId,
        startedAtWallMs,
        startedAtRealtimeMs,
        segmentStartedAtRealtimeMs,
        pausedAtWallMs,
        focusMs,
        pausedMs,
        state,
        outcome,
        enforcement,
        endReason,
        blockedAttempts,
        overlayShows,
        detectionEvents,
        timingVerified,
        blockedPackagesJson,
        endedAtWallMs,
        reflection,
        day,
        source
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSessionRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.plannedMinutes == this.plannedMinutes &&
          other.goalLabel == this.goalLabel &&
          other.commitmentId == this.commitmentId &&
          other.startedAtWallMs == this.startedAtWallMs &&
          other.startedAtRealtimeMs == this.startedAtRealtimeMs &&
          other.segmentStartedAtRealtimeMs == this.segmentStartedAtRealtimeMs &&
          other.pausedAtWallMs == this.pausedAtWallMs &&
          other.focusMs == this.focusMs &&
          other.pausedMs == this.pausedMs &&
          other.state == this.state &&
          other.outcome == this.outcome &&
          other.enforcement == this.enforcement &&
          other.endReason == this.endReason &&
          other.blockedAttempts == this.blockedAttempts &&
          other.overlayShows == this.overlayShows &&
          other.detectionEvents == this.detectionEvents &&
          other.timingVerified == this.timingVerified &&
          other.blockedPackagesJson == this.blockedPackagesJson &&
          other.endedAtWallMs == this.endedAtWallMs &&
          other.reflection == this.reflection &&
          other.day == this.day &&
          other.source == this.source);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSessionRow> {
  final Value<String> id;
  final Value<String> mode;
  final Value<int> plannedMinutes;
  final Value<String> goalLabel;
  final Value<String?> commitmentId;
  final Value<int> startedAtWallMs;
  final Value<int> startedAtRealtimeMs;
  final Value<int?> segmentStartedAtRealtimeMs;
  final Value<int?> pausedAtWallMs;
  final Value<int> focusMs;
  final Value<int> pausedMs;
  final Value<String> state;
  final Value<String?> outcome;
  final Value<String> enforcement;
  final Value<String?> endReason;
  final Value<int> blockedAttempts;
  final Value<int> overlayShows;
  final Value<int> detectionEvents;
  final Value<bool> timingVerified;
  final Value<String> blockedPackagesJson;
  final Value<int?> endedAtWallMs;
  final Value<String?> reflection;
  final Value<int> day;
  final Value<String> source;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.plannedMinutes = const Value.absent(),
    this.goalLabel = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.startedAtWallMs = const Value.absent(),
    this.startedAtRealtimeMs = const Value.absent(),
    this.segmentStartedAtRealtimeMs = const Value.absent(),
    this.pausedAtWallMs = const Value.absent(),
    this.focusMs = const Value.absent(),
    this.pausedMs = const Value.absent(),
    this.state = const Value.absent(),
    this.outcome = const Value.absent(),
    this.enforcement = const Value.absent(),
    this.endReason = const Value.absent(),
    this.blockedAttempts = const Value.absent(),
    this.overlayShows = const Value.absent(),
    this.detectionEvents = const Value.absent(),
    this.timingVerified = const Value.absent(),
    this.blockedPackagesJson = const Value.absent(),
    this.endedAtWallMs = const Value.absent(),
    this.reflection = const Value.absent(),
    this.day = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    required String mode,
    required int plannedMinutes,
    required String goalLabel,
    this.commitmentId = const Value.absent(),
    required int startedAtWallMs,
    required int startedAtRealtimeMs,
    this.segmentStartedAtRealtimeMs = const Value.absent(),
    this.pausedAtWallMs = const Value.absent(),
    this.focusMs = const Value.absent(),
    this.pausedMs = const Value.absent(),
    required String state,
    this.outcome = const Value.absent(),
    required String enforcement,
    this.endReason = const Value.absent(),
    this.blockedAttempts = const Value.absent(),
    this.overlayShows = const Value.absent(),
    this.detectionEvents = const Value.absent(),
    this.timingVerified = const Value.absent(),
    this.blockedPackagesJson = const Value.absent(),
    this.endedAtWallMs = const Value.absent(),
    this.reflection = const Value.absent(),
    required int day,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mode = Value(mode),
        plannedMinutes = Value(plannedMinutes),
        goalLabel = Value(goalLabel),
        startedAtWallMs = Value(startedAtWallMs),
        startedAtRealtimeMs = Value(startedAtRealtimeMs),
        state = Value(state),
        enforcement = Value(enforcement),
        day = Value(day);
  static Insertable<FocusSessionRow> custom({
    Expression<String>? id,
    Expression<String>? mode,
    Expression<int>? plannedMinutes,
    Expression<String>? goalLabel,
    Expression<String>? commitmentId,
    Expression<int>? startedAtWallMs,
    Expression<int>? startedAtRealtimeMs,
    Expression<int>? segmentStartedAtRealtimeMs,
    Expression<int>? pausedAtWallMs,
    Expression<int>? focusMs,
    Expression<int>? pausedMs,
    Expression<String>? state,
    Expression<String>? outcome,
    Expression<String>? enforcement,
    Expression<String>? endReason,
    Expression<int>? blockedAttempts,
    Expression<int>? overlayShows,
    Expression<int>? detectionEvents,
    Expression<bool>? timingVerified,
    Expression<String>? blockedPackagesJson,
    Expression<int>? endedAtWallMs,
    Expression<String>? reflection,
    Expression<int>? day,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (plannedMinutes != null) 'planned_minutes': plannedMinutes,
      if (goalLabel != null) 'goal_label': goalLabel,
      if (commitmentId != null) 'commitment_id': commitmentId,
      if (startedAtWallMs != null) 'started_at_wall_ms': startedAtWallMs,
      if (startedAtRealtimeMs != null)
        'started_at_realtime_ms': startedAtRealtimeMs,
      if (segmentStartedAtRealtimeMs != null)
        'segment_started_at_realtime_ms': segmentStartedAtRealtimeMs,
      if (pausedAtWallMs != null) 'paused_at_wall_ms': pausedAtWallMs,
      if (focusMs != null) 'focus_ms': focusMs,
      if (pausedMs != null) 'paused_ms': pausedMs,
      if (state != null) 'state': state,
      if (outcome != null) 'outcome': outcome,
      if (enforcement != null) 'enforcement': enforcement,
      if (endReason != null) 'end_reason': endReason,
      if (blockedAttempts != null) 'blocked_attempts': blockedAttempts,
      if (overlayShows != null) 'overlay_shows': overlayShows,
      if (detectionEvents != null) 'detection_events': detectionEvents,
      if (timingVerified != null) 'timing_verified': timingVerified,
      if (blockedPackagesJson != null)
        'blocked_packages_json': blockedPackagesJson,
      if (endedAtWallMs != null) 'ended_at_wall_ms': endedAtWallMs,
      if (reflection != null) 'reflection': reflection,
      if (day != null) 'day': day,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? mode,
      Value<int>? plannedMinutes,
      Value<String>? goalLabel,
      Value<String?>? commitmentId,
      Value<int>? startedAtWallMs,
      Value<int>? startedAtRealtimeMs,
      Value<int?>? segmentStartedAtRealtimeMs,
      Value<int?>? pausedAtWallMs,
      Value<int>? focusMs,
      Value<int>? pausedMs,
      Value<String>? state,
      Value<String?>? outcome,
      Value<String>? enforcement,
      Value<String?>? endReason,
      Value<int>? blockedAttempts,
      Value<int>? overlayShows,
      Value<int>? detectionEvents,
      Value<bool>? timingVerified,
      Value<String>? blockedPackagesJson,
      Value<int?>? endedAtWallMs,
      Value<String?>? reflection,
      Value<int>? day,
      Value<String>? source,
      Value<int>? rowid}) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      goalLabel: goalLabel ?? this.goalLabel,
      commitmentId: commitmentId ?? this.commitmentId,
      startedAtWallMs: startedAtWallMs ?? this.startedAtWallMs,
      startedAtRealtimeMs: startedAtRealtimeMs ?? this.startedAtRealtimeMs,
      segmentStartedAtRealtimeMs:
          segmentStartedAtRealtimeMs ?? this.segmentStartedAtRealtimeMs,
      pausedAtWallMs: pausedAtWallMs ?? this.pausedAtWallMs,
      focusMs: focusMs ?? this.focusMs,
      pausedMs: pausedMs ?? this.pausedMs,
      state: state ?? this.state,
      outcome: outcome ?? this.outcome,
      enforcement: enforcement ?? this.enforcement,
      endReason: endReason ?? this.endReason,
      blockedAttempts: blockedAttempts ?? this.blockedAttempts,
      overlayShows: overlayShows ?? this.overlayShows,
      detectionEvents: detectionEvents ?? this.detectionEvents,
      timingVerified: timingVerified ?? this.timingVerified,
      blockedPackagesJson: blockedPackagesJson ?? this.blockedPackagesJson,
      endedAtWallMs: endedAtWallMs ?? this.endedAtWallMs,
      reflection: reflection ?? this.reflection,
      day: day ?? this.day,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (plannedMinutes.present) {
      map['planned_minutes'] = Variable<int>(plannedMinutes.value);
    }
    if (goalLabel.present) {
      map['goal_label'] = Variable<String>(goalLabel.value);
    }
    if (commitmentId.present) {
      map['commitment_id'] = Variable<String>(commitmentId.value);
    }
    if (startedAtWallMs.present) {
      map['started_at_wall_ms'] = Variable<int>(startedAtWallMs.value);
    }
    if (startedAtRealtimeMs.present) {
      map['started_at_realtime_ms'] = Variable<int>(startedAtRealtimeMs.value);
    }
    if (segmentStartedAtRealtimeMs.present) {
      map['segment_started_at_realtime_ms'] =
          Variable<int>(segmentStartedAtRealtimeMs.value);
    }
    if (pausedAtWallMs.present) {
      map['paused_at_wall_ms'] = Variable<int>(pausedAtWallMs.value);
    }
    if (focusMs.present) {
      map['focus_ms'] = Variable<int>(focusMs.value);
    }
    if (pausedMs.present) {
      map['paused_ms'] = Variable<int>(pausedMs.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (enforcement.present) {
      map['enforcement'] = Variable<String>(enforcement.value);
    }
    if (endReason.present) {
      map['end_reason'] = Variable<String>(endReason.value);
    }
    if (blockedAttempts.present) {
      map['blocked_attempts'] = Variable<int>(blockedAttempts.value);
    }
    if (overlayShows.present) {
      map['overlay_shows'] = Variable<int>(overlayShows.value);
    }
    if (detectionEvents.present) {
      map['detection_events'] = Variable<int>(detectionEvents.value);
    }
    if (timingVerified.present) {
      map['timing_verified'] = Variable<bool>(timingVerified.value);
    }
    if (blockedPackagesJson.present) {
      map['blocked_packages_json'] =
          Variable<String>(blockedPackagesJson.value);
    }
    if (endedAtWallMs.present) {
      map['ended_at_wall_ms'] = Variable<int>(endedAtWallMs.value);
    }
    if (reflection.present) {
      map['reflection'] = Variable<String>(reflection.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('plannedMinutes: $plannedMinutes, ')
          ..write('goalLabel: $goalLabel, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('startedAtWallMs: $startedAtWallMs, ')
          ..write('startedAtRealtimeMs: $startedAtRealtimeMs, ')
          ..write('segmentStartedAtRealtimeMs: $segmentStartedAtRealtimeMs, ')
          ..write('pausedAtWallMs: $pausedAtWallMs, ')
          ..write('focusMs: $focusMs, ')
          ..write('pausedMs: $pausedMs, ')
          ..write('state: $state, ')
          ..write('outcome: $outcome, ')
          ..write('enforcement: $enforcement, ')
          ..write('endReason: $endReason, ')
          ..write('blockedAttempts: $blockedAttempts, ')
          ..write('overlayShows: $overlayShows, ')
          ..write('detectionEvents: $detectionEvents, ')
          ..write('timingVerified: $timingVerified, ')
          ..write('blockedPackagesJson: $blockedPackagesJson, ')
          ..write('endedAtWallMs: $endedAtWallMs, ')
          ..write('reflection: $reflection, ')
          ..write('day: $day, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusProfilesTable extends FocusProfiles
    with TableInfo<$FocusProfilesTable, FocusProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _minutesMeta =
      const VerificationMeta('minutes');
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
      'minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _commitmentIdMeta =
      const VerificationMeta('commitmentId');
  @override
  late final GeneratedColumn<String> commitmentId = GeneratedColumn<String>(
      'commitment_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES commitment_rows (id) ON DELETE SET NULL'));
  static const VerificationMeta _packagesJsonMeta =
      const VerificationMeta('packagesJson');
  @override
  late final GeneratedColumn<String> packagesJson = GeneratedColumn<String>(
      'packages_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
      'sort', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, mode, minutes, commitmentId, packagesJson, sort];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<FocusProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('minutes')) {
      context.handle(_minutesMeta,
          minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta));
    } else if (isInserting) {
      context.missing(_minutesMeta);
    }
    if (data.containsKey('commitment_id')) {
      context.handle(
          _commitmentIdMeta,
          commitmentId.isAcceptableOrUnknown(
              data['commitment_id']!, _commitmentIdMeta));
    }
    if (data.containsKey('packages_json')) {
      context.handle(
          _packagesJsonMeta,
          packagesJson.isAcceptableOrUnknown(
              data['packages_json']!, _packagesJsonMeta));
    }
    if (data.containsKey('sort')) {
      context.handle(
          _sortMeta, sort.isAcceptableOrUnknown(data['sort']!, _sortMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      minutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}minutes'])!,
      commitmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}commitment_id']),
      packagesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}packages_json'])!,
      sort: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort'])!,
    );
  }

  @override
  $FocusProfilesTable createAlias(String alias) {
    return $FocusProfilesTable(attachedDatabase, alias);
  }
}

class FocusProfileRow extends DataClass implements Insertable<FocusProfileRow> {
  final String id;
  final String name;
  final String mode;
  final int minutes;
  final String? commitmentId;
  final String packagesJson;
  final int sort;
  const FocusProfileRow(
      {required this.id,
      required this.name,
      required this.mode,
      required this.minutes,
      this.commitmentId,
      required this.packagesJson,
      required this.sort});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['mode'] = Variable<String>(mode);
    map['minutes'] = Variable<int>(minutes);
    if (!nullToAbsent || commitmentId != null) {
      map['commitment_id'] = Variable<String>(commitmentId);
    }
    map['packages_json'] = Variable<String>(packagesJson);
    map['sort'] = Variable<int>(sort);
    return map;
  }

  FocusProfilesCompanion toCompanion(bool nullToAbsent) {
    return FocusProfilesCompanion(
      id: Value(id),
      name: Value(name),
      mode: Value(mode),
      minutes: Value(minutes),
      commitmentId: commitmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(commitmentId),
      packagesJson: Value(packagesJson),
      sort: Value(sort),
    );
  }

  factory FocusProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      mode: serializer.fromJson<String>(json['mode']),
      minutes: serializer.fromJson<int>(json['minutes']),
      commitmentId: serializer.fromJson<String?>(json['commitmentId']),
      packagesJson: serializer.fromJson<String>(json['packagesJson']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'mode': serializer.toJson<String>(mode),
      'minutes': serializer.toJson<int>(minutes),
      'commitmentId': serializer.toJson<String?>(commitmentId),
      'packagesJson': serializer.toJson<String>(packagesJson),
      'sort': serializer.toJson<int>(sort),
    };
  }

  FocusProfileRow copyWith(
          {String? id,
          String? name,
          String? mode,
          int? minutes,
          Value<String?> commitmentId = const Value.absent(),
          String? packagesJson,
          int? sort}) =>
      FocusProfileRow(
        id: id ?? this.id,
        name: name ?? this.name,
        mode: mode ?? this.mode,
        minutes: minutes ?? this.minutes,
        commitmentId:
            commitmentId.present ? commitmentId.value : this.commitmentId,
        packagesJson: packagesJson ?? this.packagesJson,
        sort: sort ?? this.sort,
      );
  FocusProfileRow copyWithCompanion(FocusProfilesCompanion data) {
    return FocusProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mode: data.mode.present ? data.mode.value : this.mode,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      commitmentId: data.commitmentId.present
          ? data.commitmentId.value
          : this.commitmentId,
      packagesJson: data.packagesJson.present
          ? data.packagesJson.value
          : this.packagesJson,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('minutes: $minutes, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('packagesJson: $packagesJson, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, mode, minutes, commitmentId, packagesJson, sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.mode == this.mode &&
          other.minutes == this.minutes &&
          other.commitmentId == this.commitmentId &&
          other.packagesJson == this.packagesJson &&
          other.sort == this.sort);
}

class FocusProfilesCompanion extends UpdateCompanion<FocusProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> mode;
  final Value<int> minutes;
  final Value<String?> commitmentId;
  final Value<String> packagesJson;
  final Value<int> sort;
  final Value<int> rowid;
  const FocusProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mode = const Value.absent(),
    this.minutes = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.packagesJson = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusProfilesCompanion.insert({
    required String id,
    required String name,
    required String mode,
    required int minutes,
    this.commitmentId = const Value.absent(),
    this.packagesJson = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        mode = Value(mode),
        minutes = Value(minutes);
  static Insertable<FocusProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? mode,
    Expression<int>? minutes,
    Expression<String>? commitmentId,
    Expression<String>? packagesJson,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mode != null) 'mode': mode,
      if (minutes != null) 'minutes': minutes,
      if (commitmentId != null) 'commitment_id': commitmentId,
      if (packagesJson != null) 'packages_json': packagesJson,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? mode,
      Value<int>? minutes,
      Value<String?>? commitmentId,
      Value<String>? packagesJson,
      Value<int>? sort,
      Value<int>? rowid}) {
    return FocusProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      minutes: minutes ?? this.minutes,
      commitmentId: commitmentId ?? this.commitmentId,
      packagesJson: packagesJson ?? this.packagesJson,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (commitmentId.present) {
      map['commitment_id'] = Variable<String>(commitmentId.value);
    }
    if (packagesJson.present) {
      map['packages_json'] = Variable<String>(packagesJson.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mode: $mode, ')
          ..write('minutes: $minutes, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('packagesJson: $packagesJson, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSchedulesTable extends FocusSchedules
    with TableInfo<$FocusSchedulesTable, FocusScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _minutesMeta =
      const VerificationMeta('minutes');
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
      'minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
      'hour', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
      'minute', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _weekdaysJsonMeta =
      const VerificationMeta('weekdaysJson');
  @override
  late final GeneratedColumn<String> weekdaysJson = GeneratedColumn<String>(
      'weekdays_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _commitmentIdMeta =
      const VerificationMeta('commitmentId');
  @override
  late final GeneratedColumn<String> commitmentId = GeneratedColumn<String>(
      'commitment_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES commitment_rows (id) ON DELETE SET NULL'));
  static const VerificationMeta _packagesJsonMeta =
      const VerificationMeta('packagesJson');
  @override
  late final GeneratedColumn<String> packagesJson = GeneratedColumn<String>(
      'packages_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _notificationIdMeta =
      const VerificationMeta('notificationId');
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
      'notification_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mode,
        minutes,
        hour,
        minute,
        weekdaysJson,
        commitmentId,
        packagesJson,
        enabled,
        notificationId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_schedules';
  @override
  VerificationContext validateIntegrity(Insertable<FocusScheduleRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('minutes')) {
      context.handle(_minutesMeta,
          minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta));
    } else if (isInserting) {
      context.missing(_minutesMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
          _hourMeta, hour.isAcceptableOrUnknown(data['hour']!, _hourMeta));
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(_minuteMeta,
          minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta));
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('weekdays_json')) {
      context.handle(
          _weekdaysJsonMeta,
          weekdaysJson.isAcceptableOrUnknown(
              data['weekdays_json']!, _weekdaysJsonMeta));
    }
    if (data.containsKey('commitment_id')) {
      context.handle(
          _commitmentIdMeta,
          commitmentId.isAcceptableOrUnknown(
              data['commitment_id']!, _commitmentIdMeta));
    }
    if (data.containsKey('packages_json')) {
      context.handle(
          _packagesJsonMeta,
          packagesJson.isAcceptableOrUnknown(
              data['packages_json']!, _packagesJsonMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('notification_id')) {
      context.handle(
          _notificationIdMeta,
          notificationId.isAcceptableOrUnknown(
              data['notification_id']!, _notificationIdMeta));
    } else if (isInserting) {
      context.missing(_notificationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusScheduleRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      minutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}minutes'])!,
      hour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hour'])!,
      minute: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}minute'])!,
      weekdaysJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weekdays_json'])!,
      commitmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}commitment_id']),
      packagesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}packages_json'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      notificationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}notification_id'])!,
    );
  }

  @override
  $FocusSchedulesTable createAlias(String alias) {
    return $FocusSchedulesTable(attachedDatabase, alias);
  }
}

class FocusScheduleRow extends DataClass
    implements Insertable<FocusScheduleRow> {
  final String id;
  final String mode;
  final int minutes;
  final int hour;
  final int minute;

  /// ISO weekdays as a JSON array; empty means every day.
  final String weekdaysJson;
  final String? commitmentId;
  final String packagesJson;
  final bool enabled;

  /// The id handed to `NotificationService`, stored so a schedule can always
  /// cancel exactly what it scheduled — including after a reinstall of the app's
  /// settings, which is why it is not derived on the fly.
  final int notificationId;
  const FocusScheduleRow(
      {required this.id,
      required this.mode,
      required this.minutes,
      required this.hour,
      required this.minute,
      required this.weekdaysJson,
      this.commitmentId,
      required this.packagesJson,
      required this.enabled,
      required this.notificationId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mode'] = Variable<String>(mode);
    map['minutes'] = Variable<int>(minutes);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['weekdays_json'] = Variable<String>(weekdaysJson);
    if (!nullToAbsent || commitmentId != null) {
      map['commitment_id'] = Variable<String>(commitmentId);
    }
    map['packages_json'] = Variable<String>(packagesJson);
    map['enabled'] = Variable<bool>(enabled);
    map['notification_id'] = Variable<int>(notificationId);
    return map;
  }

  FocusSchedulesCompanion toCompanion(bool nullToAbsent) {
    return FocusSchedulesCompanion(
      id: Value(id),
      mode: Value(mode),
      minutes: Value(minutes),
      hour: Value(hour),
      minute: Value(minute),
      weekdaysJson: Value(weekdaysJson),
      commitmentId: commitmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(commitmentId),
      packagesJson: Value(packagesJson),
      enabled: Value(enabled),
      notificationId: Value(notificationId),
    );
  }

  factory FocusScheduleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      minutes: serializer.fromJson<int>(json['minutes']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      weekdaysJson: serializer.fromJson<String>(json['weekdaysJson']),
      commitmentId: serializer.fromJson<String?>(json['commitmentId']),
      packagesJson: serializer.fromJson<String>(json['packagesJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notificationId: serializer.fromJson<int>(json['notificationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mode': serializer.toJson<String>(mode),
      'minutes': serializer.toJson<int>(minutes),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'weekdaysJson': serializer.toJson<String>(weekdaysJson),
      'commitmentId': serializer.toJson<String?>(commitmentId),
      'packagesJson': serializer.toJson<String>(packagesJson),
      'enabled': serializer.toJson<bool>(enabled),
      'notificationId': serializer.toJson<int>(notificationId),
    };
  }

  FocusScheduleRow copyWith(
          {String? id,
          String? mode,
          int? minutes,
          int? hour,
          int? minute,
          String? weekdaysJson,
          Value<String?> commitmentId = const Value.absent(),
          String? packagesJson,
          bool? enabled,
          int? notificationId}) =>
      FocusScheduleRow(
        id: id ?? this.id,
        mode: mode ?? this.mode,
        minutes: minutes ?? this.minutes,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdaysJson: weekdaysJson ?? this.weekdaysJson,
        commitmentId:
            commitmentId.present ? commitmentId.value : this.commitmentId,
        packagesJson: packagesJson ?? this.packagesJson,
        enabled: enabled ?? this.enabled,
        notificationId: notificationId ?? this.notificationId,
      );
  FocusScheduleRow copyWithCompanion(FocusSchedulesCompanion data) {
    return FocusScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      weekdaysJson: data.weekdaysJson.present
          ? data.weekdaysJson.value
          : this.weekdaysJson,
      commitmentId: data.commitmentId.present
          ? data.commitmentId.value
          : this.commitmentId,
      packagesJson: data.packagesJson.present
          ? data.packagesJson.value
          : this.packagesJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusScheduleRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('minutes: $minutes, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('weekdaysJson: $weekdaysJson, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('packagesJson: $packagesJson, ')
          ..write('enabled: $enabled, ')
          ..write('notificationId: $notificationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mode, minutes, hour, minute, weekdaysJson,
      commitmentId, packagesJson, enabled, notificationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusScheduleRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.minutes == this.minutes &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.weekdaysJson == this.weekdaysJson &&
          other.commitmentId == this.commitmentId &&
          other.packagesJson == this.packagesJson &&
          other.enabled == this.enabled &&
          other.notificationId == this.notificationId);
}

class FocusSchedulesCompanion extends UpdateCompanion<FocusScheduleRow> {
  final Value<String> id;
  final Value<String> mode;
  final Value<int> minutes;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> weekdaysJson;
  final Value<String?> commitmentId;
  final Value<String> packagesJson;
  final Value<bool> enabled;
  final Value<int> notificationId;
  final Value<int> rowid;
  const FocusSchedulesCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.minutes = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.weekdaysJson = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.packagesJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSchedulesCompanion.insert({
    required String id,
    required String mode,
    required int minutes,
    required int hour,
    required int minute,
    this.weekdaysJson = const Value.absent(),
    this.commitmentId = const Value.absent(),
    this.packagesJson = const Value.absent(),
    this.enabled = const Value.absent(),
    required int notificationId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mode = Value(mode),
        minutes = Value(minutes),
        hour = Value(hour),
        minute = Value(minute),
        notificationId = Value(notificationId);
  static Insertable<FocusScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? mode,
    Expression<int>? minutes,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<String>? weekdaysJson,
    Expression<String>? commitmentId,
    Expression<String>? packagesJson,
    Expression<bool>? enabled,
    Expression<int>? notificationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (minutes != null) 'minutes': minutes,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (weekdaysJson != null) 'weekdays_json': weekdaysJson,
      if (commitmentId != null) 'commitment_id': commitmentId,
      if (packagesJson != null) 'packages_json': packagesJson,
      if (enabled != null) 'enabled': enabled,
      if (notificationId != null) 'notification_id': notificationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSchedulesCompanion copyWith(
      {Value<String>? id,
      Value<String>? mode,
      Value<int>? minutes,
      Value<int>? hour,
      Value<int>? minute,
      Value<String>? weekdaysJson,
      Value<String?>? commitmentId,
      Value<String>? packagesJson,
      Value<bool>? enabled,
      Value<int>? notificationId,
      Value<int>? rowid}) {
    return FocusSchedulesCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      minutes: minutes ?? this.minutes,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdaysJson: weekdaysJson ?? this.weekdaysJson,
      commitmentId: commitmentId ?? this.commitmentId,
      packagesJson: packagesJson ?? this.packagesJson,
      enabled: enabled ?? this.enabled,
      notificationId: notificationId ?? this.notificationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (weekdaysJson.present) {
      map['weekdays_json'] = Variable<String>(weekdaysJson.value);
    }
    if (commitmentId.present) {
      map['commitment_id'] = Variable<String>(commitmentId.value);
    }
    if (packagesJson.present) {
      map['packages_json'] = Variable<String>(packagesJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('minutes: $minutes, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('weekdaysJson: $weekdaysJson, ')
          ..write('commitmentId: $commitmentId, ')
          ..write('packagesJson: $packagesJson, ')
          ..write('enabled: $enabled, ')
          ..write('notificationId: $notificationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TrackDatabase extends GeneratedDatabase {
  _$TrackDatabase(QueryExecutor e) : super(e);
  $TrackDatabaseManager get managers => $TrackDatabaseManager(this);
  late final $TrackerRowsTable trackerRows = $TrackerRowsTable(this);
  late final $DailyEntriesTable dailyEntries = $DailyEntriesTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $PurchasesTable purchases = $PurchasesTable(this);
  late final $TrackEventsTable trackEvents = $TrackEventsTable(this);
  late final $CommitmentRowsTable commitmentRows = $CommitmentRowsTable(this);
  late final $CommitmentEntriesTable commitmentEntries =
      $CommitmentEntriesTable(this);
  late final $CommitmentPausesTable commitmentPauses =
      $CommitmentPausesTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $FocusProfilesTable focusProfiles = $FocusProfilesTable(this);
  late final $FocusSchedulesTable focusSchedules = $FocusSchedulesTable(this);
  late final TrackDao trackDao = TrackDao(this as TrackDatabase);
  late final CommitmentDao commitmentDao = CommitmentDao(this as TrackDatabase);
  late final FocusDao focusDao = FocusDao(this as TrackDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        trackerRows,
        dailyEntries,
        events,
        appSettings,
        purchases,
        trackEvents,
        commitmentRows,
        commitmentEntries,
        commitmentPauses,
        focusSessions,
        focusProfiles,
        focusSchedules
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracker_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('daily_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracker_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('events', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('commitment_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('commitment_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('commitment_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('commitment_pauses', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('commitment_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('focus_sessions', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('commitment_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('focus_profiles', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('commitment_rows',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('focus_schedules', kind: UpdateKind.update),
            ],
          ),
        ],
      );
}

typedef $$TrackerRowsTableCreateCompanionBuilder = TrackerRowsCompanion
    Function({
  required String id,
  required String name,
  required String emoji,
  required String kind,
  required String unit,
  required String blurb,
  required String insight,
  required int accent,
  required int accent2,
  required double goal,
  required double step,
  Value<bool> hero,
  Value<bool> hidden,
  Value<int> sort,
  Value<int> rowid,
});
typedef $$TrackerRowsTableUpdateCompanionBuilder = TrackerRowsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> emoji,
  Value<String> kind,
  Value<String> unit,
  Value<String> blurb,
  Value<String> insight,
  Value<int> accent,
  Value<int> accent2,
  Value<double> goal,
  Value<double> step,
  Value<bool> hero,
  Value<bool> hidden,
  Value<int> sort,
  Value<int> rowid,
});

final class $$TrackerRowsTableReferences
    extends BaseReferences<_$TrackDatabase, $TrackerRowsTable, TrackerRow> {
  $$TrackerRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DailyEntriesTable, List<DailyEntry>>
      _dailyEntriesRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.dailyEntries,
              aliasName: 'tracker_rows__id__daily_entries__tracker_id');

  $$DailyEntriesTableProcessedTableManager get dailyEntriesRefs {
    final manager = $$DailyEntriesTableTableManager($_db, $_db.dailyEntries)
        .filter((f) => f.trackerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dailyEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$EventsTable, List<EventRow>> _eventsRefsTable(
          _$TrackDatabase db) =>
      MultiTypedResultKey.fromTable(db.events,
          aliasName: 'tracker_rows__id__events__tracker_id');

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager($_db, $_db.events)
        .filter((f) => f.trackerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TrackerRowsTableFilterComposer
    extends Composer<_$TrackDatabase, $TrackerRowsTable> {
  $$TrackerRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blurb => $composableBuilder(
      column: $table.blurb, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get insight => $composableBuilder(
      column: $table.insight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accent => $composableBuilder(
      column: $table.accent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accent2 => $composableBuilder(
      column: $table.accent2, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get goal => $composableBuilder(
      column: $table.goal, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get step => $composableBuilder(
      column: $table.step, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hero => $composableBuilder(
      column: $table.hero, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnFilters(column));

  Expression<bool> dailyEntriesRefs(
      Expression<bool> Function($$DailyEntriesTableFilterComposer f) f) {
    final $$DailyEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dailyEntries,
        getReferencedColumn: (t) => t.trackerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DailyEntriesTableFilterComposer(
              $db: $db,
              $table: $db.dailyEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> eventsRefs(
      Expression<bool> Function($$EventsTableFilterComposer f) f) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.events,
        getReferencedColumn: (t) => t.trackerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EventsTableFilterComposer(
              $db: $db,
              $table: $db.events,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TrackerRowsTableOrderingComposer
    extends Composer<_$TrackDatabase, $TrackerRowsTable> {
  $$TrackerRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blurb => $composableBuilder(
      column: $table.blurb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get insight => $composableBuilder(
      column: $table.insight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accent => $composableBuilder(
      column: $table.accent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accent2 => $composableBuilder(
      column: $table.accent2, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get goal => $composableBuilder(
      column: $table.goal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get step => $composableBuilder(
      column: $table.step, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hero => $composableBuilder(
      column: $table.hero, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnOrderings(column));
}

class $$TrackerRowsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $TrackerRowsTable> {
  $$TrackerRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get blurb =>
      $composableBuilder(column: $table.blurb, builder: (column) => column);

  GeneratedColumn<String> get insight =>
      $composableBuilder(column: $table.insight, builder: (column) => column);

  GeneratedColumn<int> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<int> get accent2 =>
      $composableBuilder(column: $table.accent2, builder: (column) => column);

  GeneratedColumn<double> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<double> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<bool> get hero =>
      $composableBuilder(column: $table.hero, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  Expression<T> dailyEntriesRefs<T extends Object>(
      Expression<T> Function($$DailyEntriesTableAnnotationComposer a) f) {
    final $$DailyEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dailyEntries,
        getReferencedColumn: (t) => t.trackerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DailyEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.dailyEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> eventsRefs<T extends Object>(
      Expression<T> Function($$EventsTableAnnotationComposer a) f) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.events,
        getReferencedColumn: (t) => t.trackerId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EventsTableAnnotationComposer(
              $db: $db,
              $table: $db.events,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TrackerRowsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $TrackerRowsTable,
    TrackerRow,
    $$TrackerRowsTableFilterComposer,
    $$TrackerRowsTableOrderingComposer,
    $$TrackerRowsTableAnnotationComposer,
    $$TrackerRowsTableCreateCompanionBuilder,
    $$TrackerRowsTableUpdateCompanionBuilder,
    (TrackerRow, $$TrackerRowsTableReferences),
    TrackerRow,
    PrefetchHooks Function({bool dailyEntriesRefs, bool eventsRefs})> {
  $$TrackerRowsTableTableManager(_$TrackDatabase db, $TrackerRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackerRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackerRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackerRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<String> blurb = const Value.absent(),
            Value<String> insight = const Value.absent(),
            Value<int> accent = const Value.absent(),
            Value<int> accent2 = const Value.absent(),
            Value<double> goal = const Value.absent(),
            Value<double> step = const Value.absent(),
            Value<bool> hero = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackerRowsCompanion(
            id: id,
            name: name,
            emoji: emoji,
            kind: kind,
            unit: unit,
            blurb: blurb,
            insight: insight,
            accent: accent,
            accent2: accent2,
            goal: goal,
            step: step,
            hero: hero,
            hidden: hidden,
            sort: sort,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String emoji,
            required String kind,
            required String unit,
            required String blurb,
            required String insight,
            required int accent,
            required int accent2,
            required double goal,
            required double step,
            Value<bool> hero = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackerRowsCompanion.insert(
            id: id,
            name: name,
            emoji: emoji,
            kind: kind,
            unit: unit,
            blurb: blurb,
            insight: insight,
            accent: accent,
            accent2: accent2,
            goal: goal,
            step: step,
            hero: hero,
            hidden: hidden,
            sort: sort,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TrackerRowsTable, TrackerRow>(table),
                    $$TrackerRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {dailyEntriesRefs = false, eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (dailyEntriesRefs) db.dailyEntries,
                if (eventsRefs) db.events
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dailyEntriesRefs)
                    await $_getPrefetchedData<TrackerRow, $TrackerRowsTable,
                            DailyEntry>(
                        currentTable: table,
                        referencedTable: $$TrackerRowsTableReferences
                            ._dailyEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TrackerRowsTableReferences(db, table, p0)
                                .dailyEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.trackerId == item.id),
                        typedResults: items),
                  if (eventsRefs)
                    await $_getPrefetchedData<TrackerRow, $TrackerRowsTable,
                            EventRow>(
                        currentTable: table,
                        referencedTable:
                            $$TrackerRowsTableReferences._eventsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TrackerRowsTableReferences(db, table, p0)
                                .eventsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.trackerId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TrackerRowsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $TrackerRowsTable,
    TrackerRow,
    $$TrackerRowsTableFilterComposer,
    $$TrackerRowsTableOrderingComposer,
    $$TrackerRowsTableAnnotationComposer,
    $$TrackerRowsTableCreateCompanionBuilder,
    $$TrackerRowsTableUpdateCompanionBuilder,
    (TrackerRow, $$TrackerRowsTableReferences),
    TrackerRow,
    PrefetchHooks Function({bool dailyEntriesRefs, bool eventsRefs})>;
typedef $$DailyEntriesTableCreateCompanionBuilder = DailyEntriesCompanion
    Function({
  Value<int> id,
  required String trackerId,
  required int day,
  required DateTime updatedAt,
  required double value,
  Value<String> source,
  Value<String?> meta,
});
typedef $$DailyEntriesTableUpdateCompanionBuilder = DailyEntriesCompanion
    Function({
  Value<int> id,
  Value<String> trackerId,
  Value<int> day,
  Value<DateTime> updatedAt,
  Value<double> value,
  Value<String> source,
  Value<String?> meta,
});

final class $$DailyEntriesTableReferences
    extends BaseReferences<_$TrackDatabase, $DailyEntriesTable, DailyEntry> {
  $$DailyEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackerRowsTable _trackerIdTable(_$TrackDatabase db) =>
      db.trackerRows.createAlias('daily_entries__tracker_id__tracker_rows__id');

  $$TrackerRowsTableProcessedTableManager get trackerId {
    final $_column = $_itemColumn<String>('tracker_id')!;

    final manager = $$TrackerRowsTableTableManager($_db, $_db.trackerRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DailyEntriesTableFilterComposer
    extends Composer<_$TrackDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnFilters(column));

  $$TrackerRowsTableFilterComposer get trackerId {
    final $$TrackerRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableFilterComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DailyEntriesTableOrderingComposer
    extends Composer<_$TrackDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnOrderings(column));

  $$TrackerRowsTableOrderingComposer get trackerId {
    final $$TrackerRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableOrderingComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DailyEntriesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  $$TrackerRowsTableAnnotationComposer get trackerId {
    final $$TrackerRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DailyEntriesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $DailyEntriesTable,
    DailyEntry,
    $$DailyEntriesTableFilterComposer,
    $$DailyEntriesTableOrderingComposer,
    $$DailyEntriesTableAnnotationComposer,
    $$DailyEntriesTableCreateCompanionBuilder,
    $$DailyEntriesTableUpdateCompanionBuilder,
    (DailyEntry, $$DailyEntriesTableReferences),
    DailyEntry,
    PrefetchHooks Function({bool trackerId})> {
  $$DailyEntriesTableTableManager(_$TrackDatabase db, $DailyEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> trackerId = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> meta = const Value.absent(),
          }) =>
              DailyEntriesCompanion(
            id: id,
            trackerId: trackerId,
            day: day,
            updatedAt: updatedAt,
            value: value,
            source: source,
            meta: meta,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String trackerId,
            required int day,
            required DateTime updatedAt,
            required double value,
            Value<String> source = const Value.absent(),
            Value<String?> meta = const Value.absent(),
          }) =>
              DailyEntriesCompanion.insert(
            id: id,
            trackerId: trackerId,
            day: day,
            updatedAt: updatedAt,
            value: value,
            source: source,
            meta: meta,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DailyEntriesTable, DailyEntry>(table),
                    $$DailyEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackerId,
                    referencedTable:
                        $$DailyEntriesTableReferences._trackerIdTable(db),
                    referencedColumn:
                        $$DailyEntriesTableReferences._trackerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DailyEntriesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $DailyEntriesTable,
    DailyEntry,
    $$DailyEntriesTableFilterComposer,
    $$DailyEntriesTableOrderingComposer,
    $$DailyEntriesTableAnnotationComposer,
    $$DailyEntriesTableCreateCompanionBuilder,
    $$DailyEntriesTableUpdateCompanionBuilder,
    (DailyEntry, $$DailyEntriesTableReferences),
    DailyEntry,
    PrefetchHooks Function({bool trackerId})>;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  required String trackerId,
  required DateTime ts,
  required int day,
  required double value,
  Value<String> source,
  Value<String?> meta,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  Value<String> trackerId,
  Value<DateTime> ts,
  Value<int> day,
  Value<double> value,
  Value<String> source,
  Value<String?> meta,
});

final class $$EventsTableReferences
    extends BaseReferences<_$TrackDatabase, $EventsTable, EventRow> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackerRowsTable _trackerIdTable(_$TrackDatabase db) =>
      db.trackerRows.createAlias('events__tracker_id__tracker_rows__id');

  $$TrackerRowsTableProcessedTableManager get trackerId {
    final $_column = $_itemColumn<String>('tracker_id')!;

    final manager = $$TrackerRowsTableTableManager($_db, $_db.trackerRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$TrackDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnFilters(column));

  $$TrackerRowsTableFilterComposer get trackerId {
    final $$TrackerRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableFilterComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$TrackDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnOrderings(column));

  $$TrackerRowsTableOrderingComposer get trackerId {
    final $$TrackerRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableOrderingComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EventsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  $$TrackerRowsTableAnnotationComposer get trackerId {
    final $$TrackerRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackerId,
        referencedTable: $db.trackerRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TrackerRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.trackerRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EventsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $EventsTable,
    EventRow,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (EventRow, $$EventsTableReferences),
    EventRow,
    PrefetchHooks Function({bool trackerId})> {
  $$EventsTableTableManager(_$TrackDatabase db, $EventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> trackerId = const Value.absent(),
            Value<DateTime> ts = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> meta = const Value.absent(),
          }) =>
              EventsCompanion(
            id: id,
            trackerId: trackerId,
            ts: ts,
            day: day,
            value: value,
            source: source,
            meta: meta,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String trackerId,
            required DateTime ts,
            required int day,
            required double value,
            Value<String> source = const Value.absent(),
            Value<String?> meta = const Value.absent(),
          }) =>
              EventsCompanion.insert(
            id: id,
            trackerId: trackerId,
            ts: ts,
            day: day,
            value: value,
            source: source,
            meta: meta,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$EventsTable, EventRow>(table),
                    $$EventsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackerId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackerId,
                    referencedTable:
                        $$EventsTableReferences._trackerIdTable(db),
                    referencedColumn:
                        $$EventsTableReferences._trackerIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$EventsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $EventsTable,
    EventRow,
    $$EventsTableFilterComposer,
    $$EventsTableOrderingComposer,
    $$EventsTableAnnotationComposer,
    $$EventsTableCreateCompanionBuilder,
    $$EventsTableUpdateCompanionBuilder,
    (EventRow, $$EventsTableReferences),
    EventRow,
    PrefetchHooks Function({bool trackerId})>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$TrackDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$TrackDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $AppSettingsTable,
    AppSettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingRow,
      BaseReferences<_$TrackDatabase, $AppSettingsTable, AppSettingRow>
    ),
    AppSettingRow,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$TrackDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppSettingsTable, AppSettingRow>(table),
                    BaseReferences<_$TrackDatabase, $AppSettingsTable,
                        AppSettingRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $AppSettingsTable,
    AppSettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingRow,
      BaseReferences<_$TrackDatabase, $AppSettingsTable, AppSettingRow>
    ),
    AppSettingRow,
    PrefetchHooks Function()>;
typedef $$PurchasesTableCreateCompanionBuilder = PurchasesCompanion Function({
  Value<int> id,
  required String productId,
  required String purchaseToken,
  required String status,
  required DateTime purchasedAt,
  Value<DateTime?> expiresAt,
  Value<bool> autoRenew,
  Value<bool> acknowledged,
  Value<bool> serverVerified,
  Value<bool> trial,
  Value<String?> raw,
});
typedef $$PurchasesTableUpdateCompanionBuilder = PurchasesCompanion Function({
  Value<int> id,
  Value<String> productId,
  Value<String> purchaseToken,
  Value<String> status,
  Value<DateTime> purchasedAt,
  Value<DateTime?> expiresAt,
  Value<bool> autoRenew,
  Value<bool> acknowledged,
  Value<bool> serverVerified,
  Value<bool> trial,
  Value<String?> raw,
});

class $$PurchasesTableFilterComposer
    extends Composer<_$TrackDatabase, $PurchasesTable> {
  $$PurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseToken => $composableBuilder(
      column: $table.purchaseToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoRenew => $composableBuilder(
      column: $table.autoRenew, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get acknowledged => $composableBuilder(
      column: $table.acknowledged, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get serverVerified => $composableBuilder(
      column: $table.serverVerified,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trial => $composableBuilder(
      column: $table.trial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnFilters(column));
}

class $$PurchasesTableOrderingComposer
    extends Composer<_$TrackDatabase, $PurchasesTable> {
  $$PurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseToken => $composableBuilder(
      column: $table.purchaseToken,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoRenew => $composableBuilder(
      column: $table.autoRenew, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get acknowledged => $composableBuilder(
      column: $table.acknowledged,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get serverVerified => $composableBuilder(
      column: $table.serverVerified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trial => $composableBuilder(
      column: $table.trial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get raw => $composableBuilder(
      column: $table.raw, builder: (column) => ColumnOrderings(column));
}

class $$PurchasesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $PurchasesTable> {
  $$PurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get purchaseToken => $composableBuilder(
      column: $table.purchaseToken, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<bool> get autoRenew =>
      $composableBuilder(column: $table.autoRenew, builder: (column) => column);

  GeneratedColumn<bool> get acknowledged => $composableBuilder(
      column: $table.acknowledged, builder: (column) => column);

  GeneratedColumn<bool> get serverVerified => $composableBuilder(
      column: $table.serverVerified, builder: (column) => column);

  GeneratedColumn<bool> get trial =>
      $composableBuilder(column: $table.trial, builder: (column) => column);

  GeneratedColumn<String> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);
}

class $$PurchasesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $PurchasesTable,
    PurchaseRow,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (
      PurchaseRow,
      BaseReferences<_$TrackDatabase, $PurchasesTable, PurchaseRow>
    ),
    PurchaseRow,
    PrefetchHooks Function()> {
  $$PurchasesTableTableManager(_$TrackDatabase db, $PurchasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> purchaseToken = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> purchasedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<bool> autoRenew = const Value.absent(),
            Value<bool> acknowledged = const Value.absent(),
            Value<bool> serverVerified = const Value.absent(),
            Value<bool> trial = const Value.absent(),
            Value<String?> raw = const Value.absent(),
          }) =>
              PurchasesCompanion(
            id: id,
            productId: productId,
            purchaseToken: purchaseToken,
            status: status,
            purchasedAt: purchasedAt,
            expiresAt: expiresAt,
            autoRenew: autoRenew,
            acknowledged: acknowledged,
            serverVerified: serverVerified,
            trial: trial,
            raw: raw,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String productId,
            required String purchaseToken,
            required String status,
            required DateTime purchasedAt,
            Value<DateTime?> expiresAt = const Value.absent(),
            Value<bool> autoRenew = const Value.absent(),
            Value<bool> acknowledged = const Value.absent(),
            Value<bool> serverVerified = const Value.absent(),
            Value<bool> trial = const Value.absent(),
            Value<String?> raw = const Value.absent(),
          }) =>
              PurchasesCompanion.insert(
            id: id,
            productId: productId,
            purchaseToken: purchaseToken,
            status: status,
            purchasedAt: purchasedAt,
            expiresAt: expiresAt,
            autoRenew: autoRenew,
            acknowledged: acknowledged,
            serverVerified: serverVerified,
            trial: trial,
            raw: raw,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PurchasesTable, PurchaseRow>(table),
                    BaseReferences<_$TrackDatabase, $PurchasesTable,
                        PurchaseRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchasesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $PurchasesTable,
    PurchaseRow,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (
      PurchaseRow,
      BaseReferences<_$TrackDatabase, $PurchasesTable, PurchaseRow>
    ),
    PurchaseRow,
    PrefetchHooks Function()>;
typedef $$TrackEventsTableCreateCompanionBuilder = TrackEventsCompanion
    Function({
  Value<int> id,
  required String name,
  required DateTime at,
  Value<String?> meta,
});
typedef $$TrackEventsTableUpdateCompanionBuilder = TrackEventsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> at,
  Value<String?> meta,
});

class $$TrackEventsTableFilterComposer
    extends Composer<_$TrackDatabase, $TrackEventsTable> {
  $$TrackEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnFilters(column));
}

class $$TrackEventsTableOrderingComposer
    extends Composer<_$TrackDatabase, $TrackEventsTable> {
  $$TrackEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta => $composableBuilder(
      column: $table.meta, builder: (column) => ColumnOrderings(column));
}

class $$TrackEventsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $TrackEventsTable> {
  $$TrackEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);
}

class $$TrackEventsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $TrackEventsTable,
    TrackEventRow,
    $$TrackEventsTableFilterComposer,
    $$TrackEventsTableOrderingComposer,
    $$TrackEventsTableAnnotationComposer,
    $$TrackEventsTableCreateCompanionBuilder,
    $$TrackEventsTableUpdateCompanionBuilder,
    (
      TrackEventRow,
      BaseReferences<_$TrackDatabase, $TrackEventsTable, TrackEventRow>
    ),
    TrackEventRow,
    PrefetchHooks Function()> {
  $$TrackEventsTableTableManager(_$TrackDatabase db, $TrackEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<String?> meta = const Value.absent(),
          }) =>
              TrackEventsCompanion(
            id: id,
            name: name,
            at: at,
            meta: meta,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required DateTime at,
            Value<String?> meta = const Value.absent(),
          }) =>
              TrackEventsCompanion.insert(
            id: id,
            name: name,
            at: at,
            meta: meta,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TrackEventsTable, TrackEventRow>(table),
                    BaseReferences<_$TrackDatabase, $TrackEventsTable,
                        TrackEventRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrackEventsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $TrackEventsTable,
    TrackEventRow,
    $$TrackEventsTableFilterComposer,
    $$TrackEventsTableOrderingComposer,
    $$TrackEventsTableAnnotationComposer,
    $$TrackEventsTableCreateCompanionBuilder,
    $$TrackEventsTableUpdateCompanionBuilder,
    (
      TrackEventRow,
      BaseReferences<_$TrackDatabase, $TrackEventsTable, TrackEventRow>
    ),
    TrackEventRow,
    PrefetchHooks Function()>;
typedef $$CommitmentRowsTableCreateCompanionBuilder = CommitmentRowsCompanion
    Function({
  required String id,
  required String name,
  required String emoji,
  required int color,
  required String outcome,
  required String minimumAction,
  required String fullAction,
  required String scheduleJson,
  required int createdDay,
  Value<bool> archived,
  Value<int?> archivedDay,
  Value<int> sort,
  Value<int> rowid,
});
typedef $$CommitmentRowsTableUpdateCompanionBuilder = CommitmentRowsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> emoji,
  Value<int> color,
  Value<String> outcome,
  Value<String> minimumAction,
  Value<String> fullAction,
  Value<String> scheduleJson,
  Value<int> createdDay,
  Value<bool> archived,
  Value<int?> archivedDay,
  Value<int> sort,
  Value<int> rowid,
});

final class $$CommitmentRowsTableReferences extends BaseReferences<
    _$TrackDatabase, $CommitmentRowsTable, CommitmentRow> {
  $$CommitmentRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CommitmentEntriesTable, List<CommitmentEntryRow>>
      _commitmentEntriesRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.commitmentEntries,
              aliasName:
                  'commitment_rows__id__commitment_entries__commitment_id');

  $$CommitmentEntriesTableProcessedTableManager get commitmentEntriesRefs {
    final manager = $$CommitmentEntriesTableTableManager(
            $_db, $_db.commitmentEntries)
        .filter(
            (f) => f.commitmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_commitmentEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CommitmentPausesTable, List<CommitmentPauseRow>>
      _commitmentPausesRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.commitmentPauses,
              aliasName:
                  'commitment_rows__id__commitment_pauses__commitment_id');

  $$CommitmentPausesTableProcessedTableManager get commitmentPausesRefs {
    final manager =
        $$CommitmentPausesTableTableManager($_db, $_db.commitmentPauses).filter(
            (f) => f.commitmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_commitmentPausesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FocusSessionsTable, List<FocusSessionRow>>
      _focusSessionsRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.focusSessions,
              aliasName: 'commitment_rows__id__focus_sessions__commitment_id');

  $$FocusSessionsTableProcessedTableManager get focusSessionsRefs {
    final manager = $$FocusSessionsTableTableManager($_db, $_db.focusSessions)
        .filter(
            (f) => f.commitmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_focusSessionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FocusProfilesTable, List<FocusProfileRow>>
      _focusProfilesRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.focusProfiles,
              aliasName: 'commitment_rows__id__focus_profiles__commitment_id');

  $$FocusProfilesTableProcessedTableManager get focusProfilesRefs {
    final manager = $$FocusProfilesTableTableManager($_db, $_db.focusProfiles)
        .filter(
            (f) => f.commitmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_focusProfilesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FocusSchedulesTable, List<FocusScheduleRow>>
      _focusSchedulesRefsTable(_$TrackDatabase db) =>
          MultiTypedResultKey.fromTable(db.focusSchedules,
              aliasName: 'commitment_rows__id__focus_schedules__commitment_id');

  $$FocusSchedulesTableProcessedTableManager get focusSchedulesRefs {
    final manager = $$FocusSchedulesTableTableManager($_db, $_db.focusSchedules)
        .filter(
            (f) => f.commitmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_focusSchedulesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CommitmentRowsTableFilterComposer
    extends Composer<_$TrackDatabase, $CommitmentRowsTable> {
  $$CommitmentRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get minimumAction => $composableBuilder(
      column: $table.minimumAction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fullAction => $composableBuilder(
      column: $table.fullAction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduleJson => $composableBuilder(
      column: $table.scheduleJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdDay => $composableBuilder(
      column: $table.createdDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get archivedDay => $composableBuilder(
      column: $table.archivedDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnFilters(column));

  Expression<bool> commitmentEntriesRefs(
      Expression<bool> Function($$CommitmentEntriesTableFilterComposer f) f) {
    final $$CommitmentEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.commitmentEntries,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentEntriesTableFilterComposer(
              $db: $db,
              $table: $db.commitmentEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> commitmentPausesRefs(
      Expression<bool> Function($$CommitmentPausesTableFilterComposer f) f) {
    final $$CommitmentPausesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.commitmentPauses,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentPausesTableFilterComposer(
              $db: $db,
              $table: $db.commitmentPauses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> focusSessionsRefs(
      Expression<bool> Function($$FocusSessionsTableFilterComposer f) f) {
    final $$FocusSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusSessions,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusSessionsTableFilterComposer(
              $db: $db,
              $table: $db.focusSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> focusProfilesRefs(
      Expression<bool> Function($$FocusProfilesTableFilterComposer f) f) {
    final $$FocusProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusProfiles,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusProfilesTableFilterComposer(
              $db: $db,
              $table: $db.focusProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> focusSchedulesRefs(
      Expression<bool> Function($$FocusSchedulesTableFilterComposer f) f) {
    final $$FocusSchedulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusSchedules,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusSchedulesTableFilterComposer(
              $db: $db,
              $table: $db.focusSchedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CommitmentRowsTableOrderingComposer
    extends Composer<_$TrackDatabase, $CommitmentRowsTable> {
  $$CommitmentRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get emoji => $composableBuilder(
      column: $table.emoji, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get minimumAction => $composableBuilder(
      column: $table.minimumAction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fullAction => $composableBuilder(
      column: $table.fullAction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduleJson => $composableBuilder(
      column: $table.scheduleJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdDay => $composableBuilder(
      column: $table.createdDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get archivedDay => $composableBuilder(
      column: $table.archivedDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnOrderings(column));
}

class $$CommitmentRowsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $CommitmentRowsTable> {
  $$CommitmentRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get minimumAction => $composableBuilder(
      column: $table.minimumAction, builder: (column) => column);

  GeneratedColumn<String> get fullAction => $composableBuilder(
      column: $table.fullAction, builder: (column) => column);

  GeneratedColumn<String> get scheduleJson => $composableBuilder(
      column: $table.scheduleJson, builder: (column) => column);

  GeneratedColumn<int> get createdDay => $composableBuilder(
      column: $table.createdDay, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get archivedDay => $composableBuilder(
      column: $table.archivedDay, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  Expression<T> commitmentEntriesRefs<T extends Object>(
      Expression<T> Function($$CommitmentEntriesTableAnnotationComposer a) f) {
    final $$CommitmentEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.commitmentEntries,
            getReferencedColumn: (t) => t.commitmentId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$CommitmentEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.commitmentEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> commitmentPausesRefs<T extends Object>(
      Expression<T> Function($$CommitmentPausesTableAnnotationComposer a) f) {
    final $$CommitmentPausesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.commitmentPauses,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentPausesTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentPauses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> focusSessionsRefs<T extends Object>(
      Expression<T> Function($$FocusSessionsTableAnnotationComposer a) f) {
    final $$FocusSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusSessions,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.focusSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> focusProfilesRefs<T extends Object>(
      Expression<T> Function($$FocusProfilesTableAnnotationComposer a) f) {
    final $$FocusProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusProfiles,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.focusProfiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> focusSchedulesRefs<T extends Object>(
      Expression<T> Function($$FocusSchedulesTableAnnotationComposer a) f) {
    final $$FocusSchedulesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.focusSchedules,
        getReferencedColumn: (t) => t.commitmentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FocusSchedulesTableAnnotationComposer(
              $db: $db,
              $table: $db.focusSchedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CommitmentRowsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $CommitmentRowsTable,
    CommitmentRow,
    $$CommitmentRowsTableFilterComposer,
    $$CommitmentRowsTableOrderingComposer,
    $$CommitmentRowsTableAnnotationComposer,
    $$CommitmentRowsTableCreateCompanionBuilder,
    $$CommitmentRowsTableUpdateCompanionBuilder,
    (CommitmentRow, $$CommitmentRowsTableReferences),
    CommitmentRow,
    PrefetchHooks Function(
        {bool commitmentEntriesRefs,
        bool commitmentPausesRefs,
        bool focusSessionsRefs,
        bool focusProfilesRefs,
        bool focusSchedulesRefs})> {
  $$CommitmentRowsTableTableManager(
      _$TrackDatabase db, $CommitmentRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommitmentRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommitmentRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommitmentRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> emoji = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<String> minimumAction = const Value.absent(),
            Value<String> fullAction = const Value.absent(),
            Value<String> scheduleJson = const Value.absent(),
            Value<int> createdDay = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int?> archivedDay = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CommitmentRowsCompanion(
            id: id,
            name: name,
            emoji: emoji,
            color: color,
            outcome: outcome,
            minimumAction: minimumAction,
            fullAction: fullAction,
            scheduleJson: scheduleJson,
            createdDay: createdDay,
            archived: archived,
            archivedDay: archivedDay,
            sort: sort,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String emoji,
            required int color,
            required String outcome,
            required String minimumAction,
            required String fullAction,
            required String scheduleJson,
            required int createdDay,
            Value<bool> archived = const Value.absent(),
            Value<int?> archivedDay = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CommitmentRowsCompanion.insert(
            id: id,
            name: name,
            emoji: emoji,
            color: color,
            outcome: outcome,
            minimumAction: minimumAction,
            fullAction: fullAction,
            scheduleJson: scheduleJson,
            createdDay: createdDay,
            archived: archived,
            archivedDay: archivedDay,
            sort: sort,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CommitmentRowsTable, CommitmentRow>(table),
                    $$CommitmentRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {commitmentEntriesRefs = false,
              commitmentPausesRefs = false,
              focusSessionsRefs = false,
              focusProfilesRefs = false,
              focusSchedulesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (commitmentEntriesRefs) db.commitmentEntries,
                if (commitmentPausesRefs) db.commitmentPauses,
                if (focusSessionsRefs) db.focusSessions,
                if (focusProfilesRefs) db.focusProfiles,
                if (focusSchedulesRefs) db.focusSchedules
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (commitmentEntriesRefs)
                    await $_getPrefetchedData<CommitmentRow,
                            $CommitmentRowsTable, CommitmentEntryRow>(
                        currentTable: table,
                        referencedTable: $$CommitmentRowsTableReferences
                            ._commitmentEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CommitmentRowsTableReferences(db, table, p0)
                                .commitmentEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.commitmentId == item.id),
                        typedResults: items),
                  if (commitmentPausesRefs)
                    await $_getPrefetchedData<CommitmentRow,
                            $CommitmentRowsTable, CommitmentPauseRow>(
                        currentTable: table,
                        referencedTable: $$CommitmentRowsTableReferences
                            ._commitmentPausesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CommitmentRowsTableReferences(db, table, p0)
                                .commitmentPausesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.commitmentId == item.id),
                        typedResults: items),
                  if (focusSessionsRefs)
                    await $_getPrefetchedData<CommitmentRow,
                            $CommitmentRowsTable, FocusSessionRow>(
                        currentTable: table,
                        referencedTable: $$CommitmentRowsTableReferences
                            ._focusSessionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CommitmentRowsTableReferences(db, table, p0)
                                .focusSessionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.commitmentId == item.id),
                        typedResults: items),
                  if (focusProfilesRefs)
                    await $_getPrefetchedData<CommitmentRow,
                            $CommitmentRowsTable, FocusProfileRow>(
                        currentTable: table,
                        referencedTable: $$CommitmentRowsTableReferences
                            ._focusProfilesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CommitmentRowsTableReferences(db, table, p0)
                                .focusProfilesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.commitmentId == item.id),
                        typedResults: items),
                  if (focusSchedulesRefs)
                    await $_getPrefetchedData<CommitmentRow,
                            $CommitmentRowsTable, FocusScheduleRow>(
                        currentTable: table,
                        referencedTable: $$CommitmentRowsTableReferences
                            ._focusSchedulesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CommitmentRowsTableReferences(db, table, p0)
                                .focusSchedulesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.commitmentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CommitmentRowsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $CommitmentRowsTable,
    CommitmentRow,
    $$CommitmentRowsTableFilterComposer,
    $$CommitmentRowsTableOrderingComposer,
    $$CommitmentRowsTableAnnotationComposer,
    $$CommitmentRowsTableCreateCompanionBuilder,
    $$CommitmentRowsTableUpdateCompanionBuilder,
    (CommitmentRow, $$CommitmentRowsTableReferences),
    CommitmentRow,
    PrefetchHooks Function(
        {bool commitmentEntriesRefs,
        bool commitmentPausesRefs,
        bool focusSessionsRefs,
        bool focusProfilesRefs,
        bool focusSchedulesRefs})>;
typedef $$CommitmentEntriesTableCreateCompanionBuilder
    = CommitmentEntriesCompanion Function({
  Value<int> id,
  required String commitmentId,
  required int day,
  required String outcome,
  Value<double?> value,
  Value<String?> note,
  required DateTime recordedAt,
  Value<String> source,
});
typedef $$CommitmentEntriesTableUpdateCompanionBuilder
    = CommitmentEntriesCompanion Function({
  Value<int> id,
  Value<String> commitmentId,
  Value<int> day,
  Value<String> outcome,
  Value<double?> value,
  Value<String?> note,
  Value<DateTime> recordedAt,
  Value<String> source,
});

final class $$CommitmentEntriesTableReferences extends BaseReferences<
    _$TrackDatabase, $CommitmentEntriesTable, CommitmentEntryRow> {
  $$CommitmentEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentRowsTable _commitmentIdTable(_$TrackDatabase db) => db
      .commitmentRows
      .createAlias('commitment_entries__commitment_id__commitment_rows__id');

  $$CommitmentRowsTableProcessedTableManager get commitmentId {
    final $_column = $_itemColumn<String>('commitment_id')!;

    final manager = $$CommitmentRowsTableTableManager($_db, $_db.commitmentRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CommitmentEntriesTableFilterComposer
    extends Composer<_$TrackDatabase, $CommitmentEntriesTable> {
  $$CommitmentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  $$CommitmentRowsTableFilterComposer get commitmentId {
    final $$CommitmentRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableFilterComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentEntriesTableOrderingComposer
    extends Composer<_$TrackDatabase, $CommitmentEntriesTable> {
  $$CommitmentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  $$CommitmentRowsTableOrderingComposer get commitmentId {
    final $$CommitmentRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableOrderingComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentEntriesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $CommitmentEntriesTable> {
  $$CommitmentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$CommitmentRowsTableAnnotationComposer get commitmentId {
    final $$CommitmentRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentEntriesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $CommitmentEntriesTable,
    CommitmentEntryRow,
    $$CommitmentEntriesTableFilterComposer,
    $$CommitmentEntriesTableOrderingComposer,
    $$CommitmentEntriesTableAnnotationComposer,
    $$CommitmentEntriesTableCreateCompanionBuilder,
    $$CommitmentEntriesTableUpdateCompanionBuilder,
    (CommitmentEntryRow, $$CommitmentEntriesTableReferences),
    CommitmentEntryRow,
    PrefetchHooks Function({bool commitmentId})> {
  $$CommitmentEntriesTableTableManager(
      _$TrackDatabase db, $CommitmentEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommitmentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommitmentEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommitmentEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> commitmentId = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<double?> value = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<String> source = const Value.absent(),
          }) =>
              CommitmentEntriesCompanion(
            id: id,
            commitmentId: commitmentId,
            day: day,
            outcome: outcome,
            value: value,
            note: note,
            recordedAt: recordedAt,
            source: source,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String commitmentId,
            required int day,
            required String outcome,
            Value<double?> value = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime recordedAt,
            Value<String> source = const Value.absent(),
          }) =>
              CommitmentEntriesCompanion.insert(
            id: id,
            commitmentId: commitmentId,
            day: day,
            outcome: outcome,
            value: value,
            note: note,
            recordedAt: recordedAt,
            source: source,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CommitmentEntriesTable, CommitmentEntryRow>(
                        table),
                    $$CommitmentEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({commitmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (commitmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.commitmentId,
                    referencedTable: $$CommitmentEntriesTableReferences
                        ._commitmentIdTable(db),
                    referencedColumn: $$CommitmentEntriesTableReferences
                        ._commitmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CommitmentEntriesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $CommitmentEntriesTable,
    CommitmentEntryRow,
    $$CommitmentEntriesTableFilterComposer,
    $$CommitmentEntriesTableOrderingComposer,
    $$CommitmentEntriesTableAnnotationComposer,
    $$CommitmentEntriesTableCreateCompanionBuilder,
    $$CommitmentEntriesTableUpdateCompanionBuilder,
    (CommitmentEntryRow, $$CommitmentEntriesTableReferences),
    CommitmentEntryRow,
    PrefetchHooks Function({bool commitmentId})>;
typedef $$CommitmentPausesTableCreateCompanionBuilder
    = CommitmentPausesCompanion Function({
  Value<int> id,
  required String commitmentId,
  required int fromDay,
  Value<int?> toDay,
  Value<String?> reason,
});
typedef $$CommitmentPausesTableUpdateCompanionBuilder
    = CommitmentPausesCompanion Function({
  Value<int> id,
  Value<String> commitmentId,
  Value<int> fromDay,
  Value<int?> toDay,
  Value<String?> reason,
});

final class $$CommitmentPausesTableReferences extends BaseReferences<
    _$TrackDatabase, $CommitmentPausesTable, CommitmentPauseRow> {
  $$CommitmentPausesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentRowsTable _commitmentIdTable(_$TrackDatabase db) =>
      db.commitmentRows
          .createAlias('commitment_pauses__commitment_id__commitment_rows__id');

  $$CommitmentRowsTableProcessedTableManager get commitmentId {
    final $_column = $_itemColumn<String>('commitment_id')!;

    final manager = $$CommitmentRowsTableTableManager($_db, $_db.commitmentRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CommitmentPausesTableFilterComposer
    extends Composer<_$TrackDatabase, $CommitmentPausesTable> {
  $$CommitmentPausesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fromDay => $composableBuilder(
      column: $table.fromDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toDay => $composableBuilder(
      column: $table.toDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  $$CommitmentRowsTableFilterComposer get commitmentId {
    final $$CommitmentRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableFilterComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentPausesTableOrderingComposer
    extends Composer<_$TrackDatabase, $CommitmentPausesTable> {
  $$CommitmentPausesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fromDay => $composableBuilder(
      column: $table.fromDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toDay => $composableBuilder(
      column: $table.toDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  $$CommitmentRowsTableOrderingComposer get commitmentId {
    final $$CommitmentRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableOrderingComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentPausesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $CommitmentPausesTable> {
  $$CommitmentPausesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get fromDay =>
      $composableBuilder(column: $table.fromDay, builder: (column) => column);

  GeneratedColumn<int> get toDay =>
      $composableBuilder(column: $table.toDay, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  $$CommitmentRowsTableAnnotationComposer get commitmentId {
    final $$CommitmentRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommitmentPausesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $CommitmentPausesTable,
    CommitmentPauseRow,
    $$CommitmentPausesTableFilterComposer,
    $$CommitmentPausesTableOrderingComposer,
    $$CommitmentPausesTableAnnotationComposer,
    $$CommitmentPausesTableCreateCompanionBuilder,
    $$CommitmentPausesTableUpdateCompanionBuilder,
    (CommitmentPauseRow, $$CommitmentPausesTableReferences),
    CommitmentPauseRow,
    PrefetchHooks Function({bool commitmentId})> {
  $$CommitmentPausesTableTableManager(
      _$TrackDatabase db, $CommitmentPausesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommitmentPausesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommitmentPausesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommitmentPausesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> commitmentId = const Value.absent(),
            Value<int> fromDay = const Value.absent(),
            Value<int?> toDay = const Value.absent(),
            Value<String?> reason = const Value.absent(),
          }) =>
              CommitmentPausesCompanion(
            id: id,
            commitmentId: commitmentId,
            fromDay: fromDay,
            toDay: toDay,
            reason: reason,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String commitmentId,
            required int fromDay,
            Value<int?> toDay = const Value.absent(),
            Value<String?> reason = const Value.absent(),
          }) =>
              CommitmentPausesCompanion.insert(
            id: id,
            commitmentId: commitmentId,
            fromDay: fromDay,
            toDay: toDay,
            reason: reason,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CommitmentPausesTable, CommitmentPauseRow>(
                        table),
                    $$CommitmentPausesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({commitmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (commitmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.commitmentId,
                    referencedTable: $$CommitmentPausesTableReferences
                        ._commitmentIdTable(db),
                    referencedColumn: $$CommitmentPausesTableReferences
                        ._commitmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CommitmentPausesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $CommitmentPausesTable,
    CommitmentPauseRow,
    $$CommitmentPausesTableFilterComposer,
    $$CommitmentPausesTableOrderingComposer,
    $$CommitmentPausesTableAnnotationComposer,
    $$CommitmentPausesTableCreateCompanionBuilder,
    $$CommitmentPausesTableUpdateCompanionBuilder,
    (CommitmentPauseRow, $$CommitmentPausesTableReferences),
    CommitmentPauseRow,
    PrefetchHooks Function({bool commitmentId})>;
typedef $$FocusSessionsTableCreateCompanionBuilder = FocusSessionsCompanion
    Function({
  required String id,
  required String mode,
  required int plannedMinutes,
  required String goalLabel,
  Value<String?> commitmentId,
  required int startedAtWallMs,
  required int startedAtRealtimeMs,
  Value<int?> segmentStartedAtRealtimeMs,
  Value<int?> pausedAtWallMs,
  Value<int> focusMs,
  Value<int> pausedMs,
  required String state,
  Value<String?> outcome,
  required String enforcement,
  Value<String?> endReason,
  Value<int> blockedAttempts,
  Value<int> overlayShows,
  Value<int> detectionEvents,
  Value<bool> timingVerified,
  Value<String> blockedPackagesJson,
  Value<int?> endedAtWallMs,
  Value<String?> reflection,
  required int day,
  Value<String> source,
  Value<int> rowid,
});
typedef $$FocusSessionsTableUpdateCompanionBuilder = FocusSessionsCompanion
    Function({
  Value<String> id,
  Value<String> mode,
  Value<int> plannedMinutes,
  Value<String> goalLabel,
  Value<String?> commitmentId,
  Value<int> startedAtWallMs,
  Value<int> startedAtRealtimeMs,
  Value<int?> segmentStartedAtRealtimeMs,
  Value<int?> pausedAtWallMs,
  Value<int> focusMs,
  Value<int> pausedMs,
  Value<String> state,
  Value<String?> outcome,
  Value<String> enforcement,
  Value<String?> endReason,
  Value<int> blockedAttempts,
  Value<int> overlayShows,
  Value<int> detectionEvents,
  Value<bool> timingVerified,
  Value<String> blockedPackagesJson,
  Value<int?> endedAtWallMs,
  Value<String?> reflection,
  Value<int> day,
  Value<String> source,
  Value<int> rowid,
});

final class $$FocusSessionsTableReferences extends BaseReferences<
    _$TrackDatabase, $FocusSessionsTable, FocusSessionRow> {
  $$FocusSessionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentRowsTable _commitmentIdTable(_$TrackDatabase db) =>
      db.commitmentRows
          .createAlias('focus_sessions__commitment_id__commitment_rows__id');

  $$CommitmentRowsTableProcessedTableManager? get commitmentId {
    final $_column = $_itemColumn<String>('commitment_id');
    if ($_column == null) return null;
    final manager = $$CommitmentRowsTableTableManager($_db, $_db.commitmentRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FocusSessionsTableFilterComposer
    extends Composer<_$TrackDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get plannedMinutes => $composableBuilder(
      column: $table.plannedMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalLabel => $composableBuilder(
      column: $table.goalLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAtWallMs => $composableBuilder(
      column: $table.startedAtWallMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAtRealtimeMs => $composableBuilder(
      column: $table.startedAtRealtimeMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get segmentStartedAtRealtimeMs => $composableBuilder(
      column: $table.segmentStartedAtRealtimeMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pausedAtWallMs => $composableBuilder(
      column: $table.pausedAtWallMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get focusMs => $composableBuilder(
      column: $table.focusMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pausedMs => $composableBuilder(
      column: $table.pausedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get enforcement => $composableBuilder(
      column: $table.enforcement, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endReason => $composableBuilder(
      column: $table.endReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get blockedAttempts => $composableBuilder(
      column: $table.blockedAttempts,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get overlayShows => $composableBuilder(
      column: $table.overlayShows, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get detectionEvents => $composableBuilder(
      column: $table.detectionEvents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get timingVerified => $composableBuilder(
      column: $table.timingVerified,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blockedPackagesJson => $composableBuilder(
      column: $table.blockedPackagesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endedAtWallMs => $composableBuilder(
      column: $table.endedAtWallMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reflection => $composableBuilder(
      column: $table.reflection, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  $$CommitmentRowsTableFilterComposer get commitmentId {
    final $$CommitmentRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableFilterComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$TrackDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plannedMinutes => $composableBuilder(
      column: $table.plannedMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalLabel => $composableBuilder(
      column: $table.goalLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAtWallMs => $composableBuilder(
      column: $table.startedAtWallMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAtRealtimeMs => $composableBuilder(
      column: $table.startedAtRealtimeMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get segmentStartedAtRealtimeMs => $composableBuilder(
      column: $table.segmentStartedAtRealtimeMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pausedAtWallMs => $composableBuilder(
      column: $table.pausedAtWallMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get focusMs => $composableBuilder(
      column: $table.focusMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pausedMs => $composableBuilder(
      column: $table.pausedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get enforcement => $composableBuilder(
      column: $table.enforcement, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endReason => $composableBuilder(
      column: $table.endReason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get blockedAttempts => $composableBuilder(
      column: $table.blockedAttempts,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get overlayShows => $composableBuilder(
      column: $table.overlayShows,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get detectionEvents => $composableBuilder(
      column: $table.detectionEvents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get timingVerified => $composableBuilder(
      column: $table.timingVerified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blockedPackagesJson => $composableBuilder(
      column: $table.blockedPackagesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endedAtWallMs => $composableBuilder(
      column: $table.endedAtWallMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reflection => $composableBuilder(
      column: $table.reflection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  $$CommitmentRowsTableOrderingComposer get commitmentId {
    final $$CommitmentRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableOrderingComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$TrackDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get plannedMinutes => $composableBuilder(
      column: $table.plannedMinutes, builder: (column) => column);

  GeneratedColumn<String> get goalLabel =>
      $composableBuilder(column: $table.goalLabel, builder: (column) => column);

  GeneratedColumn<int> get startedAtWallMs => $composableBuilder(
      column: $table.startedAtWallMs, builder: (column) => column);

  GeneratedColumn<int> get startedAtRealtimeMs => $composableBuilder(
      column: $table.startedAtRealtimeMs, builder: (column) => column);

  GeneratedColumn<int> get segmentStartedAtRealtimeMs => $composableBuilder(
      column: $table.segmentStartedAtRealtimeMs, builder: (column) => column);

  GeneratedColumn<int> get pausedAtWallMs => $composableBuilder(
      column: $table.pausedAtWallMs, builder: (column) => column);

  GeneratedColumn<int> get focusMs =>
      $composableBuilder(column: $table.focusMs, builder: (column) => column);

  GeneratedColumn<int> get pausedMs =>
      $composableBuilder(column: $table.pausedMs, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get enforcement => $composableBuilder(
      column: $table.enforcement, builder: (column) => column);

  GeneratedColumn<String> get endReason =>
      $composableBuilder(column: $table.endReason, builder: (column) => column);

  GeneratedColumn<int> get blockedAttempts => $composableBuilder(
      column: $table.blockedAttempts, builder: (column) => column);

  GeneratedColumn<int> get overlayShows => $composableBuilder(
      column: $table.overlayShows, builder: (column) => column);

  GeneratedColumn<int> get detectionEvents => $composableBuilder(
      column: $table.detectionEvents, builder: (column) => column);

  GeneratedColumn<bool> get timingVerified => $composableBuilder(
      column: $table.timingVerified, builder: (column) => column);

  GeneratedColumn<String> get blockedPackagesJson => $composableBuilder(
      column: $table.blockedPackagesJson, builder: (column) => column);

  GeneratedColumn<int> get endedAtWallMs => $composableBuilder(
      column: $table.endedAtWallMs, builder: (column) => column);

  GeneratedColumn<String> get reflection => $composableBuilder(
      column: $table.reflection, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$CommitmentRowsTableAnnotationComposer get commitmentId {
    final $$CommitmentRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSessionsTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $FocusSessionsTable,
    FocusSessionRow,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (FocusSessionRow, $$FocusSessionsTableReferences),
    FocusSessionRow,
    PrefetchHooks Function({bool commitmentId})> {
  $$FocusSessionsTableTableManager(
      _$TrackDatabase db, $FocusSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<int> plannedMinutes = const Value.absent(),
            Value<String> goalLabel = const Value.absent(),
            Value<String?> commitmentId = const Value.absent(),
            Value<int> startedAtWallMs = const Value.absent(),
            Value<int> startedAtRealtimeMs = const Value.absent(),
            Value<int?> segmentStartedAtRealtimeMs = const Value.absent(),
            Value<int?> pausedAtWallMs = const Value.absent(),
            Value<int> focusMs = const Value.absent(),
            Value<int> pausedMs = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<String?> outcome = const Value.absent(),
            Value<String> enforcement = const Value.absent(),
            Value<String?> endReason = const Value.absent(),
            Value<int> blockedAttempts = const Value.absent(),
            Value<int> overlayShows = const Value.absent(),
            Value<int> detectionEvents = const Value.absent(),
            Value<bool> timingVerified = const Value.absent(),
            Value<String> blockedPackagesJson = const Value.absent(),
            Value<int?> endedAtWallMs = const Value.absent(),
            Value<String?> reflection = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion(
            id: id,
            mode: mode,
            plannedMinutes: plannedMinutes,
            goalLabel: goalLabel,
            commitmentId: commitmentId,
            startedAtWallMs: startedAtWallMs,
            startedAtRealtimeMs: startedAtRealtimeMs,
            segmentStartedAtRealtimeMs: segmentStartedAtRealtimeMs,
            pausedAtWallMs: pausedAtWallMs,
            focusMs: focusMs,
            pausedMs: pausedMs,
            state: state,
            outcome: outcome,
            enforcement: enforcement,
            endReason: endReason,
            blockedAttempts: blockedAttempts,
            overlayShows: overlayShows,
            detectionEvents: detectionEvents,
            timingVerified: timingVerified,
            blockedPackagesJson: blockedPackagesJson,
            endedAtWallMs: endedAtWallMs,
            reflection: reflection,
            day: day,
            source: source,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String mode,
            required int plannedMinutes,
            required String goalLabel,
            Value<String?> commitmentId = const Value.absent(),
            required int startedAtWallMs,
            required int startedAtRealtimeMs,
            Value<int?> segmentStartedAtRealtimeMs = const Value.absent(),
            Value<int?> pausedAtWallMs = const Value.absent(),
            Value<int> focusMs = const Value.absent(),
            Value<int> pausedMs = const Value.absent(),
            required String state,
            Value<String?> outcome = const Value.absent(),
            required String enforcement,
            Value<String?> endReason = const Value.absent(),
            Value<int> blockedAttempts = const Value.absent(),
            Value<int> overlayShows = const Value.absent(),
            Value<int> detectionEvents = const Value.absent(),
            Value<bool> timingVerified = const Value.absent(),
            Value<String> blockedPackagesJson = const Value.absent(),
            Value<int?> endedAtWallMs = const Value.absent(),
            Value<String?> reflection = const Value.absent(),
            required int day,
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSessionsCompanion.insert(
            id: id,
            mode: mode,
            plannedMinutes: plannedMinutes,
            goalLabel: goalLabel,
            commitmentId: commitmentId,
            startedAtWallMs: startedAtWallMs,
            startedAtRealtimeMs: startedAtRealtimeMs,
            segmentStartedAtRealtimeMs: segmentStartedAtRealtimeMs,
            pausedAtWallMs: pausedAtWallMs,
            focusMs: focusMs,
            pausedMs: pausedMs,
            state: state,
            outcome: outcome,
            enforcement: enforcement,
            endReason: endReason,
            blockedAttempts: blockedAttempts,
            overlayShows: overlayShows,
            detectionEvents: detectionEvents,
            timingVerified: timingVerified,
            blockedPackagesJson: blockedPackagesJson,
            endedAtWallMs: endedAtWallMs,
            reflection: reflection,
            day: day,
            source: source,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FocusSessionsTable, FocusSessionRow>(table),
                    $$FocusSessionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({commitmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (commitmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.commitmentId,
                    referencedTable:
                        $$FocusSessionsTableReferences._commitmentIdTable(db),
                    referencedColumn: $$FocusSessionsTableReferences
                        ._commitmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FocusSessionsTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $FocusSessionsTable,
    FocusSessionRow,
    $$FocusSessionsTableFilterComposer,
    $$FocusSessionsTableOrderingComposer,
    $$FocusSessionsTableAnnotationComposer,
    $$FocusSessionsTableCreateCompanionBuilder,
    $$FocusSessionsTableUpdateCompanionBuilder,
    (FocusSessionRow, $$FocusSessionsTableReferences),
    FocusSessionRow,
    PrefetchHooks Function({bool commitmentId})>;
typedef $$FocusProfilesTableCreateCompanionBuilder = FocusProfilesCompanion
    Function({
  required String id,
  required String name,
  required String mode,
  required int minutes,
  Value<String?> commitmentId,
  Value<String> packagesJson,
  Value<int> sort,
  Value<int> rowid,
});
typedef $$FocusProfilesTableUpdateCompanionBuilder = FocusProfilesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> mode,
  Value<int> minutes,
  Value<String?> commitmentId,
  Value<String> packagesJson,
  Value<int> sort,
  Value<int> rowid,
});

final class $$FocusProfilesTableReferences extends BaseReferences<
    _$TrackDatabase, $FocusProfilesTable, FocusProfileRow> {
  $$FocusProfilesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentRowsTable _commitmentIdTable(_$TrackDatabase db) =>
      db.commitmentRows
          .createAlias('focus_profiles__commitment_id__commitment_rows__id');

  $$CommitmentRowsTableProcessedTableManager? get commitmentId {
    final $_column = $_itemColumn<String>('commitment_id');
    if ($_column == null) return null;
    final manager = $$CommitmentRowsTableTableManager($_db, $_db.commitmentRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FocusProfilesTableFilterComposer
    extends Composer<_$TrackDatabase, $FocusProfilesTable> {
  $$FocusProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minutes => $composableBuilder(
      column: $table.minutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnFilters(column));

  $$CommitmentRowsTableFilterComposer get commitmentId {
    final $$CommitmentRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableFilterComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusProfilesTableOrderingComposer
    extends Composer<_$TrackDatabase, $FocusProfilesTable> {
  $$FocusProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minutes => $composableBuilder(
      column: $table.minutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnOrderings(column));

  $$CommitmentRowsTableOrderingComposer get commitmentId {
    final $$CommitmentRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableOrderingComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusProfilesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $FocusProfilesTable> {
  $$FocusProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  $$CommitmentRowsTableAnnotationComposer get commitmentId {
    final $$CommitmentRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusProfilesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $FocusProfilesTable,
    FocusProfileRow,
    $$FocusProfilesTableFilterComposer,
    $$FocusProfilesTableOrderingComposer,
    $$FocusProfilesTableAnnotationComposer,
    $$FocusProfilesTableCreateCompanionBuilder,
    $$FocusProfilesTableUpdateCompanionBuilder,
    (FocusProfileRow, $$FocusProfilesTableReferences),
    FocusProfileRow,
    PrefetchHooks Function({bool commitmentId})> {
  $$FocusProfilesTableTableManager(
      _$TrackDatabase db, $FocusProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<int> minutes = const Value.absent(),
            Value<String?> commitmentId = const Value.absent(),
            Value<String> packagesJson = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusProfilesCompanion(
            id: id,
            name: name,
            mode: mode,
            minutes: minutes,
            commitmentId: commitmentId,
            packagesJson: packagesJson,
            sort: sort,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String mode,
            required int minutes,
            Value<String?> commitmentId = const Value.absent(),
            Value<String> packagesJson = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusProfilesCompanion.insert(
            id: id,
            name: name,
            mode: mode,
            minutes: minutes,
            commitmentId: commitmentId,
            packagesJson: packagesJson,
            sort: sort,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FocusProfilesTable, FocusProfileRow>(table),
                    $$FocusProfilesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({commitmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (commitmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.commitmentId,
                    referencedTable:
                        $$FocusProfilesTableReferences._commitmentIdTable(db),
                    referencedColumn: $$FocusProfilesTableReferences
                        ._commitmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FocusProfilesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $FocusProfilesTable,
    FocusProfileRow,
    $$FocusProfilesTableFilterComposer,
    $$FocusProfilesTableOrderingComposer,
    $$FocusProfilesTableAnnotationComposer,
    $$FocusProfilesTableCreateCompanionBuilder,
    $$FocusProfilesTableUpdateCompanionBuilder,
    (FocusProfileRow, $$FocusProfilesTableReferences),
    FocusProfileRow,
    PrefetchHooks Function({bool commitmentId})>;
typedef $$FocusSchedulesTableCreateCompanionBuilder = FocusSchedulesCompanion
    Function({
  required String id,
  required String mode,
  required int minutes,
  required int hour,
  required int minute,
  Value<String> weekdaysJson,
  Value<String?> commitmentId,
  Value<String> packagesJson,
  Value<bool> enabled,
  required int notificationId,
  Value<int> rowid,
});
typedef $$FocusSchedulesTableUpdateCompanionBuilder = FocusSchedulesCompanion
    Function({
  Value<String> id,
  Value<String> mode,
  Value<int> minutes,
  Value<int> hour,
  Value<int> minute,
  Value<String> weekdaysJson,
  Value<String?> commitmentId,
  Value<String> packagesJson,
  Value<bool> enabled,
  Value<int> notificationId,
  Value<int> rowid,
});

final class $$FocusSchedulesTableReferences extends BaseReferences<
    _$TrackDatabase, $FocusSchedulesTable, FocusScheduleRow> {
  $$FocusSchedulesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentRowsTable _commitmentIdTable(_$TrackDatabase db) =>
      db.commitmentRows
          .createAlias('focus_schedules__commitment_id__commitment_rows__id');

  $$CommitmentRowsTableProcessedTableManager? get commitmentId {
    final $_column = $_itemColumn<String>('commitment_id');
    if ($_column == null) return null;
    final manager = $$CommitmentRowsTableTableManager($_db, $_db.commitmentRows)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FocusSchedulesTableFilterComposer
    extends Composer<_$TrackDatabase, $FocusSchedulesTable> {
  $$FocusSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minutes => $composableBuilder(
      column: $table.minutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hour => $composableBuilder(
      column: $table.hour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minute => $composableBuilder(
      column: $table.minute, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weekdaysJson => $composableBuilder(
      column: $table.weekdaysJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get notificationId => $composableBuilder(
      column: $table.notificationId,
      builder: (column) => ColumnFilters(column));

  $$CommitmentRowsTableFilterComposer get commitmentId {
    final $$CommitmentRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableFilterComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSchedulesTableOrderingComposer
    extends Composer<_$TrackDatabase, $FocusSchedulesTable> {
  $$FocusSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minutes => $composableBuilder(
      column: $table.minutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hour => $composableBuilder(
      column: $table.hour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minute => $composableBuilder(
      column: $table.minute, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weekdaysJson => $composableBuilder(
      column: $table.weekdaysJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get notificationId => $composableBuilder(
      column: $table.notificationId,
      builder: (column) => ColumnOrderings(column));

  $$CommitmentRowsTableOrderingComposer get commitmentId {
    final $$CommitmentRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableOrderingComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSchedulesTableAnnotationComposer
    extends Composer<_$TrackDatabase, $FocusSchedulesTable> {
  $$FocusSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get weekdaysJson => $composableBuilder(
      column: $table.weekdaysJson, builder: (column) => column);

  GeneratedColumn<String> get packagesJson => $composableBuilder(
      column: $table.packagesJson, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get notificationId => $composableBuilder(
      column: $table.notificationId, builder: (column) => column);

  $$CommitmentRowsTableAnnotationComposer get commitmentId {
    final $$CommitmentRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.commitmentId,
        referencedTable: $db.commitmentRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommitmentRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.commitmentRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FocusSchedulesTableTableManager extends RootTableManager<
    _$TrackDatabase,
    $FocusSchedulesTable,
    FocusScheduleRow,
    $$FocusSchedulesTableFilterComposer,
    $$FocusSchedulesTableOrderingComposer,
    $$FocusSchedulesTableAnnotationComposer,
    $$FocusSchedulesTableCreateCompanionBuilder,
    $$FocusSchedulesTableUpdateCompanionBuilder,
    (FocusScheduleRow, $$FocusSchedulesTableReferences),
    FocusScheduleRow,
    PrefetchHooks Function({bool commitmentId})> {
  $$FocusSchedulesTableTableManager(
      _$TrackDatabase db, $FocusSchedulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<int> minutes = const Value.absent(),
            Value<int> hour = const Value.absent(),
            Value<int> minute = const Value.absent(),
            Value<String> weekdaysJson = const Value.absent(),
            Value<String?> commitmentId = const Value.absent(),
            Value<String> packagesJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> notificationId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSchedulesCompanion(
            id: id,
            mode: mode,
            minutes: minutes,
            hour: hour,
            minute: minute,
            weekdaysJson: weekdaysJson,
            commitmentId: commitmentId,
            packagesJson: packagesJson,
            enabled: enabled,
            notificationId: notificationId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String mode,
            required int minutes,
            required int hour,
            required int minute,
            Value<String> weekdaysJson = const Value.absent(),
            Value<String?> commitmentId = const Value.absent(),
            Value<String> packagesJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            required int notificationId,
            Value<int> rowid = const Value.absent(),
          }) =>
              FocusSchedulesCompanion.insert(
            id: id,
            mode: mode,
            minutes: minutes,
            hour: hour,
            minute: minute,
            weekdaysJson: weekdaysJson,
            commitmentId: commitmentId,
            packagesJson: packagesJson,
            enabled: enabled,
            notificationId: notificationId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FocusSchedulesTable, FocusScheduleRow>(table),
                    $$FocusSchedulesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({commitmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (commitmentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.commitmentId,
                    referencedTable:
                        $$FocusSchedulesTableReferences._commitmentIdTable(db),
                    referencedColumn: $$FocusSchedulesTableReferences
                        ._commitmentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FocusSchedulesTableProcessedTableManager = ProcessedTableManager<
    _$TrackDatabase,
    $FocusSchedulesTable,
    FocusScheduleRow,
    $$FocusSchedulesTableFilterComposer,
    $$FocusSchedulesTableOrderingComposer,
    $$FocusSchedulesTableAnnotationComposer,
    $$FocusSchedulesTableCreateCompanionBuilder,
    $$FocusSchedulesTableUpdateCompanionBuilder,
    (FocusScheduleRow, $$FocusSchedulesTableReferences),
    FocusScheduleRow,
    PrefetchHooks Function({bool commitmentId})>;

class $TrackDatabaseManager {
  final _$TrackDatabase _db;
  $TrackDatabaseManager(this._db);
  $$TrackerRowsTableTableManager get trackerRows =>
      $$TrackerRowsTableTableManager(_db, _db.trackerRows);
  $$DailyEntriesTableTableManager get dailyEntries =>
      $$DailyEntriesTableTableManager(_db, _db.dailyEntries);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db, _db.purchases);
  $$TrackEventsTableTableManager get trackEvents =>
      $$TrackEventsTableTableManager(_db, _db.trackEvents);
  $$CommitmentRowsTableTableManager get commitmentRows =>
      $$CommitmentRowsTableTableManager(_db, _db.commitmentRows);
  $$CommitmentEntriesTableTableManager get commitmentEntries =>
      $$CommitmentEntriesTableTableManager(_db, _db.commitmentEntries);
  $$CommitmentPausesTableTableManager get commitmentPauses =>
      $$CommitmentPausesTableTableManager(_db, _db.commitmentPauses);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$FocusProfilesTableTableManager get focusProfiles =>
      $$FocusProfilesTableTableManager(_db, _db.focusProfiles);
  $$FocusSchedulesTableTableManager get focusSchedules =>
      $$FocusSchedulesTableTableManager(_db, _db.focusSchedules);
}

mixin _$TrackDaoMixin on DatabaseAccessor<TrackDatabase> {
  $TrackerRowsTable get trackerRows => attachedDatabase.trackerRows;
  $DailyEntriesTable get dailyEntries => attachedDatabase.dailyEntries;
  $EventsTable get events => attachedDatabase.events;
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $TrackEventsTable get trackEvents => attachedDatabase.trackEvents;
  TrackDaoManager get managers => TrackDaoManager(this);
}

class TrackDaoManager {
  final _$TrackDaoMixin _db;
  TrackDaoManager(this._db);
  $$TrackerRowsTableTableManager get trackerRows =>
      $$TrackerRowsTableTableManager(_db.attachedDatabase, _db.trackerRows);
  $$DailyEntriesTableTableManager get dailyEntries =>
      $$DailyEntriesTableTableManager(_db.attachedDatabase, _db.dailyEntries);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$TrackEventsTableTableManager get trackEvents =>
      $$TrackEventsTableTableManager(_db.attachedDatabase, _db.trackEvents);
}

mixin _$CommitmentDaoMixin on DatabaseAccessor<TrackDatabase> {
  $CommitmentRowsTable get commitmentRows => attachedDatabase.commitmentRows;
  $CommitmentEntriesTable get commitmentEntries =>
      attachedDatabase.commitmentEntries;
  $CommitmentPausesTable get commitmentPauses =>
      attachedDatabase.commitmentPauses;
  CommitmentDaoManager get managers => CommitmentDaoManager(this);
}

class CommitmentDaoManager {
  final _$CommitmentDaoMixin _db;
  CommitmentDaoManager(this._db);
  $$CommitmentRowsTableTableManager get commitmentRows =>
      $$CommitmentRowsTableTableManager(
          _db.attachedDatabase, _db.commitmentRows);
  $$CommitmentEntriesTableTableManager get commitmentEntries =>
      $$CommitmentEntriesTableTableManager(
          _db.attachedDatabase, _db.commitmentEntries);
  $$CommitmentPausesTableTableManager get commitmentPauses =>
      $$CommitmentPausesTableTableManager(
          _db.attachedDatabase, _db.commitmentPauses);
}

mixin _$FocusDaoMixin on DatabaseAccessor<TrackDatabase> {
  $CommitmentRowsTable get commitmentRows => attachedDatabase.commitmentRows;
  $FocusSessionsTable get focusSessions => attachedDatabase.focusSessions;
  $FocusProfilesTable get focusProfiles => attachedDatabase.focusProfiles;
  $FocusSchedulesTable get focusSchedules => attachedDatabase.focusSchedules;
  FocusDaoManager get managers => FocusDaoManager(this);
}

class FocusDaoManager {
  final _$FocusDaoMixin _db;
  FocusDaoManager(this._db);
  $$CommitmentRowsTableTableManager get commitmentRows =>
      $$CommitmentRowsTableTableManager(
          _db.attachedDatabase, _db.commitmentRows);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db.attachedDatabase, _db.focusSessions);
  $$FocusProfilesTableTableManager get focusProfiles =>
      $$FocusProfilesTableTableManager(_db.attachedDatabase, _db.focusProfiles);
  $$FocusSchedulesTableTableManager get focusSchedules =>
      $$FocusSchedulesTableTableManager(
          _db.attachedDatabase, _db.focusSchedules);
}
