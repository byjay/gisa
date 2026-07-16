import 'dart:math' as math;

/// 단위 하나 — 표시 기호와 SI 기준값으로의 변환 계수(factor)
/// value_in_base = value * factor  (선형 단위)
/// 온도처럼 비선형은 별도 함수 사용
class ConvUnit {
  final String symbol; // 표시 기호 (Ω, kΩ ...)
  final String name; // 한글 이름
  final double factor; // 기준단위 대비 배수 (선형 단위만)
  const ConvUnit(this.symbol, this.name, this.factor);
}

/// 변환 카테고리
class ConvCategory {
  final String id;
  final String title; // 메뉴 표시명
  final String iconText; // 원형 아이콘 안 글자 (A, V, R ...)
  final List<ConvUnit> units;
  final int defaultFrom;
  final int defaultTo;
  final bool isTemperature; // 온도(비선형) 특수 처리
  const ConvCategory({
    required this.id,
    required this.title,
    required this.iconText,
    required this.units,
    this.defaultFrom = 0,
    this.defaultTo = 1,
    this.isTemperature = false,
  });
}

/// 단위 환산 엔진 — 첨부 앱의 13개 카테고리 전부 반영 + 전기/실무 확장
class UnitConverter {
  UnitConverter._();

  /// 선형 변환: from 단위값 → to 단위값
  static double convert(ConvCategory cat, int fromIdx, int toIdx, double value) {
    if (cat.isTemperature) {
      return _convertTemp(
          cat.units[fromIdx].symbol, cat.units[toIdx].symbol, value);
    }
    final base = value * cat.units[fromIdx].factor; // → 기준단위
    return base / cat.units[toIdx].factor; // → 목표단위
  }

  /// 특정 from 값 기준, 모든 단위로의 변환 결과 리스트
  static List<({ConvUnit unit, double value})> convertAll(
      ConvCategory cat, int fromIdx, double value) {
    return List.generate(cat.units.length, (i) {
      return (unit: cat.units[i], value: convert(cat, fromIdx, i, value));
    });
  }

  // ─── 온도 변환 (비선형) ───
  static double _toKelvin(String sym, double v) {
    switch (sym) {
      case 'K':
        return v;
      case '°C':
        return v + 273.15;
      case '°F':
        return (v - 32) * 5 / 9 + 273.15;
      case '°R': // Rankine
        return v * 5 / 9;
      case '°r': // Réaumur
        return v * 5 / 4 + 273.15;
      case 'Triple pt': // 물의 삼중점(273.16K) 기준 배수
        return v * 273.16;
      default:
        return v;
    }
  }

  static double _fromKelvin(String sym, double k) {
    switch (sym) {
      case 'K':
        return k;
      case '°C':
        return k - 273.15;
      case '°F':
        return (k - 273.15) * 9 / 5 + 32;
      case '°R':
        return k * 9 / 5;
      case '°r':
        return (k - 273.15) * 4 / 5;
      case 'Triple pt':
        return k / 273.16;
      default:
        return k;
    }
  }

  static double _convertTemp(String from, String to, double v) =>
      _fromKelvin(to, _toKelvin(from, v));

  /// 숫자를 앱 스타일로 포맷 (아주 크거나 작으면 지수표기)
  static String fmt(double v) {
    if (v == 0) return '0';
    if (v.isNaN || v.isInfinite) return '-';
    final abs = v.abs();
    if (abs >= 1e6 || abs < 1e-4) {
      // 지수 표기 1.0×10⁶ 형태
      final exp = (math.log(abs) / math.ln10).floor();
      final mant = v / math.pow(10, exp);
      final mantStr = _trim(mant, 4);
      return '$mantStr×10${_superscript(exp)}';
    }
    return _trim(v, 6);
  }

  static String _trim(double v, int maxDecimals) {
    var s = v.toStringAsFixed(maxDecimals);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  static String _superscript(int n) {
    const map = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻'
    };
    return n.toString().split('').map((c) => map[c] ?? c).join();
  }

  // ══════════════════════════════════════════════════════
  // 13개 카테고리 정의 (첨부 앱 전부 + 정확한 계수)
  // ══════════════════════════════════════════════════════
  static final List<ConvCategory> categories = [
    // 1. 전류 (Current)
    const ConvCategory(id: 'current', title: '전류 단위 변환', iconText: 'A', units: [
      ConvUnit('A', '암페어', 1),
      ConvUnit('kA', '킬로암페어', 1e3),
      ConvUnit('mA', '밀리암페어', 1e-3),
      ConvUnit('μA', '마이크로암페어', 1e-6),
      ConvUnit('nA', '나노암페어', 1e-9),
    ]),
    // 2. 전압 (Voltage)
    const ConvCategory(id: 'voltage', title: '전압 단위 변환', iconText: 'V', units: [
      ConvUnit('V', '볼트', 1),
      ConvUnit('kV', '킬로볼트', 1e3),
      ConvUnit('MV', '메가볼트', 1e6),
      ConvUnit('mV', '밀리볼트', 1e-3),
      ConvUnit('μV', '마이크로볼트', 1e-6),
    ]),
    // 3. 저항 (Resistance) — 스크린샷과 동일 순서
    const ConvCategory(id: 'resistance', title: '저항 단위 변환', iconText: 'R', units: [
      ConvUnit('Ω', '옴', 1),
      ConvUnit('kΩ', '킬로옴', 1e3),
      ConvUnit('MΩ', '메가옴', 1e6),
      ConvUnit('GΩ', '기가옴', 1e9),
      ConvUnit('mΩ', '밀리옴', 1e-3),
      ConvUnit('μΩ', '마이크로옴', 1e-6),
      ConvUnit('nΩ', '나노옴', 1e-9),
      ConvUnit('pΩ', '피코옴', 1e-12),
    ]),
    // 4. 온도 (Temperature) — 비선형
    const ConvCategory(
        id: 'temperature',
        title: '온도 단위 변환',
        iconText: 'T',
        isTemperature: true,
        units: [
          ConvUnit('K', '켈빈', 1),
          ConvUnit('°C', '섭씨', 1),
          ConvUnit('°F', '화씨', 1),
          ConvUnit('°R', '랭킨', 1),
          ConvUnit('°r', '열씨(레오뮈르)', 1),
          ConvUnit('Triple pt', '삼중점', 1),
        ]),
    // 5. 데이터 (Data)
    const ConvCategory(id: 'data', title: '데이터 단위 변환', iconText: 'Byte', units: [
      ConvUnit('B', '바이트', 1),
      ConvUnit('KB', '킬로바이트', 1024),
      ConvUnit('MB', '메가바이트', 1024.0 * 1024),
      ConvUnit('GB', '기가바이트', 1024.0 * 1024 * 1024),
      ConvUnit('TB', '테라바이트', 1024.0 * 1024 * 1024 * 1024),
      ConvUnit('bit', '비트', 1 / 8),
      ConvUnit('Kb', '킬로비트', 1024 / 8),
      ConvUnit('Mb', '메가비트', 1024.0 * 1024 / 8),
    ]),
    // 6. 에너지 (Energy)
    const ConvCategory(id: 'energy', title: '에너지 단위 변환', iconText: 'E', units: [
      ConvUnit('J', '줄', 1),
      ConvUnit('kJ', '킬로줄', 1e3),
      ConvUnit('cal', '칼로리', 4.184),
      ConvUnit('kcal', '킬로칼로리', 4184),
      ConvUnit('Wh', '와트시', 3600),
      ConvUnit('kWh', '킬로와트시', 3.6e6),
      ConvUnit('eV', '전자볼트', 1.602176634e-19),
      ConvUnit('BTU', '영국열량단위', 1055.06),
    ]),
    // 7. 각도 (Angle)
    ConvCategory(id: 'angle', title: '각도 단위 변환', iconText: 'θ', units: [
      const ConvUnit('°', '도', 1),
      ConvUnit('rad', '라디안', 180 / math.pi),
      ConvUnit('grad', '그라드', 0.9),
      const ConvUnit('′', '분(arcmin)', 1 / 60),
      const ConvUnit('″', '초(arcsec)', 1 / 3600),
      const ConvUnit('rev', '회전', 360),
    ]),
    // 8. 면적 (Area) — 스크린샷과 동일
    const ConvCategory(id: 'area', title: '면적 단위 변환', iconText: 'm²', units: [
      ConvUnit('m²', '제곱미터', 1),
      ConvUnit('mm²', '제곱밀리미터', 1e-6),
      ConvUnit('cm²', '제곱센티미터', 1e-4),
      ConvUnit('in²', '제곱인치', 0.00064516),
      ConvUnit('ft²', '제곱피트', 0.09290304),
      ConvUnit('yd²', '제곱야드', 0.83612736),
      ConvUnit('acre', '에이커', 4046.8564224),
      ConvUnit('kanal', '카날', 505.857),
      ConvUnit('marla', '마를라', 25.2929),
      ConvUnit('km²', '제곱킬로미터', 1e6),
      ConvUnit('ha', '헥타르', 1e4),
      ConvUnit('평', '평', 3.305785),
    ]),
    // 9. 전력 (Power)
    const ConvCategory(id: 'power', title: '전력 단위 변환', iconText: 'P', units: [
      ConvUnit('W', '와트', 1),
      ConvUnit('kW', '킬로와트', 1e3),
      ConvUnit('MW', '메가와트', 1e6),
      ConvUnit('mW', '밀리와트', 1e-3),
      ConvUnit('HP', '마력(전기)', 746),
      ConvUnit('PS', '마력(미터)', 735.49875),
      ConvUnit('VA', '피상전력', 1),
      ConvUnit('kVA', '킬로볼트암페어', 1e3),
    ]),
    // 10. 힘 (Force)
    const ConvCategory(id: 'force', title: '힘 단위 변환', iconText: 'F', units: [
      ConvUnit('N', '뉴턴', 1),
      ConvUnit('kN', '킬로뉴턴', 1e3),
      ConvUnit('kgf', '중량킬로그램', 9.80665),
      ConvUnit('gf', '중량그램', 0.00980665),
      ConvUnit('dyn', '다인', 1e-5),
      ConvUnit('lbf', '파운드힘', 4.4482216153),
    ]),
    // 11. 연료 (Fuel efficiency) — km/L 기준
    const ConvCategory(id: 'fuel', title: '연료 단위 변환', iconText: 'Fu', units: [
      ConvUnit('km/L', '킬로미터/리터', 1),
      ConvUnit('L/100km', '리터/100km', -1), // 역수 관계는 근사표기(별도 안내)
      ConvUnit('mpg(US)', '마일/갤런(미)', 0.425143707),
      ConvUnit('mpg(UK)', '마일/갤런(영)', 0.354006042),
      ConvUnit('mi/L', '마일/리터', 1.609344),
    ]),
    // 12. 길이 (Length)
    const ConvCategory(id: 'length', title: '길이 단위 변환', iconText: 'm', units: [
      ConvUnit('m', '미터', 1),
      ConvUnit('km', '킬로미터', 1e3),
      ConvUnit('cm', '센티미터', 1e-2),
      ConvUnit('mm', '밀리미터', 1e-3),
      ConvUnit('μm', '마이크로미터', 1e-6),
      ConvUnit('in', '인치', 0.0254),
      ConvUnit('ft', '피트', 0.3048),
      ConvUnit('yd', '야드', 0.9144),
      ConvUnit('mi', '마일', 1609.344),
      ConvUnit('mil', '밀(1/1000인치)', 0.0000254),
    ]),
    // 13. 압력 (Pressure)
    const ConvCategory(id: 'pressure', title: '압력 단위 변환', iconText: 'P', units: [
      ConvUnit('Pa', '파스칼', 1),
      ConvUnit('kPa', '킬로파스칼', 1e3),
      ConvUnit('MPa', '메가파스칼', 1e6),
      ConvUnit('bar', '바', 1e5),
      ConvUnit('atm', '기압', 101325),
      ConvUnit('mmHg', '수은주밀리미터', 133.322387415),
      ConvUnit('psi', '제곱인치당파운드', 6894.757293),
      ConvUnit('kgf/cm²', '중량kg/cm²', 98066.5),
    ]),
  ];

  /// 연료 효율의 역수 단위(L/100km) 특수 변환
  static double convertFuel(int fromIdx, int toIdx, double value) {
    final cat = categories.firstWhere((c) => c.id == 'fuel');
    // 기준: km/L. L/100km은 역수 관계
    double toKmPerL(int idx, double v) {
      final u = cat.units[idx];
      if (u.symbol == 'L/100km') return v == 0 ? double.infinity : 100 / v;
      return v * u.factor;
    }

    double fromKmPerL(int idx, double kmPerL) {
      final u = cat.units[idx];
      if (u.symbol == 'L/100km') {
        return kmPerL == 0 ? double.infinity : 100 / kmPerL;
      }
      return kmPerL / u.factor;
    }

    return fromKmPerL(toIdx, toKmPerL(fromIdx, value));
  }
}
