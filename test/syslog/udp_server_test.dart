library bwu_log.test.udp_server;

import 'package:test/test.dart';
import 'package:bwu_log/server_appenders.dart';
import 'package:logging/logging.dart';

void main() {
  group('syslog_appender', () {
    Logger _log;
    setUp(() {
      final appender = new SyslogAppender(
          formatter: new SimpleSyslogFormatter(
              facility: Facility.user, applicationName: 'fhir_designer_server'),
          transport: new SyslogUdpTransport());
      _log = new Logger('fhir_designer.server.server');
      appender.attachLogger(Logger.root..level = Level.FINEST);
      hierarchicalLoggingEnabled = true;
    });

    test('should receive a message', () {
      _log
        ..finest('udp test 0')
        ..finer('udp test 1')
        ..fine('udp test 2')
        ..config('udp test 3')
        ..info('udp test 4')
        ..warning('udp test 5')
        ..severe('udp test 6')
        ..shout('udp test 7');
    });
//    }, skip: 'run only manually where rsyslogd is available');
  });
}
