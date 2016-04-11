// Copyright 2013 Google Inc. All Rights Reserved.
// Copyright 2015 Günter Zöchbauer, All Rights Reserved.
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
  final Formatter<T> formatter;
  final Filter filter;

  Appender(this.formatter, {this.filter});

  //TODO(bendera): What if we just handed in the stream? Does it need to be a
  //Logger or just a stream of LogRecords?
  /// Attaches a logger to this appender
  attachLogger(Logger logger) => _subscriptions.add(logger.onRecord
      .listen((LogRecord r) {
    if (filter != null && !filter(r)) {
      return;
    }
    try {
      append(r, formatter);
    } catch (e) {
      //will keep the logger from downing the app, how best to notify the
      //app here?
    }
  }));

  /// Each appender should implement this method to perform custom log output.
  void append(LogRecord record, Formatter<T> formatter);

  /// Terminate this Appender and cancel all logging subscriptions.
  void stop() => _subscriptions.forEach((s) => s.cancel());
}

typedef T Formatter<T>(LogRecord record);

///  Formatter accepts a [LogRecord] and returns a T
abstract class FormatterBase<T> {
  //TODO(bendera): wasn't sure if formatter should be const, but it seems like
  //if we intend for them to eventually be only functions then it make sense.
  const FormatterBase();

  /// Formats a given [LogRecord] returning type T as a result
  T call(LogRecord record);
}

/// Formats log messages using a simple pattern
class BasicLogFormatter implements FormatterBase<String> {
  static final DateFormat _dateFormat = new DateFormat("yyMMdd HH:mm:ss.S");

  const BasicLogFormatter();
  /// Formats a [LogRecord] using the following pattern:
  /// MMyy HH:MM:ss.S level sequence loggerName message
  String call(LogRecord record) => "${_dateFormat.format(record.time)} "
      "${record.level} "
      "${record.sequenceNumber} "
      "${record.loggerName} "
      "${record.message}";
}

/// Default instance of the BasicLogFormatter
@deprecated
const BASIC_LOG_FORMATTER = basicLogFormatter;
const basicLogFormatter = const BasicLogFormatter();

/// Appends string messages to the console using print function
class PrintAppender extends Appender<String> {

  /// Returns a new ConsoleAppender with the given [Formatter<String>]
  PrintAppender(Formatter<String> formatter, {Filter filter})
      : super(formatter, filter: filter);

  void append(LogRecord record, Formatter<String> formatter) =>
      print(formatter(record));
}

/// Appends string messages to the messages list. Note that this logger does not
/// ever truncate so only use for diagnostics or short lived applications.
class InMemoryListAppender extends Appender<Object> {
  final List<Object> messages = [];

  /// Returns a new InMemoryListAppender with the given [Formatter<String>]
  InMemoryListAppender(Formatter<Object> formatter, {Filter filter})
      : super(formatter, filter: filter);

  void append(LogRecord record, Formatter<Object> formatter) =>
      messages.add(formatter(record));
}

typedef bool Filter(LogRecord record);

/// Suppresses log records which are matched by an [excludes] rule and not
/// matched by an [includes] rule. [includes] rules have higher priority than
/// [excludes].
class BasicFilter {
  final List<FilterRule> excludes;
  final List<FilterRule> includes;

  const BasicFilter({this.excludes, this.includes});

  bool call(LogRecord record) {
    bool include = true;
    if (excludes != null && excludes.any((excl) => excl.match(record))) {
      include = false;
    }
    if (includes != null && includes.any((incl) => incl.match(record))) {
      include = true;
    }
    return include;
  }
}

/// A rule can be used as exclusion or inclusion rule.
/// To customize the matching capabilities just extend this class.
class FilterRule {
  /// Allows to filter for specific log levels, instead of a minimum log level.
  /// The filter only returns log records which were not already filtered out
  /// by the loggers `level` configuration.
  final List<Level> levels;
  /// Allows to filter by logger name using RegExp matches.
  final Pattern loggerNamePattern;
  /// Allows to filter by log message content using RegExp matches.
  final Pattern messagePattern;

  const FilterRule({this.levels, this.loggerNamePattern, this.messagePattern});

  bool match(LogRecord record) {
    if (levels != null && !levels.contains(record.level)) {
      return false;
    }
    if (loggerNamePattern != null &&
        loggerNamePattern.allMatches(record.loggerName).isEmpty) {
      return false;
    }
    if (messagePattern != null &&
        messagePattern.allMatches(record.message).isEmpty) {
      return false;
    }
    if (messagePattern != null &&
        messagePattern.allMatches(record.message).isEmpty) {
      return false;
    }
    return true;
  }
}
