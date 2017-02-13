library bwu_log.test.simple_logger;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:bwu_log/bwu_log.dart';

class SimpleLogger implements Logger {
  final _controller = new StreamController<LogRecord>(sync: true);
  @override
  Stream<LogRecord> get onRecord => _controller.stream;

  @override
  void info(covariant String msg, [Object message, StackTrace stackTrace]) =>
      _controller.add(new LogRecord(Level.INFO, msg, 'simple'));

  @override
  dynamic noSuchMethod(Invocation i) {
    return null;
  }
}

class SimpleStringFormatter implements FormatterBase<String> {
  @override
  String call(LogRecord record) => "Formatted ${record.message}";
}
