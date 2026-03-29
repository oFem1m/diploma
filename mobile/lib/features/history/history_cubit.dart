import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/job_result.dart';
import '../../storage/database.dart';

class HistoryState extends Equatable {
  final List<SavedJobResult> results;
  final String? filterMethod;
  final String? filterObjective;
  final Set<int> selectedIds;
  final bool loading;

  const HistoryState({
    this.results = const [],
    this.filterMethod,
    this.filterObjective,
    this.selectedIds = const {},
    this.loading = true,
  });

  HistoryState copyWith({
    List<SavedJobResult>? results,
    String? filterMethod,
    String? filterObjective,
    Set<int>? selectedIds,
    bool? loading,
  }) {
    return HistoryState(
      results: results ?? this.results,
      filterMethod: filterMethod ?? this.filterMethod,
      filterObjective: filterObjective ?? this.filterObjective,
      selectedIds: selectedIds ?? this.selectedIds,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props =>
      [results.length, filterMethod, filterObjective, selectedIds, loading];
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit() : super(const HistoryState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final results = await AppDatabase.getResultsByFilter(
      method: state.filterMethod,
      objectiveName: state.filterObjective,
    );
    emit(state.copyWith(results: results, loading: false));
  }

  void setFilterMethod(String? method) {
    emit(HistoryState(
      filterMethod: method,
      filterObjective: state.filterObjective,
    ));
    load();
  }

  void setFilterObjective(String? objective) {
    emit(HistoryState(
      filterMethod: state.filterMethod,
      filterObjective: objective,
    ));
    load();
  }

  void clearFilters() {
    emit(const HistoryState());
    load();
  }

  void toggleSelection(int id) {
    final selected = Set<int>.from(state.selectedIds);
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      if (selected.length < 7) {
        selected.add(id);
      }
    }
    emit(state.copyWith(selectedIds: selected));
  }

  void clearSelection() {
    emit(state.copyWith(selectedIds: {}));
  }

  Future<void> deleteResult(int id) async {
    await AppDatabase.deleteResult(id);
    final selected = Set<int>.from(state.selectedIds)..remove(id);
    emit(state.copyWith(selectedIds: selected));
    load();
  }

  List<SavedJobResult> get selectedResults {
    return state.results
        .where((r) => r.id != null && state.selectedIds.contains(r.id))
        .toList();
  }
}
