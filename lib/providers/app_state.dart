import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../models/reading_report.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

enum AppThemeMode { light, rest, dark, sepia }

class AppState extends ChangeNotifier {
  // 슬롯 기본 색상 (리셋용)
  static const Map<String, Color> _defaultSlotColors = {
    'sage':  Color(0xFF8FB89E),
    'terra': Color(0xFFB85C38),
    'amber': Color(0xFF8A6523),
  };

  // ── 인증 상태 ─────────────────────────────────────────────────────────────
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  // 첫 설치 시 빈 상태로 시작 (seed 데이터 없음)
  List<Book> _books = [];
  List<Highlight> _highlights = [];
  String _activeSlot = 'sage';
  String? _tocSavedForBookId;
  AppThemeMode _themeMode = AppThemeMode.light;
  String _memoFont = 'gaegu';
  double _themeIntensity = 1.0; // 0.3 ~ 1.0, 프리미엄 전용
  String _exportFormat = 'csv';
  List<String> _highlightSlotOrder = ['sage', 'terra', 'amber'];
  // ── 문장 리마인더 ─────────────────────────────────────────────────────────────
  bool _reminderEnabled = false;
  // 0=월, 1=화, 2=수, 3=목, 4=금, 5=토, 6=일 (전부 선택 = 매일)
  Set<int> _reminderDays = {0, 1, 2, 3, 4, 5, 6};
  TimeOfDay _reminderStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _reminderEndTime = const TimeOfDay(hour: 21, minute: 0);

  // ── 닉네임 ────────────────────────────────────────────────────────────────
  String _nickname = '';
  String get nickname => _nickname;
  /// 닉네임이 없으면 '독자' 반환
  String get displayName => _nickname.trim().isEmpty ? '독자' : _nickname.trim();

  void setNickname(String name) {
    _nickname = name.trim();
    notifyListeners();
  }

  // ── 독서 리포트 ───────────────────────────────────────────────────────────
  // 개발 중 확인용 샘플 리포트 (Phase 3에서 서버 데이터로 교체)
  List<ReadingReport> _reports = [
    ReadingReport(
      id: 'report_sample_2026_3',
      year: 2026, month: 3,
      generatedAt: DateTime(2026, 3, 1),
      booksAdded: 3, quotesAdded: 21,
      topBookTitle: '파친코',
      quotesBySlot: {'sage': 12, 'terra': 6, 'amber': 3},
      aiComment: '책장을 지키며 지켜봐 왔습니다. 이달도 조용히, 그러나 꾸준히 쌓아 가셨군요.',
      isRead: true,
    ),
    ReadingReport(
      id: 'report_sample_2026_4',
      year: 2026, month: 4,
      generatedAt: DateTime(2026, 4, 1),
      booksAdded: 2, quotesAdded: 14,
      topBookTitle: '채식주의자',
      quotesBySlot: {'sage': 8, 'terra': 4, 'amber': 2},
      aiComment: '골라낸 문장들이 곧 당신의 언어가 됩니다. 이 서가는 그것을 기억하고 있어요.',
      isRead: true,
    ),
    ReadingReport(
      id: 'report_sample_2026_5',
      year: 2026, month: 5,
      generatedAt: DateTime(2026, 5, 1),
      booksAdded: 4, quotesAdded: 32,
      topBookTitle: '82년생 김지영',
      quotesBySlot: {'sage': 18, 'terra': 9, 'amber': 5},
      aiComment: '이달 서가에 꽂힌 문장들을 살펴보니, 당신의 시선이 어디를 향하고 있는지 보입니다.',
      isRead: false, // 미읽음 → 배너 표시
    ),
  ];
  List<ReadingReport> get reports => List.unmodifiable(_reports);
  bool get hasUnreadReport => _reports.any((r) => !r.isRead);
  ReadingReport? get latestUnreadReport =>
      _reports.where((r) => !r.isRead).isEmpty
          ? null
          : _reports.where((r) => !r.isRead).last;

  void addReport(ReadingReport r) {
    _reports = [..._reports, r];
    notifyListeners();
  }

  void markReportRead(String id) {
    _reports = _reports
        .map((r) => r.id == id ? r.copyWith(isRead: true) : r)
        .toList();
    notifyListeners();
  }

  /// 현재 데이터를 기반으로 월간 리포트 생성 (mock AI 코멘트 포함)
  ReadingReport generateMonthlyReport(int year, int month) {
    final comments = [
      '이달 서가에 꽂힌 문장들을 살펴보니, 당신의 시선이 어디를 향하고 있는지 보입니다.',
      '책장을 지키며 지켜봐 왔습니다. 이달도 조용히, 그러나 꾸준히 쌓아 가셨군요.',
      '골라낸 문장들이 곧 당신의 언어가 됩니다. 이 서가는 그것을 기억하고 있어요.',
      '독서란 결국 자신에게 보내는 편지입니다. 이달의 문장들은 그 편지의 일부예요.',
      '서가는 채워질수록 더 많은 이야기를 품습니다. 다음 달도 기다리겠습니다.',
    ];
    final rng = Random();
    final slotMap = <String, int>{};
    for (final h in _highlights) {
      slotMap[h.slot] = (slotMap[h.slot] ?? 0) + 1;
    }
    final topBook = _books.isEmpty ? '' : _books.last.title;
    return ReadingReport(
      id: 'report_${year}_${month}_${rng.nextInt(9999)}',
      year: year,
      month: month,
      generatedAt: DateTime(year, month, 1),
      booksAdded: _books.length,
      quotesAdded: _highlights.length,
      topBookTitle: topBook,
      quotesBySlot: slotMap,
      aiComment: comments[rng.nextInt(comments.length)],
    );
  }

  // ── 구독 상태 ─────────────────────────────────────────────────────────────
  SubscriptionTier _subscriptionTier = SubscriptionTier.free;

  // 실제 저장 카운터 (Phase 3에서 DB 쿼리로 교체)
  int _effectiveBookCount      = 0;
  int _effectiveHighlightCount = 0;

  Map<String, Color> _slotColors = {
    'sage':  const Color(0xFF8FB89E),
    'terra': const Color(0xFFB85C38),
    'amber': const Color(0xFF8A6523),
  };

  // ── 기본 getter ───────────────────────────────────────────────────────────
  List<Book>      get books           => _books;
  List<Highlight> get highlights      => _highlights;
  String          get activeSlot      => _activeSlot;
  String?         get tocSavedForBookId => _tocSavedForBookId;
  AppThemeMode    get themeMode       => _themeMode;
  bool            get isDark          => _themeMode == AppThemeMode.dark;
  bool            get isRest          => _themeMode == AppThemeMode.rest;
  Map<String, Color> get slotColors   => _slotColors;
  String          get memoFont        => _memoFont;
  double get themeIntensity => _themeIntensity;
  String get exportFormat => _exportFormat;
  List<String> get highlightSlotOrder => _highlightSlotOrder;
  bool get isSepia => _themeMode == AppThemeMode.sepia;
  bool get reminderEnabled => _reminderEnabled;
  Set<int> get reminderDays => _reminderDays;
  bool get reminderIsDaily => _reminderDays.length == 7;
  TimeOfDay get reminderStartTime => _reminderStartTime;
  TimeOfDay get reminderEndTime => _reminderEndTime;

  bool isDefaultSlotColor(String slot) {
    final def = _defaultSlotColors[slot];
    if (def == null) return true;
    return _slotColors[slot]?.toARGB32() == def.toARGB32();
  }

  List<String> get availableExportFormats {
    switch (_subscriptionTier) {
      case SubscriptionTier.premiumAnnual:
        return ['csv', 'pdf', 'md'];
      case SubscriptionTier.standardMonthly:
      case SubscriptionTier.standardAnnual:
        return ['csv'];
      case SubscriptionTier.free:
        return [];
    }
  }

  bool get canAddHighlightSlot =>
      _svc.canAddHighlightSlot(_highlightSlotOrder.length, _subscriptionTier);

  bool canUseThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return true;
      case AppThemeMode.rest:
      case AppThemeMode.dark: return _subscriptionTier != SubscriptionTier.free;
      case AppThemeMode.sepia: return _subscriptionTier == SubscriptionTier.premiumAnnual;
    }
  }

  bool canUseFont(String fontKey) {
    const freeFonts = {'notoSansKr', 'nanumPenScript', 'gaegu'};
    if (freeFonts.contains(fontKey)) return true;
    // 스탠다드 이용 가능 폰트 (design_tokens의 standardFontKeys와 동기화)
    const stdFonts = {
      'ibmPlexSansKr', 'jua', 'doHyeon', 'blackHanSans',
      'cuteFont', 'kirangHaerang', 'singleDay',
    };
    if (stdFonts.contains(fontKey)) return _subscriptionTier != SubscriptionTier.free;
    // 나머지는 프리미엄 전용
    return _subscriptionTier == SubscriptionTier.premiumAnnual;
  }

  // ── 구독 getter ───────────────────────────────────────────────────────────
  SubscriptionTier get subscriptionTier => _subscriptionTier;
  bool get isSubscribed => _subscriptionTier != SubscriptionTier.free;
  bool get isStandard   => _subscriptionTier == SubscriptionTier.standardMonthly ||
                           _subscriptionTier == SubscriptionTier.standardAnnual;
  bool get isStdAnnual  => _subscriptionTier == SubscriptionTier.standardAnnual;
  bool get isPremium    => _subscriptionTier == SubscriptionTier.premiumAnnual;

  // ── 카운터 getter (Phase 3에서 실제 DB 쿼리로 교체) ──────────────────────
  int get effectiveBookCount      => _effectiveBookCount;
  int get effectiveHighlightCount => _effectiveHighlightCount;

  // ── 한도 체크 (SubscriptionService 위임) ──────────────────────────────────
  final _svc = SubscriptionService.instance;

  bool get canSaveBook =>
      _svc.canSaveBook(_effectiveBookCount, _subscriptionTier);
  bool get canSaveHighlight =>
      _svc.canSaveHighlight(_effectiveHighlightCount, _subscriptionTier);
  bool get canAddShelf =>
      _svc.canAddShelf(_pageCount, _subscriptionTier);
  bool get isNearBookLimit =>
      _svc.isNearBookLimit(_effectiveBookCount, _subscriptionTier);
  bool get isNearHighlightLimit =>
      _svc.isNearHighlightLimit(_effectiveHighlightCount, _subscriptionTier);

  // 스탠다드 → 프리미엄 업셀 (책장 8/10 이상)
  bool get shouldUpsellToPremium =>
      _svc.isNearShelfLimitForUpsell(_books.length, _subscriptionTier);

  String get bookLimitMessage =>
      _svc.bookLimitMessage(_effectiveBookCount, _subscriptionTier);
  String get highlightLimitMessage =>
      _svc.highlightLimitMessage(_effectiveHighlightCount, _subscriptionTier);

  // ── 구독 액션 ─────────────────────────────────────────────────────────────
  void subscribe(SubscriptionTier tier) {
    _subscriptionTier = tier;
    if (!availableExportFormats.contains(_exportFormat)) {
      _exportFormat = availableExportFormats.isNotEmpty ? availableExportFormats.first : 'csv';
    }
    notifyListeners();
  }

  void cancelSubscription() {
    _subscriptionTier = SubscriptionTier.free;
    if (!canUseThemeMode(_themeMode)) _themeMode = AppThemeMode.light;
    _highlightSlotOrder = ['sage', 'terra', 'amber'];
    _slotColors = {
      'sage':  const Color(0xFF8FB89E),
      'terra': const Color(0xFFB85C38),
      'amber': const Color(0xFF8A6523),
    };
    _exportFormat = 'csv';
    notifyListeners();
  }

  // ── 앱 상태 액션 ──────────────────────────────────────────────────────────
  void updateMemoFont(String fontKey) {
    _memoFont = fontKey;
    notifyListeners();
  }

  Color slotColor(String slot) =>
      _slotColors[slot] ?? _slotColors['sage']!;

  void updateSlotColor(String slot, Color color) {
    _slotColors = Map.from(_slotColors)..[slot] = color;
    notifyListeners();
  }

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
    final usable = AppThemeMode.values.where(canUseThemeMode).toList();
    final idx = usable.indexOf(_themeMode);
    _themeMode = usable[(idx + 1) % usable.length];
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setThemeIntensity(double v) {
    _themeIntensity = v.clamp(0.3, 1.0);
    notifyListeners();
  }

  void setExportFormat(String fmt) {
    if (availableExportFormats.contains(fmt)) {
      _exportFormat = fmt;
      notifyListeners();
    }
  }

  void addHighlightSlot() {
    if (!canAddHighlightSlot) return;
    final newKey = 'custom_${_highlightSlotOrder.length}';
    _slotColors = Map.from(_slotColors)..[newKey] = const Color(0xFF9BB8D4);
    _highlightSlotOrder = [..._highlightSlotOrder, newKey];
    notifyListeners();
  }

  void removeHighlightSlot(String slot) {
    if (['sage', 'terra', 'amber'].contains(slot)) return;
    _slotColors = Map.from(_slotColors)..remove(slot);
    _highlightSlotOrder = _highlightSlotOrder.where((s) => s != slot).toList();
    notifyListeners();
  }

  void resetSlotColor(String slot) {
    final def = _defaultSlotColors[slot];
    if (def == null) return;
    _slotColors = Map.from(_slotColors)..[slot] = def;
    notifyListeners();
  }

  void setReminderEnabled(bool v) {
    _reminderEnabled = v;
    notifyListeners();
  }

  void toggleReminderDay(int day) {
    final next = Set<int>.from(_reminderDays);
    if (next.contains(day)) {
      if (next.length > 1) next.remove(day); // 최소 1일 유지
    } else {
      next.add(day);
    }
    _reminderDays = next;
    notifyListeners();
  }

  void setReminderDays(Set<int> days) {
    if (days.isEmpty) return;
    _reminderDays = Set.from(days);
    notifyListeners();
  }

  void setReminderStartTime(TimeOfDay t) {
    _reminderStartTime = t;
    notifyListeners();
  }

  void setReminderEndTime(TimeOfDay t) {
    _reminderEndTime = t;
    notifyListeners();
  }

  void addHighlight(Highlight h) {
    if (_highlights.any((e) => e.id == h.id)) return; // 중복 방지
    _highlights = [h, ..._highlights];
    _effectiveHighlightCount++;
    notifyListeners();
  }

  void updateHighlightNote(String id, String note) {
    _highlights = _highlights
        .map((h) => h.id == id ? h.copyWith(note: note) : h)
        .toList();
    notifyListeners();
  }

  void removeHighlight(String id) {
    _highlights = _highlights.where((h) => h.id != id).toList();
    notifyListeners();
  }

  /// 목차가 없는 책의 문장 순서 변경 — draggedId를 targetId 앞에 삽입
  void reorderHighlights(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final list  = List<Highlight>.from(_highlights);
    final from  = list.indexWhere((h) => h.id == draggedId);
    final to    = list.indexWhere((h) => h.id == targetId);
    if (from == -1 || to == -1) return;
    final item = list.removeAt(from);
    list.insert(to > from ? to - 1 : to, item);
    _highlights = list;
    notifyListeners();
  }

  /// 스캔 직후 '기존 도서에 추가' 시 사용 — 가장 최근 저장된 문장의 bookId를 변경
  void moveLastHighlightToBook(String targetBookId) {
    if (_highlights.isEmpty) return;
    final last = _highlights.last;
    _highlights = [
      ..._highlights.sublist(0, _highlights.length - 1),
      last.copyWith(bookId: targetBookId),
    ];
    notifyListeners();
  }

  // ── 책장 페이지 관리 ─────────────────────────────────────────────────────────
  // pageIndex × 10 = 해당 페이지의 책장 슬롯 기준 (0=표지, 1~3=책등)
  int _pageCount = 1;
  int get pageCount => _pageCount;

  final Map<int, String> _pageNames = {};
  String getPageName(int page) =>
      (_pageNames[page]?.isNotEmpty == true) ? _pageNames[page]! : (page == 0 ? '나의 책장' : '책장 ${page + 1}');

  void updatePageName(int page, String name) {
    _pageNames[page] = name;
    notifyListeners();
  }

  void addShelfPage() {
    _pageCount++;
    notifyListeners();
  }

  // 책을 특정 페이지의 표지 칸으로 이동
  void moveBookToPage(String bookId, int targetPage) {
    moveBookToShelf(bookId, targetPage * 10);
  }

  final Map<int, String> _shelfLabels = {};
  String getShelfLabel(int shelf) => _shelfLabels[shelf] ?? '';
  void updateShelfLabel(int shelf, String label) {
    _shelfLabels[shelf] = label;
    notifyListeners();
  }

  void moveBookToShelf(String bookId, int newShelf) {
    final book = _books.firstWhere((b) => b.id == bookId);
    _books = [
      ..._books.where((b) => b.id != bookId),
      book.copyWith(shelf: newShelf),
    ];
    notifyListeners();
  }

  void addBook(Book b) {
    _books = [..._books, b];
    _effectiveBookCount++;
    notifyListeners();
  }

  void updateBookCover(String bookId, String imagePath) {
    _books = _books
        .map((b) => b.id == bookId ? b.copyWith(coverImagePath: imagePath) : b)
        .toList();
    notifyListeners();
  }

  void updateBookCoverBytes(String bookId, Uint8List bytes) {
    _books = _books
        .map((b) => b.id == bookId ? b.copyWith(coverImageBytes: bytes) : b)
        .toList();
    notifyListeners();
  }

  void updateBookComment(String bookId, String comment) {
    _books = _books
        .map((b) => b.id == bookId ? b.copyWith(comment: comment) : b)
        .toList();
    notifyListeners();
  }

  List<Highlight> highlightsForBook(String bookId) =>
      _highlights.where((h) => h.bookId == bookId).toList();

  String nextHighlightId() => 'h${_highlights.length + 1}';
  String nextBookId() => 'b${_books.length + 1}';

  // ── 영속화 ────────────────────────────────────────────────────────────────
  Timer? _saveDebounce;

  /// 앱 시작 시 한 번 호출 — 저장된 상태를 복원
  Future<void> loadState() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_state.json');
      if (!file.existsSync()) return;
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      _isLoggedIn     = (j['isLoggedIn'] as bool?)        ?? false;
      _nickname       = (j['nickname']   as String?)       ?? '';
      _activeSlot     = (j['activeSlot'] as String?)       ?? 'sage';
      _memoFont       = (j['memoFont']   as String?)       ?? 'gaegu';
      _themeIntensity = ((j['themeIntensity'] as num?)     ?? 1.0).toDouble();
      _exportFormat   = (j['exportFormat'] as String?)     ?? 'csv';
      _reminderEnabled= (j['reminderEnabled'] as bool?)    ?? false;

      final tmIdx = (j['themeMode'] as int?) ?? 0;
      _themeMode  = AppThemeMode.values[tmIdx.clamp(0, AppThemeMode.values.length - 1)];

      if (j['highlightSlotOrder'] != null) {
        _highlightSlotOrder = List<String>.from(j['highlightSlotOrder'] as List);
      }
      if (j['reminderDays'] != null) {
        _reminderDays = Set<int>.from(j['reminderDays'] as List);
      }

      _reminderStartTime = TimeOfDay(
        hour:   (j['reminderStartHour']   as int?) ?? 9,
        minute: (j['reminderStartMinute'] as int?) ?? 0,
      );
      _reminderEndTime = TimeOfDay(
        hour:   (j['reminderEndHour']   as int?) ?? 21,
        minute: (j['reminderEndMinute'] as int?) ?? 0,
      );

      if (j['books'] != null) {
        _books = (j['books'] as List)
            .map((e) => Book.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (j['highlights'] != null) {
        _highlights = (j['highlights'] as List)
            .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  /// 상태 변경 시 자동 호출 (디바운스 500ms)
  Future<void> _saveState() async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_state.json');
      await file.writeAsString(jsonEncode({
        'isLoggedIn':          _isLoggedIn,
        'nickname':            _nickname,
        'activeSlot':          _activeSlot,
        'themeMode':           _themeMode.index,
        'memoFont':            _memoFont,
        'themeIntensity':      _themeIntensity,
        'exportFormat':        _exportFormat,
        'highlightSlotOrder':  _highlightSlotOrder,
        'reminderEnabled':     _reminderEnabled,
        'reminderDays':        _reminderDays.toList(),
        'reminderStartHour':   _reminderStartTime.hour,
        'reminderStartMinute': _reminderStartTime.minute,
        'reminderEndHour':     _reminderEndTime.hour,
        'reminderEndMinute':   _reminderEndTime.minute,
        'books':               _books.map((b) => b.toJson()).toList(),
        'highlights':          _highlights.map((h) => h.toJson()).toList(),
      }));
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveState);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
