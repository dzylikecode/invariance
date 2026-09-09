import 'dart:async';
import 'dart:ffi';

import 'binding/callable.g.dart' as g;

class const BenchmarkConfig({
  final int hz = 1000,
  final double seconds = 3,
  final int busyMilliseconds = 0,
}) {
  int get sampleCount => (hz * seconds).round();
  int get intervalNanoseconds => (_nanosecondsPerSecond / hz).round();
  Duration get timeout => Duration(seconds: seconds.ceil() + 30);

  BenchmarkConfig copyWith({int? hz, double? seconds, int? busyMilliseconds}) =>
      BenchmarkConfig(
        hz: hz ?? this.hz,
        seconds: seconds ?? this.seconds,
        busyMilliseconds: busyMilliseconds ?? this.busyMilliseconds,
      );

  void validate() {
    if (hz <= 0) throw ArgumentError.value(hz, 'hz', 'must be positive');
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', 'must be positive');
    }
    if (busyMilliseconds < 0) {
      throw ArgumentError.value(
        busyMilliseconds,
        'busyMilliseconds',
        'cannot be negative',
      );
    }
  }
}

class const LatencyStats({
  required final double minUs,
  required final double averageUs,
  required final double p50Us,
  required final double p90Us,
  required final double p99Us,
  required final double p999Us,
  required final double maxUs,
}) {
  @override
  String toString() => [
    'min=${_decimal(minUs)}',
    'avg=${_decimal(averageUs)}',
    'p50=${_decimal(p50Us)}',
    'p90=${_decimal(p90Us)}',
    'p99=${_decimal(p99Us)}',
    'p99.9=${_decimal(p999Us)}',
    'max=${_decimal(maxUs)}',
  ].join(', ');
}

class const LatencyTrend({
  required final double firstTenthAverageUs,
  required final double lastTenthAverageUs,
}) {
  @override
  String toString() =>
      'first10%=${_decimal(firstTenthAverageUs)}, '
      'last10%=${_decimal(lastTenthAverageUs)}';
}

class const BenchmarkResult({
  required final BenchmarkConfig config,
  required final int sampleCount,
  required final Duration elapsed,
  required final LatencyStats latency,
  required final LatencyTrend trend,
}) {
  double get throughput =>
      sampleCount * _microsecondsPerSecond / elapsed.inMicroseconds;

  @override
  String toString() =>
      '''
NativeCallable.listener benchmark
rate=${config.hz} Hz, samples=$sampleCount, Dart busy=${config.busyMilliseconds} ms/10ms
elapsed=${(elapsed.inMicroseconds / 1e6).toStringAsFixed(3)}s, throughput=${throughput.toStringAsFixed(1)} callbacks/s
latency us: $latency
trend us: $trend''';
}

const _nanosecondsPerSecond = 1000000000;
const _nanosecondsPerMillisecond = 1000000;
const _nanosecondsPerMicrosecond = 1000;
const _microsecondsPerSecond = 1000000;
const _loadPeriod = Duration(milliseconds: 10);

String _decimal(double value) => value.toStringAsFixed(1);

Future<BenchmarkResult> runBenchmark([
  BenchmarkConfig config = const BenchmarkConfig(),
]) async {
  config.validate();

  final delays = <int>[];
  final done = Completer<void>();
  final callback = NativeCallable<g.CallableListenerFunction>.listener((
    int nativeTime,
    int sequence,
  ) {
    delays.add(g.callable_now_ns() - nativeTime);
    if (sequence + 1 == config.sampleCount) done.complete();
  });
  final isolateLoad = _startIsolateLoad(config.busyMilliseconds);

  final wall = Stopwatch()..start();
  if (!g.callable_start(
    callback.nativeFunction,
    config.intervalNanoseconds,
    config.sampleCount,
  )) {
    isolateLoad?.cancel();
    callback.close();
    throw StateError('Could not start native benchmark');
  }

  try {
    await done.future.timeout(config.timeout);
  } finally {
    wall.stop();
    isolateLoad?.cancel();
    g.callable_join();
    callback.close();
  }

  return BenchmarkResult(
    config: config,
    sampleCount: delays.length,
    elapsed: wall.elapsed,
    latency: _calculateLatencyStats(delays),
    trend: _calculateLatencyTrend(delays),
  );
}

Timer? _startIsolateLoad(int busyMilliseconds) {
  if (busyMilliseconds == 0) return null;

  return Timer.periodic(_loadPeriod, (_) {
    final busyUntil =
        g.callable_now_ns() + busyMilliseconds * _nanosecondsPerMillisecond;
    while (g.callable_now_ns() < busyUntil) {
      // Intentionally block this isolate to expose listener queueing latency.
    }
  });
}

LatencyStats _calculateLatencyStats(List<int> samples) {
  final sorted = [...samples]..sort();
  return LatencyStats(
    minUs: _toMicroseconds(sorted.first),
    averageUs: _averageMicroseconds(sorted),
    p50Us: _percentileMicroseconds(sorted, .5),
    p90Us: _percentileMicroseconds(sorted, .9),
    p99Us: _percentileMicroseconds(sorted, .99),
    p999Us: _percentileMicroseconds(sorted, .999),
    maxUs: _toMicroseconds(sorted.last),
  );
}

LatencyTrend _calculateLatencyTrend(List<int> samples) {
  final windowSize = (samples.length / 10).ceil();
  return LatencyTrend(
    firstTenthAverageUs: _averageMicroseconds(samples.take(windowSize)),
    lastTenthAverageUs: _averageMicroseconds(
      samples.skip(samples.length - windowSize),
    ),
  );
}

double _averageMicroseconds(Iterable<int> samples) {
  var total = 0;
  var count = 0;
  for (final sample in samples) {
    total += sample;
    count++;
  }
  return _toMicroseconds(total / count);
}

double _percentileMicroseconds(List<int> sorted, double percentile) {
  final index = ((sorted.length - 1) * percentile).round();
  return _toMicroseconds(sorted[index]);
}

double _toMicroseconds(num nanoseconds) =>
    nanoseconds / _nanosecondsPerMicrosecond;
