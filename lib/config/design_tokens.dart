import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ===== Color Matrices for Blue Light Filtering =====
// Rest Mode: 라이트 + 블루라이트 필터 (따뜻한 톤, 과하지 않게)
// Dark Mode: 다크 + 블루라이트 필터 (따뜻한 톤, 과하지 않게)

class DesignTokens {
  // 레스트 모드 색상 필터 (Light + 중성 톤다운)
  // 노란색 X, 대신 전체적으로 밝은 영역(흰색/파랑) 톤다운
  // Red: 95%, Green: 95%, Blue: 80% → 중성적이면서 눈이 편한 톤
  static const List<double> restModeMatrix = [
    0.95, 0,    0,    0, 0,
    0,    0.95, 0,    0, 0,
    0,    0,    0.80, 0, 0,
    0,    0,    0,    1, 0,
  ];

  // 다크 모드 색상 필터 (Dark + 밝은 영역 톤다운)
  // 파란색과 밝은 영역을 더 줄여서 눈 피로 감소
  // Red: 93%, Green: 90%, Blue: 65% → 따뜻하지 않으면서도 밝기 조절
  static const List<double> darkModeMatrix = [
    0.93, 0,    0,    0, 0,
    0,    0.90, 0,    0, 0,
    0,    0,    0.65, 0, 0,
    0,    0,    0,    1, 0,
  ];

  // Sepia Mode: 따뜻한 세피아 톤 (프리미엄 전용)
  static const List<double> sepiaModeMatrix = [
    0.94, 0.04, 0,    0, 0,
    0.02, 0.88, 0.02, 0, 0,
    0,    0.02, 0.52, 0, 0,
    0,    0,    0,    1, 0,
  ];

  // ===== Background (Light Mode) =====
  static const Color bgIvory     = Color(0xFFFFF7EE);
  static const Color bgIvoryDeep = Color(0xFFF6ECDC);
  static const Color bgIvoryEdge = Color(0xFFEADCC4);
  static const Color bgIvoryRow  = Color(0xFFF1E5D2);

  // ===== Background (Dark Mode) — 고급 우드 서재 톤 =====
  static const Color bgDark      = Color(0xFF2D2318); // 메인 배경 — 깊은 월넛 우드
  static const Color bgDarkDeep  = Color(0xFF3A2C1F); // 카드 배경 — 밝은 우드
  static const Color bgDarkEdge  = Color(0xFF4A3828); // 테두리 — 우드 그레인
  static const Color bgDarkRow   = Color(0xFF332518); // 행 배경

  // ===== Ink (Light Mode) =====
  static const Color ink      = Color(0xFF1C1612);
  static const Color inkSoft  = Color(0xFF3A2E26);
  static const Color inkMute  = Color(0xFF6E5C4E);
  static const Color inkFaint = Color(0xFFA8957F);

  // ===== Ink (Dark Mode) =====
  static const Color inkDark      = Color(0xFFF0E4D4); // 기본 텍스트 — 따뜻한 아이보리
  static const Color inkDarkSoft  = Color(0xFFD4C4B0); // 보조 텍스트
  static const Color inkDarkMute  = Color(0xFF9A8878); // 흐린 텍스트
  static const Color inkDarkFaint = Color(0xFF615550); // 아주 흐린 텍스트

  // ===== Rule lines (Light Mode) =====
  static const Color rule       = Color(0x191C1612); // ~10% ink
  static const Color ruleStrong = Color(0x381C1612); // ~22% ink

  // ===== Rule lines (Dark Mode) =====
  static const Color ruleDark       = Color(0xFF463420); // 다크 구분선
  static const Color ruleDarkStrong = Color(0xFF5A4430); // 다크 강한 구분선

  // ===== Accent =====
  static const Color sage      = Color(0xFF4A7B5E);
  static const Color sageDark  = Color(0xFF2E5442); // 다크모드 FAB — 우드 서재 톤의 깊은 세이지
  static const Color sageSoft  = Color(0xFF8FB89E);
  static const Color terracotta = Color(0xFFB85C38);
  static const Color amber     = Color(0xFF8A6523);
  static const Color walnut    = Color(0xFF5C3A21);

  // ===== Shelf =====
  static const Color shelfWood     = Color(0xFF7B5836);
  static const Color shelfWoodDark = Color(0xFF4A3320);

  // ===== Legacy aliases (used in existing code) =====
  static const Color ctaDark        = ink;
  static const Color highlightSlot1 = sageSoft;
  static const Color highlightSlot2 = terracotta;
  static const Color highlightSlot3 = amber;

  // ===== Slot helper =====
  static Color slotColor(String slot) {
    switch (slot) {
      case 'terra': return terracotta;
      case 'amber': return amber;
      default:      return sageSoft;
    }
  }

  // ===== Book color helper =====
  /// 책 팔레트 이름(navy/wine/…) → 대표 단색.
  /// 책 색상 표시는 slotColor가 아니라 이 함수를 사용해야 10색 전부 구분됨.
  static Color bookAccent(String color) {
    switch (color) {
      case 'terra':  return const Color(0xFFB05330);
      case 'amber':  return const Color(0xFF8A6523);
      case 'ink':    return const Color(0xFF2A2018);
      case 'navy':   return const Color(0xFF2E4870);
      case 'wine':   return const Color(0xFF8C2F4A);
      case 'forest': return const Color(0xFF24503A);
      case 'slate':  return const Color(0xFF45586A);
      case 'plum':   return const Color(0xFF5C2E72);
      case 'cognac': return const Color(0xFF7E4E2C);
      default:       return const Color(0xFF4A7B5E); // sage
    }
  }

  // ===== Cover gradients (Light) =====
  static LinearGradient coverGrad(String color) {
    switch (color) {
      case 'terra':   return const LinearGradient(colors: [Color(0xFFD88B68), Color(0xFFA85A38)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'amber':   return const LinearGradient(colors: [Color(0xFFC9A55C), Color(0xFF8A6523)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'ink':     return const LinearGradient(colors: [Color(0xFF4A3E36), Color(0xFF1C1612)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'navy':    return const LinearGradient(colors: [Color(0xFF3A5580), Color(0xFF1E3050)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'wine':    return const LinearGradient(colors: [Color(0xFFA03A5A), Color(0xFF6B2038)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'forest':  return const LinearGradient(colors: [Color(0xFF2A5C3E), Color(0xFF183828)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'slate':   return const LinearGradient(colors: [Color(0xFF4E6070), Color(0xFF2C3A46)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'plum':    return const LinearGradient(colors: [Color(0xFF6B3A7E), Color(0xFF42255A)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'cognac':  return const LinearGradient(colors: [Color(0xFF9A6540), Color(0xFF5E3A1E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:        return const LinearGradient(colors: [Color(0xFFB5D2BE), Color(0xFF7CA88E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  // ===== Cover gradients (Dark — 채도↓ 명도↓) =====
  static LinearGradient coverGradDark(String color) {
    switch (color) {
      case 'terra':   return const LinearGradient(colors: [Color(0xFF8A5038), Color(0xFF6A3422)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'amber':   return const LinearGradient(colors: [Color(0xFF7A6030), Color(0xFF523E14)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'ink':     return const LinearGradient(colors: [Color(0xFF302820), Color(0xFF1A1410)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'navy':    return const LinearGradient(colors: [Color(0xFF253A5A), Color(0xFF121E36)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'wine':    return const LinearGradient(colors: [Color(0xFF6C2840), Color(0xFF3E1020)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'forest':  return const LinearGradient(colors: [Color(0xFF1C3E2A), Color(0xFF0E2418)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'slate':   return const LinearGradient(colors: [Color(0xFF344050), Color(0xFF1C2630)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'plum':    return const LinearGradient(colors: [Color(0xFF482858), Color(0xFF28143A)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'cognac':  return const LinearGradient(colors: [Color(0xFF664228), Color(0xFF3C2010)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:        return const LinearGradient(colors: [Color(0xFF5A7A66), Color(0xFF3A5C4A)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  // ===== Spine gradients (Light) =====
  static LinearGradient spineGrad(String color) {
    switch (color) {
      case 'terra':   return const LinearGradient(colors: [Color(0xFFC26A45), Color(0xFF9C4A2C), Color(0xFFC26A45)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'amber':   return const LinearGradient(colors: [Color(0xFF9C7530), Color(0xFF6E4F18), Color(0xFF9C7530)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'ink':     return const LinearGradient(colors: [Color(0xFF3A2E26), Color(0xFF1C1612), Color(0xFF3A2E26)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'navy':    return const LinearGradient(colors: [Color(0xFF4A6898), Color(0xFF1E3050), Color(0xFF4A6898)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'wine':    return const LinearGradient(colors: [Color(0xFFB84E70), Color(0xFF6B2038), Color(0xFFB84E70)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'forest':  return const LinearGradient(colors: [Color(0xFF34704C), Color(0xFF183828), Color(0xFF34704C)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'slate':   return const LinearGradient(colors: [Color(0xFF607888), Color(0xFF2C3A46), Color(0xFF607888)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'plum':    return const LinearGradient(colors: [Color(0xFF7E4894), Color(0xFF42255A), Color(0xFF7E4894)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'cognac':  return const LinearGradient(colors: [Color(0xFFAE7650), Color(0xFF5E3A1E), Color(0xFFAE7650)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      default:        return const LinearGradient(colors: [Color(0xFF5E8E73), Color(0xFF3D6A4F), Color(0xFF5E8E73)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
  }

  // ===== Spine gradients (Dark — 채도↓ 명도↓) =====
  static LinearGradient spineGradDark(String color) {
    switch (color) {
      case 'terra':   return const LinearGradient(colors: [Color(0xFF7A4430), Color(0xFF5C2E1C), Color(0xFF7A4430)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'amber':   return const LinearGradient(colors: [Color(0xFF6A5020), Color(0xFF4A380E), Color(0xFF6A5020)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'ink':     return const LinearGradient(colors: [Color(0xFF2C2420), Color(0xFF181410), Color(0xFF2C2420)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'navy':    return const LinearGradient(colors: [Color(0xFF304070), Color(0xFF121E36), Color(0xFF304070)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'wine':    return const LinearGradient(colors: [Color(0xFF7A3050), Color(0xFF3E1020), Color(0xFF7A3050)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'forest':  return const LinearGradient(colors: [Color(0xFF224A30), Color(0xFF0E2418), Color(0xFF224A30)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'slate':   return const LinearGradient(colors: [Color(0xFF3E5060), Color(0xFF1C2630), Color(0xFF3E5060)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'plum':    return const LinearGradient(colors: [Color(0xFF5A306C), Color(0xFF28143A), Color(0xFF5A306C)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'cognac':  return const LinearGradient(colors: [Color(0xFF7A5030), Color(0xFF3C2010), Color(0xFF7A5030)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      default:        return const LinearGradient(colors: [Color(0xFF3E6050), Color(0xFF284838), Color(0xFF3E6050)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
  }

  // ===== Fonts =====
  static TextStyle solway(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.solway(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle solwayBold700(double size, [Color? color]) =>
      GoogleFonts.solway(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  static TextStyle ptSans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle ptSansRegular(double size, [Color? color]) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: FontWeight.w400, color: color ?? ink);

  static TextStyle ptSansBold(double size, [Color? color]) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  static TextStyle lora(double size, {bool italic = true, Color? color}) =>
      GoogleFonts.lora(fontSize: size, fontStyle: italic ? FontStyle.italic : FontStyle.normal, color: color ?? ink);

  static TextStyle hahmlet(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle hahmletRegular(double size, [Color? color]) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: FontWeight.w400, color: color ?? ink);

  static TextStyle hahmletBold(double size, [Color? color]) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  // 필기체 — 코멘트용 (라틴)
  static TextStyle caveat(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.caveat(fontSize: size, fontWeight: weight, color: color ?? ink);

  // 필기체 — 메모용 (한글+영문+숫자 모두 커버)
  static TextStyle nanumPen(double size, {Color? color}) =>
      GoogleFonts.nanumPenScript(fontSize: size, color: color ?? ink);

  // ── 메모/코멘트 폰트 선택 시스템 ──────────────────────────────────

  /// 스탠다드 이하 이용 가능 key 목록 (canUseFont에서 참조)
  static const Set<String> standardFontKeys = {
    'notoSansKr', 'ibmPlexSansKr', 'jua', 'doHyeon', 'blackHanSans',
    'nanumPenScript', 'gaegu', 'cuteFont', 'kirangHaerang', 'singleDay',
  };

  static const List<Map<String, String>> memoFontOptions = [
    // ── 고딕 (Standard 5종) ──
    {'key': 'notoSansKr',    'label': 'Noto Sans KR',   'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'ibmPlexSansKr', 'label': 'IBM Plex KR',    'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'jua',           'label': '주아체',            'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'doHyeon',       'label': '도현체',            'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'blackHanSans',  'label': 'Black Han Sans',  'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    // ── 필기체 (Standard 5종) ──
    {'key': 'nanumPenScript','label': '나눔펜스크립트',     'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'gaegu',         'label': '개구체',            'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'cuteFont',      'label': 'Cute Font',        'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'kirangHaerang', 'label': '키랑해랑',           'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'singleDay',     'label': 'Single Day',       'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    // ── 고딕+ (Premium only 5종) ──
    {'key': 'gugi',          'label': '구기체',            'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'gowunDodum',    'label': '고운돋움',           'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'sunflower',     'label': 'Sunflower',         'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'nanumGothic',   'label': '나눔고딕',           'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'gothicA1',      'label': 'Gothic A1',         'category': '고딕',    'preview': '기록하는 삶 Aa 123'},
    // ── 명조 (Premium only 3종) ──
    {'key': 'nanumMyeongjo', 'label': '나눔명조',           'category': '명조',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'gowunBatang',   'label': '고운바탕',           'category': '명조',    'preview': '기록하는 삶 Aa 123'},
    {'key': 'notoSerifKr',   'label': 'Noto Serif KR',    'category': '명조',    'preview': '기록하는 삶 Aa 123'},
    // ── 필기체+ (Premium only 4종) ──
    {'key': 'nanumBrushScript','label':'나눔붓스크립트',     'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'yeonSung',      'label': '연성체',             'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'hiMelody',      'label': 'Hi Melody',         'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    {'key': 'dokdo',         'label': 'Dokdo',             'category': '필기체',  'preview': '기록하는 삶 Aa 123'},
    // ── Serif 영문 (Premium only 4종) ──
    {'key': 'lora',          'label': 'Lora',              'category': 'Serif',   'preview': 'Reading Life Aa 123'},
    {'key': 'merriweather',  'label': 'Merriweather',      'category': 'Serif',   'preview': 'Reading Life Aa 123'},
    {'key': 'playfairDisplay','label':'Playfair Display',  'category': 'Serif',   'preview': 'Reading Life Aa 123'},
    {'key': 'ebGaramond',    'label': 'EB Garamond',       'category': 'Serif',   'preview': 'Reading Life Aa 123'},
  ];

  /// fontKey로 메모/코멘트 TextStyle 반환
  static TextStyle memoStyle(String fontKey, double size, {Color? color}) {
    final c = color ?? ink;
    final ls = fontKey == 'gaegu' ? size * -0.1 : 0.0; // 개구체만 자간 -10%
    switch (fontKey) {
      // ── Standard 고딕 ──
      case 'ibmPlexSansKr':    return GoogleFonts.ibmPlexSansKr(fontSize: size, color: c);
      case 'jua':              return GoogleFonts.jua(fontSize: size, color: c);
      case 'doHyeon':          return GoogleFonts.doHyeon(fontSize: size, color: c);
      case 'blackHanSans':     return GoogleFonts.blackHanSans(fontSize: size, color: c);
      // ── Standard 필기체 ──
      case 'nanumPenScript':   return GoogleFonts.nanumPenScript(fontSize: size, color: c);
      case 'gaegu':            return GoogleFonts.gaegu(fontSize: size, color: c)
                                   .copyWith(letterSpacing: ls);
      case 'cuteFont':         return GoogleFonts.cuteFont(fontSize: size, color: c);
      case 'kirangHaerang':    return GoogleFonts.kirangHaerang(fontSize: size, color: c);
      case 'singleDay':        return GoogleFonts.singleDay(fontSize: size, color: c);
      // ── Premium 고딕+ ──
      case 'gugi':             return GoogleFonts.gugi(fontSize: size, color: c);
      case 'gowunDodum':       return GoogleFonts.gowunDodum(fontSize: size, color: c);
      case 'sunflower':        return GoogleFonts.sunflower(fontSize: size, color: c);
      case 'nanumGothic':      return GoogleFonts.nanumGothic(fontSize: size, color: c);
      case 'gothicA1':         return GoogleFonts.gothicA1(fontSize: size, color: c);
      // ── Premium 명조 ──
      case 'nanumMyeongjo':    return GoogleFonts.nanumMyeongjo(fontSize: size, color: c);
      case 'gowunBatang':      return GoogleFonts.gowunBatang(fontSize: size, color: c);
      case 'notoSerifKr':      return GoogleFonts.notoSerifKr(fontSize: size, color: c);
      // ── Premium 필기체+ ──
      case 'nanumBrushScript': return GoogleFonts.nanumBrushScript(fontSize: size, color: c);
      case 'yeonSung':         return GoogleFonts.yeonSung(fontSize: size, color: c);
      case 'hiMelody':         return GoogleFonts.hiMelody(fontSize: size, color: c);
      case 'dokdo':            return GoogleFonts.dokdo(fontSize: size, color: c);
      // ── Premium Serif 영문 ──
      case 'lora':             return GoogleFonts.lora(fontSize: size, color: c);
      case 'merriweather':     return GoogleFonts.merriweather(fontSize: size, color: c);
      case 'playfairDisplay':  return GoogleFonts.playfairDisplay(fontSize: size, color: c);
      case 'ebGaramond':       return GoogleFonts.ebGaramond(fontSize: size, color: c);
      // ── 기본 ──
      default:                 return GoogleFonts.notoSansKr(fontSize: size, color: c);
    }
  }

  // ===== Spacing =====
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ===== Dark Mode Helpers =====
  static Color bgColor(bool isDark) => isDark ? bgDark : bgIvory;
  static Color bgColorDeep(bool isDark) => isDark ? bgDarkDeep : bgIvoryDeep;
  static Color bgColorEdge(bool isDark) => isDark ? bgDarkEdge : bgIvoryEdge;
  static Color bgColorRow(bool isDark) => isDark ? bgDarkRow : bgIvoryRow;

  static Color textColor(bool isDark) => isDark ? inkDark : ink;
  static Color textColorSoft(bool isDark) => isDark ? inkDarkSoft : inkSoft;
  static Color textColorMute(bool isDark) => isDark ? inkDarkMute : inkMute;
  static Color textColorFaint(bool isDark) => isDark ? inkDarkFaint : inkFaint;

  static Color ruleColor(bool isDark) => isDark ? ruleDark : rule;
  static Color ruleColorStrong(bool isDark) => isDark ? ruleDarkStrong : ruleStrong;
}
