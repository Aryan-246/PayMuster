import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminUsersRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void requestRefresh() => state++;
}

final adminUsersRefreshProvider =
    NotifierProvider<AdminUsersRefreshNotifier, int>(
      AdminUsersRefreshNotifier.new,
    );
