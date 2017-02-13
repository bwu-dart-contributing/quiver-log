// Copyright 2013 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library bwu_log.appender_test;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:bwu_log/bwu_log.dart';
import 'package:test/test.dart';

void main() {
  group('Appender', () {
    test('Appends handles log message and formats before output', () {
      var appender = new InMemoryListAppender(new SimpleStringFormatter());
      var logger = new SimpleLogger();
      appender.attachLogger(logger);

      logger.info('test message');

      expect(appender.messages.last, 'Formatted test message');
    });
  });
}

class SimpleLogger implements Logger {
  StreamController<LogRecord> _controller = new StreamController(sync: true);
  @override
  Stream<LogRecord> get onRecord => _controller.stream;

  @override
  void info(dynamic msg, [Object message, StackTrace stackTrace]) =>
      _controller.add(new LogRecord(Level.INFO, msg, 'simple'));

  @override
  void noSuchMethod(Invocation i) {}
}

class SimpleStringFormatter implements FormatterBase<String> {
  @override
  String call(LogRecord record) => "Formatted ${record.message}";
}
