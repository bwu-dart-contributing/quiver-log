library bwu_log.test.syslog_appender;

import 'package:test/test.dart';
import 'package:bwu_log/server_appenders.dart';
import '../simple_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('syslog_appender', () {
    test('should not fail', () {
      final appender = new SyslogAppender();
      final logger = new SimpleLogger();
      appender.attachLogger(logger);

      logger.info('test message');
    });
  });

  group('syslog_appender', () {
    SyslogAppender appender;
    SyslogTestTransport transport;
    SyslogTestFormatter formatter;
    Logger logger;
    setUp(() {
      transport = new SyslogTestTransport();
      formatter = new SyslogTestFormatter();
      appender = new SyslogAppender(formatter: formatter, transport: transport);
      logger = new SimpleLogger();
      appender.attachLogger(logger);
    });

    tearDown(() {});

    test('should create PRI "<0>"', () {
      formatter.messages = [
        new SyslogMessage(Severity.emergency, Facility.kern, new DateTime.now(),
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Function>(() {
        final expectedPri = '<0>'.codeUnits;
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    test('should create PRI "<165>"', () {
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, new DateTime.now(),
            'hostname', 'tag', 1, 'message', 'test')
      ];

      transport.callback = expectAsync0<Null>(() {
        final expectedPri = '<165>'.codeUnits;
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    test('should create VERSION "1"', () {
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, new DateTime.now(),
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Null>(() {
        final expectedPri = '<165>1'.codeUnits;
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    test('should create correct UTC TIMESTAMP', () {
      final timeStamp = new DateTime.utc(1985, 4, 12, 23, 20, 50, 520);
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, timeStamp,
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Null>(() {
        final expectedPri = '<165>1 1985-04-12T23:20:50.520Z'.codeUnits;
        print(new String.fromCharCodes(transport.messages[0]));
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    /// Dart can't handle times with specific timezones therefore this merely
    /// tests Darts parsing capabilities
    test('should create correct zoned TIMESTAMP', () {
      final timeStamp = DateTime.parse('1985-04-12T19:20:50.52-04:00');
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, timeStamp,
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Null>(() {
        final expectedPri = '<165>1 1985-04-12T23:20:50.520Z'.codeUnits;
        print(new String.fromCharCodes(transport.messages[0]));
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    // Dart can't handle times with specific timezones therefore this merely
    // tests Darts parsing capabilities
    test('should create correct UTC TIMESTAMP with leading 0 in milliseconds',
        () {
      final timeStamp = DateTime.parse('2003-10-11T22:14:15.003Z');
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, timeStamp,
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Null>(() {
        final expectedPri = '<165>1 2003-10-11T22:14:15.003Z'.codeUnits;
        print(new String.fromCharCodes(transport.messages[0]));
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });

    // Dart doesn't support more than 3 digits in milliseconds.
    // TODO(zoechi) seems now it does
    test('should create correct UTC TIMESTAMP with 6 digit milliseconds', () {
      final timeStamp = DateTime.parse('2003-08-24T05:14:15.000003-07:00');
      formatter.messages = [
        new SyslogMessage(Severity.notice, Facility.local4, timeStamp,
            'hostname', 'tag', 1, 'message')
      ];

      transport.callback = expectAsync0<Null>(() {
        // This should have been the result according to the RFC5424 6.2.3.1
        // final expectedPri = '<165>1 2003-08-24T05:14:15.000003-07:00'.codeUnits;
        final expectedPri = '<165>1 2003-08-24T12:14:15.000003Z'.codeUnits;
        print(new String.fromCharCodes(transport.messages[0]));
        expect(transport.messages[0].sublist(0, expectedPri.length),
            orderedEquals(expectedPri));
      });

      logger.info('dummy');
    });
  });
}

class SyslogTestTransport extends SyslogTransport {
  List<List<int>> messages = [];
  @override
  void close() {}

  @override
  bool get isOpen => true;

  @override
  void open() {}

  Function callback;

  @override
  void send(List<int> data) {
    messages.add(data);
    callback();
  }
}

class SyslogTestFormatter extends SyslogFormatter {
  SyslogTestFormatter() : super();

  List<SyslogMessage> _messages;
  set messages(List<SyslogMessage> value) {
    _messages = value;
    _counter = 0;
  }

  int _counter = 0;

  @override
  SyslogMessage call(LogRecord record) {
    while (_counter < _messages.length) {
      return _messages[_counter++];
    }
    throw new Exception('No more messages');
  }
}
