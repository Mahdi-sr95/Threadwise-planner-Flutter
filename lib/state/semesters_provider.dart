import 'package:flutter/foundation.dart';

import '../models/semester.dart';
import '../repositories/shared_prefs_semesters_repository.dart';

class SemestersProvider extends ChangeNotifier {
  final SharedPrefsSemestersRepository _repo = SharedPrefsSemestersRepository();

  static const String defaultSemesterId = 'default';
  static const String defaultSemesterName = 'Default';

  bool _initialized = false;

  List<Semester> _semesters = <Semester>[];
  String? _selectedId;

  List<Semester> get semesters => List.unmodifiable(_semesters);

  Semester? get selectedSemester {
    if (_selectedId == null) return null;
    return _semesters.where((s) => s.id == _selectedId).firstOrNull;
  }

  String get selectedSemesterId => _selectedId ?? defaultSemesterId;

  Future<void> init() async {
    if (_initialized) return;

    await _repo.init();
    _semesters = await _repo.getAll();
    _selectedId = await _repo.getSelectedSemesterId();

    // Ensure default semester exists
    if (_semesters.isEmpty ||
        !_semesters.any((s) => s.id == defaultSemesterId)) {
      final def = Semester(
        id: defaultSemesterId,
        name: defaultSemesterName,
        createdAt: DateTime.now(),
      );
      // Make sure default is in list and stored
      _semesters.removeWhere((s) => s.id == defaultSemesterId);
      _semesters.insert(0, def);
      await _repo.save(def);
    }

    // Ensure selection exists
    if (_selectedId == null || !_semesters.any((s) => s.id == _selectedId)) {
      _selectedId = defaultSemesterId;
      await _repo.setSelectedSemesterId(_selectedId!);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> selectSemester(String id) async {
    if (!_semesters.any((s) => s.id == id)) return;
    _selectedId = id;
    await _repo.setSelectedSemesterId(id);
    notifyListeners();
  }

  Future<void> addSemester({
    required String name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final s = Semester(
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    _semesters = [..._semesters, s]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _repo.save(s);
    await selectSemester(s.id);
  }

  Future<void> deleteSemester(String id) async {
    if (id == defaultSemesterId) return;
    _semesters = _semesters.where((s) => s.id != id).toList();
    await _repo.deleteById(id);

    if (_selectedId == id) {
      _selectedId = defaultSemesterId;
      await _repo.setSelectedSemesterId(_selectedId!);
    }
    notifyListeners();
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
