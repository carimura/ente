import 'dart:collection';

class PartialDate {
  final int? day;
  final int? month;
  final int? year;

  const PartialDate({this.day, this.month, this.year});

  static const empty = PartialDate();

  bool get isEmpty => day == null && month == null && year == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartialDate &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => day.hashCode ^ month.hashCode ^ year.hashCode;

  @override
  String toString() {
    return 'PartialDate(day: $day, month: $month, year: $year)';
  }
}

class DateParseService {
  static final DateParseService instance = DateParseService._private();
  DateParseService._private();

  static const int _MIN_YEAR = 1900;
  static const int _MAX_YEAR = 2100;
  static const int _TWO_DIGIT_YEAR_PIVOT = 50;

  static final _ordinalRegex = RegExp(r'\b(\d{1,2})(st|nd|rd|th)\b');
  static final _normalizeRegex = RegExp(r'\bof\b|[,\.]+|\s+');
  static final _isoFormatRegex =
      RegExp(r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$');
  static final _standardFormatRegex =
      RegExp(r'^(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})$');
  static final _dotFormatRegex = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$');
  static final _compactFormatRegex = RegExp(r'^(\d{8})$');
  static final _yearOnlyRegex = RegExp(r'^\s*(\d{4})\s*$');
  static final _shortFormatRegex = RegExp(r'^(\d{1,2})[\/-](\d{1,2})$');

  static final Map<String, int> _monthMap = UnmodifiableMapView({
    "january": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "may": 5,
    "june": 6,
    "july": 7,
    "august": 8,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
    "jan": 1,
    "feb": 2,
    "mar": 3,
    "apr": 4,
    "jun": 6,
    "jul": 7,
    "aug": 8,
    "sep": 9,
    "sept": 9,
    "oct": 10,
    "nov": 11,
    "dec": 12,
    "janu": 1,
    "febr": 2,
    "marc": 3,
    "apri": 4,
    "juli": 7,
    "augu": 8,
    "sepe": 9,
    "octo": 10,
    "nove": 11,
    "dece": 12,
  });

  static const Map<int, String> monthNumberToName = {
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December",
  };

  PartialDate parse(String input) {
    if (input.trim().isEmpty) return PartialDate.empty;

    final lowerInput = input.toLowerCase();

    var result = _parseRelativeDate(lowerInput);
    if (!result.isEmpty) return result;

    result = _parseStructuredFormats(lowerInput);
    if (!result.isEmpty) return result;

    final normalized = _normalizeDateString(lowerInput);
    result = _parseTokenizedDate(normalized);

    return result;
  }

  String getMonthName(int month) {
    return monthNumberToName[month] ?? 'Unknown';
  }

  String _normalizeDateString(String input) {
    return input
        .replaceAllMapped(_ordinalRegex, (match) => match.group(1)!)
        .replaceAll(_normalizeRegex, ' ')
        .trim();
  }

  int _convertTwoDigitYear(int year) {
    return year < _TWO_DIGIT_YEAR_PIVOT ? 2000 + year : 1900 + year;
  }

  PartialDate _parseRelativeDate(String lowerInput) {
    final bool hasToday = lowerInput.contains('today');
    final bool hasTomorrow = lowerInput.contains('tomorrow');
    final bool hasYesterday = lowerInput.contains('yesterday');

    final int count =
        (hasToday ? 1 : 0) + (hasTomorrow ? 1 : 0) + (hasYesterday ? 1 : 0);

    if (count > 1) {
      return PartialDate.empty;
    }

    final now = DateTime.now();
    if (hasToday) {
      return PartialDate(day: now.day, month: now.month, year: now.year);
    }
    if (hasTomorrow) {
      final tomorrow = now.add(const Duration(days: 1));
      return PartialDate(
        day: tomorrow.day,
        month: tomorrow.month,
        year: tomorrow.year,
      );
    }
    if (hasYesterday) {
      final yesterday = now.subtract(const Duration(days: 1));
      return PartialDate(
        day: yesterday.day,
        month: yesterday.month,
        year: yesterday.year,
      );
    }
    return PartialDate.empty;
  }

  PartialDate _parseStructuredFormats(String input) {
    final cleanInput = input.replaceAll(' ', '');

    Match? match = _isoFormatRegex.firstMatch(cleanInput);
    if (match != null) {
      final yearVal = int.tryParse(match.group(1)!);
      final monthVal = int.tryParse(match.group(2)!);
      final dayVal = int.tryParse(match.group(3)!);
      if (yearVal != null &&
          yearVal >= _MIN_YEAR &&
          yearVal <= _MAX_YEAR &&
          monthVal != null &&
          monthVal >= 1 &&
          monthVal <= 12 &&
          dayVal != null &&
          dayVal >= 1 &&
          dayVal <= 31) {
        return PartialDate(day: dayVal, month: monthVal, year: yearVal);
      }
      return PartialDate.empty;
    }

    match = _standardFormatRegex.firstMatch(cleanInput);
    if (match != null) {
      final p1 = int.parse(match.group(1)!);
      final p2 = int.parse(match.group(2)!);
      final yearRaw = int.parse(match.group(3)!);
      final year = yearRaw > 99 ? yearRaw : _convertTwoDigitYear(yearRaw);

      if (year < _MIN_YEAR || year > _MAX_YEAR) return PartialDate.empty;

      if (p1 > 12) {
        if (p1 >= 1 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
          return PartialDate(day: p1, month: p2, year: year);
        }
      } else if (p2 > 12) {
        if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
          return PartialDate(day: p2, month: p1, year: year);
        }
      } else {
        if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
          return PartialDate(day: p2, month: p1, year: year);
        }
      }
      return PartialDate.empty;
    }

    match = _shortFormatRegex.firstMatch(cleanInput);
    if (match != null) {
      final p1 = int.parse(match.group(1)!);
      final p2 = int.parse(match.group(2)!);

      if (p1 > 12) {
        if (p1 >= 1 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
          return PartialDate(day: p1, month: p2);
        }
      } else if (p2 > 12) {
        if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
          return PartialDate(day: p2, month: p1);
        }
      } else {
        if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
          return PartialDate(day: p2, month: p1);
        }
      }
      return PartialDate.empty;
    }

    match = _dotFormatRegex.firstMatch(cleanInput);
    if (match != null) {
      final yearRaw = int.parse(match.group(3)!);
      final year = yearRaw > 99 ? yearRaw : _convertTwoDigitYear(yearRaw);
      final dayVal = int.tryParse(match.group(1)!);
      final monthVal = int.tryParse(match.group(2)!);

      if (year >= _MIN_YEAR &&
          year <= _MAX_YEAR &&
          dayVal != null &&
          dayVal >= 1 &&
          dayVal <= 31 &&
          monthVal != null &&
          monthVal >= 1 &&
          monthVal <= 12) {
        return PartialDate(day: dayVal, month: monthVal, year: year);
      }
      return PartialDate.empty;
    }

    match = _compactFormatRegex.firstMatch(cleanInput);
    if (match != null) {
      final yearVal = int.tryParse(cleanInput.substring(0, 4));
      final monthVal = int.tryParse(cleanInput.substring(4, 6));
      final dayVal = int.tryParse(cleanInput.substring(6, 8));

      if (yearVal != null &&
          yearVal >= _MIN_YEAR &&
          yearVal <= _MAX_YEAR &&
          monthVal != null &&
          monthVal >= 1 &&
          monthVal <= 12 &&
          dayVal != null &&
          dayVal >= 1 &&
          dayVal <= 31) {
        return PartialDate(day: dayVal, month: monthVal, year: yearVal);
      }
      return PartialDate.empty;
    }

    return PartialDate.empty;
  }

  PartialDate _parseTokenizedDate(String normalized) {
    final tokens = normalized.split(' ');
    int? day, month, year;

    if (tokens.length == 1) {
      final token = tokens[0];
      final match = _yearOnlyRegex.firstMatch(token);
      if (match != null) {
        final parsedYear = int.tryParse(match.group(1)!);
        if (parsedYear != null &&
            parsedYear >= _MIN_YEAR &&
            parsedYear <= _MAX_YEAR) {
          return PartialDate(year: parsedYear);
        }
      }
      if (_monthMap.containsKey(token)) {
        return PartialDate(month: _monthMap[token]!);
      }
      final singleValue = int.tryParse(token);
      if (singleValue != null && singleValue >= 1 && singleValue <= 31) {
        return PartialDate(day: singleValue);
      }
      return PartialDate.empty;
    }

    for (final token in tokens) {
      if (_monthMap.containsKey(token) && month == null) {
        month = _monthMap[token];
        continue;
      }

      final value = int.tryParse(token);
      if (value == null) {
        continue;
      }

      if (value >= _MIN_YEAR && value <= _MAX_YEAR && year == null) {
        year = value;
      } else if (value >= 1 && value <= 31 && day == null) {
        day = value;
      } else if (value >= 0 && value <= 99 && year == null) {
        final convertedYear = _convertTwoDigitYear(value);
        if (convertedYear >= _MIN_YEAR && convertedYear <= _MAX_YEAR) {
          year = convertedYear;
        }
      } else if (value >= 1 && value <= 12 && month == null) {
        month = value;
      }
    }

    if (day != null && (day < 1 || day > 31)) {
      day = null;
    }
    if (month != null && (month < 1 || month > 12)) {
      month = null;
    }

    final bool inputHadMonthWord = tokens.any((t) => _monthMap.containsKey(t));
    final bool inputHadYearWord = tokens.any((t) {
      final v = int.tryParse(t);
      return v != null && v >= 1000 && v <= 9999;
    });

    if (day != null && month == null && year == null && tokens.length > 1) {
      if (normalized.contains('of') &&
          !inputHadMonthWord &&
          !inputHadYearWord) {
        return PartialDate.empty;
      }
      if (!inputHadMonthWord && !inputHadYearWord && tokens.length > 1) {}
    }

    if (day == null && month == null && year == null) {
      return PartialDate.empty;
    }

    if (day != null && month == null && year == null && tokens.length > 1) {
      if (!inputHadMonthWord && !inputHadYearWord) {
        return PartialDate.empty;
      }
    }

    return PartialDate(day: day, month: month, year: year);
  }
}
