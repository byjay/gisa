import 'dart:math' as math;

/// 계산기 입력 필드 정의
class CalcField {
  final String key;
  final String label; // 표시명
  final String unit; // 단위
  final double defaultValue;
  const CalcField(this.key, this.label, this.unit, this.defaultValue);
}

/// 계산 결과 한 줄
class CalcResult {
  final String label;
  final String value;
  final String unit;
  const CalcResult(this.label, this.value, this.unit);
}

/// 공식 계산기 하나
class FormulaCalc {
  final String id;
  final String title; // 예: 옴의 법칙
  final String category; // 그룹 (직류/교류/전력/실기 등)
  final String formula; // 표시 수식
  final String desc; // 설명
  final List<CalcField> fields;
  final List<CalcResult> Function(Map<String, double>) compute;
  const FormulaCalc({
    required this.id,
    required this.title,
    required this.category,
    required this.formula,
    required this.desc,
    required this.fields,
    required this.compute,
  });
}

String _f(double v, [int d = 4]) {
  if (v.isNaN || v.isInfinite) return '-';
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// 전기기사 & 소방설비기사 공식 계산기 모음
class FormulaCalculators {
  FormulaCalculators._();

  // ═══════════════ 전기(공통·전기기사) ═══════════════
  static final List<FormulaCalc> electrical = [
    FormulaCalc(
      id: 'ohm',
      title: '옴의 법칙 (V=IR)',
      category: '직류·기초',
      formula: 'V = I × R,  I = V/R,  R = V/I',
      desc: '전압·전류·저항 중 두 값을 입력하면 나머지를 계산합니다.',
      fields: const [
        CalcField('V', '전압 V', 'V', 220),
        CalcField('I', '전류 I', 'A', 0),
        CalcField('R', '저항 R', 'Ω', 10),
      ],
      compute: (m) {
        final v = m['V']!, i = m['I']!, r = m['R']!;
        final out = <CalcResult>[];
        if (i == 0 && v != 0 && r != 0) {
          out.add(CalcResult('전류 I', _f(v / r), 'A'));
          out.add(CalcResult('전력 P', _f(v * v / r), 'W'));
        } else if (v == 0 && i != 0 && r != 0) {
          out.add(CalcResult('전압 V', _f(i * r), 'V'));
          out.add(CalcResult('전력 P', _f(i * i * r), 'W'));
        } else if (r == 0 && v != 0 && i != 0) {
          out.add(CalcResult('저항 R', _f(v / i), 'Ω'));
          out.add(CalcResult('전력 P', _f(v * i), 'W'));
        } else {
          out.add(CalcResult('전력 P', _f(v * i), 'W'));
          if (i != 0) out.add(CalcResult('저항 R', _f(v / i), 'Ω'));
        }
        return out;
      },
    ),
    FormulaCalc(
      id: 'dc_power',
      title: '직류 전력 (P=VI)',
      category: '직류·기초',
      formula: 'P = V × I = I²R = V²/R',
      desc: '전압·전류로 전력·저항을 계산합니다.',
      fields: const [
        CalcField('V', '전압 V', 'V', 220),
        CalcField('I', '전류 I', 'A', 5),
      ],
      compute: (m) {
        final v = m['V']!, i = m['I']!;
        return [
          CalcResult('전력 P', _f(v * i), 'W'),
          CalcResult('전력 P', _f(v * i / 1000), 'kW'),
          if (i != 0) CalcResult('저항 R', _f(v / i), 'Ω'),
        ];
      },
    ),
    FormulaCalc(
      id: 'ac_single_power',
      title: '단상 교류 전력',
      category: '교류·전력',
      formula: 'P = V·I·cosθ,  S = V·I,  Q = V·I·sinθ',
      desc: '단상 유효/피상/무효 전력을 역률로 계산합니다.',
      fields: const [
        CalcField('V', '전압 V', 'V', 220),
        CalcField('I', '전류 I', 'A', 10),
        CalcField('pf', '역률 cosθ', '0~1', 0.8),
      ],
      compute: (m) {
        final v = m['V']!, i = m['I']!, pf = m['pf']!.clamp(0, 1);
        final s = v * i;
        final p = s * pf;
        final q = s * math.sqrt(1 - pf * pf);
        return [
          CalcResult('유효전력 P', _f(p), 'W'),
          CalcResult('피상전력 S', _f(s), 'VA'),
          CalcResult('무효전력 Q', _f(q), 'var'),
        ];
      },
    ),
    FormulaCalc(
      id: 'ac_three_power',
      title: '3상 교류 전력',
      category: '교류·전력',
      formula: 'P = √3·V·I·cosθ',
      desc: '3상 선간전압·선전류·역률로 3상 전력을 계산합니다.',
      fields: const [
        CalcField('V', '선간전압 V', 'V', 380),
        CalcField('I', '선전류 I', 'A', 20),
        CalcField('pf', '역률 cosθ', '0~1', 0.85),
      ],
      compute: (m) {
        final v = m['V']!, i = m['I']!, pf = m['pf']!.clamp(0, 1);
        final root3 = math.sqrt(3);
        final s = root3 * v * i;
        final p = s * pf;
        final q = s * math.sqrt(1 - pf * pf);
        return [
          CalcResult('유효전력 P', _f(p), 'W'),
          CalcResult('유효전력 P', _f(p / 1000), 'kW'),
          CalcResult('피상전력 S', _f(s / 1000), 'kVA'),
          CalcResult('무효전력 Q', _f(q / 1000), 'kvar'),
        ];
      },
    ),
    FormulaCalc(
      id: 'three_phase_current',
      title: '3상 부하 선전류',
      category: '교류·전력',
      formula: 'I = P / (√3·V·cosθ)',
      desc: '3상 부하 소비전력·전압·역률로 선전류를 구합니다.',
      fields: const [
        CalcField('P', '소비전력 P', 'W', 15000),
        CalcField('V', '선간전압 V', 'V', 380),
        CalcField('pf', '역률 cosθ', '0~1', 0.85),
      ],
      compute: (m) {
        final p = m['P']!, v = m['V']!, pf = m['pf']!.clamp(0.01, 1);
        final i = p / (math.sqrt(3) * v * pf);
        return [CalcResult('선전류 I', _f(i), 'A')];
      },
    ),
    FormulaCalc(
      id: 'pf_correction',
      title: '역률 개선 콘덴서 용량',
      category: '교류·전력',
      formula: 'Qc = P(tanθ₁ − tanθ₂)',
      desc: '역률을 개선할 때 필요한 전력용 콘덴서 용량을 계산합니다.',
      fields: const [
        CalcField('P', '유효전력 P', 'kW', 200),
        CalcField('pf1', '개선 전 역률', '0~1', 0.6),
        CalcField('pf2', '개선 후 역률', '0~1', 0.9),
      ],
      compute: (m) {
        final p = m['P']!;
        final pf1 = m['pf1']!.clamp(0.01, 1).toDouble();
        final pf2 = m['pf2']!.clamp(0.01, 1).toDouble();
        double tan(double pf) => math.sqrt(1 - pf * pf) / pf;
        final qc = p * (tan(pf1) - tan(pf2));
        return [CalcResult('필요 콘덴서 용량 Qc', _f(qc), 'kVA')];
      },
    ),
    FormulaCalc(
      id: 'voltage_drop',
      title: '전압강하 (배선)',
      category: '전력·배선',
      formula: '단상2선 e=35.6LI/1000A · 3상3선 e=30.8LI/1000A',
      desc: '전선 길이·전류·단면적으로 전압강하를 계산합니다.',
      fields: const [
        CalcField('L', '배선 길이 L', 'm', 100),
        CalcField('I', '부하전류 I', 'A', 50),
        CalcField('A', '전선 단면적 A', 'mm²', 16),
        CalcField('type', '방식(1:단상2선 2:3상3선 3:단상3선/3상4선)', '', 2),
      ],
      compute: (m) {
        final l = m['L']!, i = m['I']!, a = m['A']!.clamp(0.01, 1e9);
        final t = m['type']!.round();
        double k;
        String name;
        if (t == 1) {
          k = 35.6;
          name = '단상 2선식';
        } else if (t == 3) {
          k = 17.8;
          name = '단상 3선식/3상 4선식';
        } else {
          k = 30.8;
          name = '3상 3선식';
        }
        final e = k * l * i / (1000 * a);
        return [CalcResult('방식', name, ''), CalcResult('전압강하 e', _f(e), 'V')];
      },
    ),
    FormulaCalc(
      id: 'short_circuit',
      title: '단락전류·단락용량 (%Z)',
      category: '전력·배선',
      formula: 'Ps=(100/%Z)·Pn,  Is=Ps/(√3·V)',
      desc: '기준용량·%임피던스로 단락용량과 단락전류를 계산합니다.',
      fields: const [
        CalcField('Pn', '기준용량 Pn', 'MVA', 10),
        CalcField('Z', '%임피던스 %Z', '%', 8),
        CalcField('V', '정격전압 V', 'kV', 6.6),
      ],
      compute: (m) {
        final pn = m['Pn']!, z = m['Z']!.clamp(0.01, 1e9), v = m['V']!;
        final ps = 100 / z * pn; // MVA
        final is_ = ps * 1e6 / (math.sqrt(3) * v * 1000); // A
        return [
          CalcResult('단락용량 Ps', _f(ps), 'MVA'),
          CalcResult('단락전류 Is', _f(is_), 'A'),
          CalcResult('단락전류 Is', _f(is_ / 1000), 'kA'),
        ];
      },
    ),
    FormulaCalc(
      id: 'transformer_reg',
      title: '변압기 전압변동률',
      category: '전기기기',
      formula: 'ε = p·cosθ ± q·sinθ (지상+/진상−)',
      desc: '%저항·%리액턴스·역률로 전압변동률을 계산합니다.',
      fields: const [
        CalcField('p', '%저항 p', '%', 1.5),
        CalcField('q', '%리액턴스 q', '%', 4),
        CalcField('pf', '역률 cosθ', '0~1', 0.8),
        CalcField('lead', '위상(0:지상 1:진상)', '', 0),
      ],
      compute: (m) {
        final p = m['p']!, q = m['q']!, pf = m['pf']!.clamp(0, 1);
        final sin = math.sqrt(1 - pf * pf);
        final lead = m['lead']!.round() == 1;
        final eps = p * pf + (lead ? -1 : 1) * q * sin;
        final epsMax = math.sqrt(p * p + q * q);
        return [
          CalcResult('전압변동률 ε', _f(eps), '%'),
          CalcResult('최대 전압변동률', _f(epsMax), '%'),
        ];
      },
    ),
    FormulaCalc(
      id: 'lighting',
      title: '조명 소요등수 (광속법)',
      category: '전기응용',
      formula: 'N = (E·A)/(F·U·M)',
      desc: '조도·면적·광속·조명률·보수율로 필요한 등기구 수를 계산합니다.',
      fields: const [
        CalcField('E', '평균조도 E', 'lx', 500),
        CalcField('A', '면적 A', 'm²', 200),
        CalcField('F', '1등 광속 F', 'lm', 5000),
        CalcField('U', '조명률 U', '0~1', 0.6),
        CalcField('M', '보수율 M', '0~1', 0.8),
      ],
      compute: (m) {
        final e = m['E']!, a = m['A']!, f = m['F']!.clamp(0.01, 1e9);
        final u = m['U']!.clamp(0.01, 1), mm = m['M']!.clamp(0.01, 1);
        final n = e * a / (f * u * mm);
        return [
          CalcResult('필요 등수 N', _f(n, 2), '등'),
          CalcResult('올림 적용', n.ceil().toString(), '등'),
        ];
      },
    ),
  ];

  // ═══════════════ 소방설비기사(전기) ═══════════════
  static final List<FormulaCalc> fire = [
    FormulaCalc(
      id: 'battery',
      title: '축전지(비상전원) 용량',
      category: '비상전원',
      formula: 'C = (1/L)·K·I',
      desc: '방전전류·용량환산시간·보수율로 축전지 용량을 계산합니다.',
      fields: const [
        CalcField('I', '방전전류 I', 'A', 20),
        CalcField('K', '용량환산시간 K', '', 1.2),
        CalcField('L', '보수율 L', '0~1', 0.8),
      ],
      compute: (m) {
        final i = m['I']!, k = m['K']!, l = m['L']!.clamp(0.01, 1);
        final c = 1 / l * k * i;
        return [CalcResult('축전지 용량 C', _f(c), 'Ah')];
      },
    ),
    FormulaCalc(
      id: 'detector',
      title: '감지기 설치 개수',
      category: '자동화재탐지',
      formula: 'N = 바닥면적 / 기준면적 (올림)',
      desc: '바닥면적을 감지기 종별 기준면적으로 나눠 개수를 계산합니다.',
      fields: const [
        CalcField('area', '바닥면적', 'm²', 800),
        CalcField('std', '기준면적(내화4m미만 차동2종=70)', 'm²', 70),
      ],
      compute: (m) {
        final a = m['area']!, s = m['std']!.clamp(0.01, 1e9);
        final n = a / s;
        final zones = (a / 600).ceil();
        return [
          CalcResult('감지기 개수', n.ceil().toString(), '개'),
          CalcResult('계산값', _f(n, 2), '개'),
          CalcResult('경계구역(600㎡ 기준)', zones.toString(), '개'),
        ];
      },
    ),
    FormulaCalc(
      id: 'zone',
      title: '경계구역 수',
      category: '자동화재탐지',
      formula: '하나의 경계구역 600㎡·한변 50m 이하',
      desc: '바닥면적으로 필요한 경계구역 수를 계산합니다.',
      fields: const [CalcField('area', '바닥면적', 'm²', 1500)],
      compute: (m) {
        final a = m['area']!;
        return [CalcResult('경계구역 수', (a / 600).ceil().toString(), '개')];
      },
    ),
    FormulaCalc(
      id: 'heat',
      title: '전열기 가열 시간',
      category: '전열·에너지',
      formula: 'Q=c·m·Δθ,  t=Q/(P·η)',
      desc: '물 가열에 필요한 열량과 시간을 계산합니다.',
      fields: const [
        CalcField('m', '질량(물) m', 'kg', 20),
        CalcField('dt', '온도차 Δθ', '℃', 80),
        CalcField('P', '전열기 용량 P', 'kW', 3),
        CalcField('eff', '효율 η', '0~1', 0.8),
      ],
      compute: (m) {
        final mass = m['m']!, dt = m['dt']!;
        final p = m['P']!.clamp(0.01, 1e9), eff = m['eff']!.clamp(0.01, 1);
        final q = 4.2 * mass * dt; // kJ
        final t = q / (p * eff); // s
        return [
          CalcResult('필요 열량 Q', _f(q), 'kJ'),
          CalcResult('가열 시간', _f(t), '초'),
          CalcResult('가열 시간', _f(t / 60, 2), '분'),
        ];
      },
    ),
    FormulaCalc(
      id: 'wire_area',
      title: '전선관 굵기 (점유율)',
      category: '배선·시공',
      formula: '3본↓ 48% · 4본↑ 32% 이하',
      desc: '전선 단면적·가닥수·점유율로 필요한 관 내단면적을 계산합니다.',
      fields: const [
        CalcField('sa', '전선1본 피복포함 단면적', 'mm²', 13),
        CalcField('n', '가닥수', '본', 6),
      ],
      compute: (m) {
        final sa = m['sa']!, n = m['n']!;
        final ratio = n <= 3 ? 0.48 : 0.32;
        final total = sa * n;
        final need = total / ratio;
        return [
          CalcResult('전선 총단면적', _f(total), 'mm²'),
          CalcResult('적용 점유율', '${(ratio * 100).round()}', '%'),
          CalcResult('필요 관 내단면적', _f(need), 'mm²'),
        ];
      },
    ),
    FormulaCalc(
      id: 'faraday',
      title: '패러데이 전기분해 (석출량)',
      category: '전기화학',
      formula: 'W = k·I·t (k:전기화학당량)',
      desc: '전기화학당량·전류·시간으로 석출량을 계산합니다.',
      fields: const [
        CalcField('k', '전기화학당량 k', 'g/C', 0.000329),
        CalcField('I', '전류 I', 'A', 10),
        CalcField('t', '시간 t', '초', 3600),
      ],
      compute: (m) {
        final k = m['k']!, i = m['I']!, t = m['t']!;
        return [CalcResult('석출량 W', _f(k * i * t), 'g')];
      },
    ),
  ];
}
