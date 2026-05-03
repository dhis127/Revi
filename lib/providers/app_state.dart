import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/highlight.dart';

class AppState extends ChangeNotifier {
  List<Book> _books = List.from(seedBooks);
  List<Highlight> _highlights = List.from(seedHighlights);
  String _activeSlot = 'sage';
  String? _tocSavedForBookId;
  bool _isDark = false;

  List<Book> get books => _books;
  List<Highlight> get highlights => _highlights;
  String get activeSlot => _activeSlot;
  String? get tocSavedForBookId => _tocSavedForBookId;
  bool get isDark => _isDark;

  void setSlot(String slot) {
    _activeSlot = slot;
    notifyListeners();
  }

  void setTocSaved(String bookId) {
    _tocSavedForBookId = bookId;
    notifyListeners();
  }

  void clearTocSaved() {
    _tocSavedForBookId = null;
    notifyListeners();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void addHighlight(Highlight h) {
    _highlights = [h, ..._highlights];
    notifyListeners();
  }

  void updateHighlightNote(String id, String note) {
    _highlights = _highlights.map((h) => h.id == id ? h.copyWith(note: note) : h).toList();
    notifyListeners();
  }

  void addBook(Book b) {
    _books = [..._books, b];
    notifyListeners();
  }

  List<Highlight> highlightsForBook(String bookId) =>
      _highlights.where((h) => h.bookId == bookId).toList();

  String nextHighlightId() => 'h${_highlights.length + 1}';
  String nextBookId() => 'b${_books.length + 1}';
}
