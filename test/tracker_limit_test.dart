import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/config/pro_config.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/state/app_state.dart';

/// The free tracker ceiling, enforced by `AppState` rather than by each screen.
///
/// Free: any [ProConfig.freeTrackerLimit] trackers visible at once, chosen from the
/// whole catalogue — core trackers (shown/hidden with the switch) and "add more"
/// entries alike. Pro: no ceiling. Hiding is always allowed and never deletes
/// history; a user already over the ceiling keeps everything they show.
void main() {
  late TrackDatabase db;
  late CommitmentRepository commitments;

  setUp(() {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    commitments = CommitmentRepository(db);
  });
  tearDown(() => db.close());

  Future<AppState> open() async {
    final s = AppState(repo: EntryRepository(db), commitmentRepo: commitments);
    await s.load();
    return s;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  // The shape billing_test uses for "a server-verified purchase grants Pro".
  final pro = Entitlement(
    isPro: true,
    planId: 'track_pro_annual',
    productId: 'track_pro_annual',
    expiresAt: DateTime.now().add(const Duration(days: 300)),
    autoRenew: true,
    purchaseToken: 'tok_test',
    source: 'play',
    verified: true,
    verifiedAt: DateTime.now(),
  );

  Set<String> visible(AppState s) => s.visibleTrackers.map((t) => t.id).toSet();

  test('the ceiling is five, and a new install starts inside it with room to choose', () async {
    final state = await open();
    expect(ProConfig.freeTrackerLimit, 5);
    expect(visible(state), DefaultTrackers.enabledByDefault.toSet());
    expect(state.visibleTrackers.length, lessThan(ProConfig.freeTrackerLimit));
    expect(state.canAddTracker(), isTrue);
  });

  test('a free user can mix core and catalogue trackers up to five, and no further', () async {
    final state = await open();
    expect(state.toggleHidden('sleep'), isTrue, reason: 'a core tracker');
    expect(state.toggleAdded('reading'), isTrue, reason: 'an add-more catalogue tracker');
    expect(state.visibleTrackers.length, 5);
    expect(state.atTrackerLimit, isTrue);

    // A sixth is refused by every path, and nothing changes.
    expect(state.toggleHidden('steps'), isFalse);
    expect(state.byId('steps').hidden, isTrue);
    expect(state.toggleAdded('caffeine'), isFalse);
    expect(state.added.contains('caffeine'), isFalse);
    expect(state.trackerOrNull('caffeine'), isNull);
    expect(state.visibleTrackers.length, 5);

    await settle();
    final reopened = await open();
    expect(reopened.visibleTrackers.length, 5, reason: 'the refused writes never reached the database');
    expect(visible(reopened), containsAll(<String>['sleep', 'reading']));
  });

  test('"any five" means any: the defaults can be swapped for five others', () async {
    final state = await open();
    for (final id in DefaultTrackers.enabledByDefault) {
      expect(state.toggleHidden(id), isTrue, reason: 'hiding is always allowed');
    }
    const choice = <String>['sleep', 'steps', 'weight', 'screen'];
    for (final id in choice) {
      expect(state.toggleHidden(id), isTrue);
    }
    expect(state.toggleAdded('meditation'), isTrue);
    expect(visible(state), {...choice, 'meditation'});
    expect(state.toggleHidden('water'), isFalse, reason: 'a default is not exempt from the ceiling');
  });

  test('a freed slot can be used again', () async {
    final state = await open();
    state
      ..toggleHidden('sleep')
      ..toggleHidden('steps');
    expect(state.atTrackerLimit, isTrue);
    expect(state.toggleHidden('mood'), isTrue);
    expect(state.toggleHidden('weight'), isTrue);
    expect(state.visibleTrackers.length, 5);
  });

  test('re-adding a catalogue tracker that is already visible does not need a slot', () async {
    final state = await open();
    state
      ..toggleAdded('reading')
      ..toggleHidden('sleep');
    expect(state.atTrackerLimit, isTrue);
    // Removing then re-adding at the ceiling: removal frees the slot it re-uses.
    expect(state.toggleAdded('reading'), isTrue, reason: 'remove');
    expect(state.toggleAdded('reading'), isTrue, reason: 're-add into the freed slot');
    expect(state.visibleTrackers.length, 5);
  });

  test('Pro has no ceiling', () async {
    final state = await open();
    state.entitlement = pro;
    for (final t in state.trackers.where((t) => t.hidden).toList()) {
      expect(state.toggleHidden(t.id), isTrue);
    }
    for (final e in DefaultTrackers.addable) {
      expect(state.toggleAdded(e.id), isTrue);
    }
    expect(state.visibleTrackers.length, greaterThan(ProConfig.freeTrackerLimit));
    expect(state.canAddTracker(), isTrue);
  });

  test('a lapsed Pro user over the ceiling keeps every visible tracker and its history', () async {
    final state = await open();
    state.entitlement = pro;
    for (final id in <String>['sleep', 'steps', 'weight', 'screen']) {
      state.toggleHidden(id);
    }
    state.toggleAdded('reading');
    expect(state.log('sleep', 7), isTrue);
    expect(state.visibleTrackers.length, 8);
    await settle();

    // Pro ends. Nothing is hidden, nothing is deleted.
    final lapsed = await open();
    expect(lapsed.isPro, isFalse);
    expect(lapsed.visibleTrackers.length, 8);
    expect(lapsed.today('sleep'), 7);

    // They can always hide, but cannot show another until back under five.
    expect(lapsed.toggleHidden('screen'), isTrue);
    expect(lapsed.toggleHidden('screen'), isFalse, reason: '7 visible is still over the ceiling');
    for (final id in <String>['steps', 'weight', 'reading']) {
      lapsed.toggleAdded(id) || lapsed.toggleHidden(id);
    }
    expect(lapsed.visibleTrackers.length, 4);
    expect(lapsed.toggleHidden('screen'), isTrue, reason: 'back under the ceiling, a slot is open');
    expect(lapsed.today('sleep'), 7, reason: 'history survives every visibility change');
  });
}
