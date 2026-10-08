import 'package:flutter_test/flutter_test.dart';
import 'package:tover_bilt/core/format.dart';

void main() {
  test('groupDigits inserts separators', () {
    expect(groupDigits(0), '0');
    expect(groupDigits(999), '999');
    expect(groupDigits(1000), '1,000');
    expect(groupDigits(1234567), '1,234,567');
    expect(groupDigits(-4200), '-4,200');
  });

  test('clock pads every field', () {
    expect(clock(const Duration(hours: 5, minutes: 3, seconds: 9)), '05:03:09');
    expect(clock(Duration.zero), '00:00:00');
  });
}
