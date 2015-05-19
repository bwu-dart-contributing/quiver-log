library bwu_log.test.simple_logger;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:bwu_log/bwu_log.dart';

class SimpleLogger implements Logger {
  StreamController<LogRecord> _controller = new StreamController(sync:true);
  Stream<LogRecord> get onRecord => _controller.stream;

  void info(String msg, [Object message, StackTrace stackTrace]) =>
    _controller.add(new LogRecord(Level.INFO, msg, 'simple'));

  noSuchMethod(Invocation i) {}
}

class SimpleStringFormatter implements FormatterBase<String>{
  String call(LogRecord record) => "Formatted ${record.message}";
}
