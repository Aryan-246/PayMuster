import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';
import '../data/staff_directory_api.dart';

/// Search + filter + pagination state for the Owner staff directory.
/// The backend enforces the view_staff scope; this controller only drives
/// query parameters and accumulates pages.
class StaffDirectoryState {
  const StaffDirectoryState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.search = '',
    this.status,
    this.workerType,
    this.error,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<StaffMember> items;
  final int total;
  final int page;
  final int totalPages;
  final String search;
  final String? status;
  final String? workerType;
  final String? error;

  bool get hasMore => page < totalPages;

  StaffDirectoryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<StaffMember>? items,
    int? total,
    int? page,
    int? totalPages,
    String? search,
    Object? status = _unset,
    Object? workerType = _unset,
    Object? error = _unset,
  }) {
    return StaffDirectoryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      search: search ?? this.search,
      status: identical(status, _unset) ? this.status : status as String?,
      workerType: identical(workerType, _unset)
          ? this.workerType
          : workerType as String?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class StaffDirectoryController extends Notifier<StaffDirectoryState> {
  Timer? _debounce;
  int _loadGeneration = 0;

  @override
  StaffDirectoryState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(load);
    return const StaffDirectoryState();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref.read(staffDirectoryApiProvider).listStaff(
            search: state.search.trim().isEmpty ? null : state.search.trim(),
            status: state.status,
            workerType: state.workerType,
            page: 1,
          );
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        items: result.items,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      );
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: _message(error, 'Staff could not be loaded.'),
      );
    }
  }

  Future<void> refresh() => load();

  /// Debounced search entry — typing does not spam the API.
  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), load);
  }

  void setStatus(String? status) {
    if (state.status == status) return;
    state = state.copyWith(status: status);
    load();
  }

  void setWorkerType(String? workerType) {
    if (state.workerType == workerType) return;
    state = state.copyWith(workerType: workerType);
    load();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final generation = _loadGeneration;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref.read(staffDirectoryApiProvider).listStaff(
            search: state.search.trim().isEmpty ? null : state.search.trim(),
            status: state.status,
            workerType: state.workerType,
            page: state.page + 1,
          );
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...result.items],
        total: result.total,
        page: result.page,
        totalPages: result.totalPages,
      );
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: _message(error, 'More staff could not be loaded.'),
      );
    }
  }

  /// Called after an add-staff round-trip so the roster reflects it.
  Future<void> reloadAfterMutation() => load();
}

String _message(Object error, String fallback) {
  if (error is TenantApiException) return error.message;
  return fallback;
}

final staffDirectoryControllerProvider =
    NotifierProvider<StaffDirectoryController, StaffDirectoryState>(
  StaffDirectoryController.new,
);
