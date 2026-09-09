import 'package:callable/callable.dart';
import 'package:test/test.dart';

void main() {
  test('receives every native listener callback', () async {
    const config = BenchmarkConfig(hz: 100, seconds: 0.1);
    final result = await runBenchmark(config);

    expect(result.sampleCount, 10);
    expect(result.latency.minUs, greaterThanOrEqualTo(0));
    expect(result.throughput, greaterThan(0));
  });
}
