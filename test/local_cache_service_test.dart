import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/data/local/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('cached lists remain separated by user', () async {
    await LocalCacheService.instance.saveList('user-a', 'notifications', [
      {'id': 'one', 'is_read': false},
    ]);

    expect(
      await LocalCacheService.instance.loadList('user-a', 'notifications'),
      [
        {'id': 'one', 'is_read': false},
      ],
    );
    expect(
      await LocalCacheService.instance.loadList('user-b', 'notifications'),
      isNull,
    );
  });

  test('draft maps can be saved and cleared', () async {
    await LocalCacheService.instance.saveMap('user-a', 'feedback_draft', {
      'category': 'suggestion',
      'message': 'Keep this draft',
    });

    expect(
      await LocalCacheService.instance.loadMap('user-a', 'feedback_draft'),
      {'category': 'suggestion', 'message': 'Keep this draft'},
    );

    await LocalCacheService.instance.remove('user-a', 'feedback_draft');
    expect(
      await LocalCacheService.instance.loadMap('user-a', 'feedback_draft'),
      isNull,
    );
  });
}
