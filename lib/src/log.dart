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

part of bwu_log;

/// Appenders define output vectors for logging messages. An appender can be
/// used with multiple [Logger]s, but can use only a single [Formatter]. This
/// class is designed as base class for other Appenders to extend.
///
/// Generally an Appender recieves a log message from the attached logger
/// streams, runs it through the formatter and then outputs it.
abstract class Appender<T> {
  final List<StreamSubscription> _subscriptions = [];
  final AppenderConfig configuration;

  Appender(this.configuration);

  //TODO(bendera): What if we just handed in the stream? Does it need to be a
  //Logger or just a stream of LogRecords?
  /**
   * Attaches a logger to this appender
   */
  attachLogger(Logger logger) => _subscriptions.add(logger.onRecord
      .listen((LogRecord r) {
    try {
      append(r, configuration.formatter);
    } catch (e) {
      //will keep the logger from downing the app, how best to notify the
      //app here?
    }
  }));

  /**
   * Each appender should implement this method to perform custom log output.
   */
  void append(LogRecord record, Formatter<T> formatter);

  /**
   * Terminate this Appender and cancel all logging subscriptions.
   */
  void stop() => _subscriptions.forEach((s) => s.cancel());
}

typedef T Formatter<T>(LogRecord record);

/**
 * Formatter accepts a [LogRecord] and returns a T
 */
abstract class FormatterBase<T> {
  //TODO(bendera): wasnt sure if formatter should be const, but it seems like
  //if we intend for them to eventually be only functions then it make sense.
  const FormatterBase();

  /**
   * Formats a given [LogRecord] returning type T as a result
   */
  T call(LogRecord record);
}

/**
 * Formats log messages using a simple pattern
 */
class BasicLogFormatter implements FormatterBase<String> {
  static final DateFormat _dateFormat = new DateFormat("yyMMdd HH:mm:ss.S");

  const BasicLogFormatter();
  /**
   * Formats a [LogRecord] using the following pattern:
   *
   * MMyy HH:MM:ss.S level sequence loggerName message
   */
  String call(LogRecord record) => "${_dateFormat.format(record.time)} "
      "${record.level} "
      "${record.sequenceNumber} "
      "${record.loggerName} "
      "${record.message}";
}

/**
 * Appends string messages to the console using print function
 */
class PrintAppender extends Appender<String> {
  @override
  PrintAppenderConfig get configuration => super.configuration;

  /**
   * Returns a new ConsoleAppender with the given [Formatter<String>]
   */
  factory PrintAppender([PrintAppenderConfig config]) {
    if(config == null) config = new PrintAppenderConfig();
    return new PrintAppender._(config);
  }

  PrintAppender._(PrintAppenderConfig configuration) : super(configuration);

  void append(LogRecord record, Formatter<String> formatter) =>
      print(formatter(record));
}

class PrintAppenderConfig extends AppenderConfig {
  static const defaultConfig = const {'formatter': const BasicLogFormatter()};
  Map _configuration;
  PrintAppenderConfig([this._configuration]) {
    if (_configuration == null) {
      _configuration = defaultConfig;
    }
  }

  Formatter get formatter => _configuration['formatter'] != null
      ? _configuration['formatter']
      : defaultConfig['formatter'];
}

/**
 * Appends string messages to the messages list. Note that this logger does not
 * ever truncate so only use for diagnostics or short lived applications.
 */
class InMemoryListAppender extends Appender<Object> {
  final List<Object> messages = [];

  /**
   * Returns a new InMemoryListAppender with the given [Formatter<String>]
   */

  InMemoryListAppender(InMemoryListAppenderConfig config) : super(config);

  void append(LogRecord record, Formatter<Object> formatter) =>
      messages.add(formatter(record));
}

class InMemoryListAppenderConfig extends AppenderConfig {
  static const defaultConfig = const {'formatter': const BasicLogFormatter()};
  Map _configuration;
  InMemoryListAppenderConfig([this._configuration]) {
    if (_configuration == null) {
      _configuration = defaultConfig;
    }
  }

  Formatter get formatter => _configuration['formatter'] != null
      ? _configuration['formatter']
      : defaultConfig['formatter'];
}
