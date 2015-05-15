library bwu_log.test.syslog_appender;

import 'package:test/test.dart';
import 'package:bwu_log/syslog_appender.dart';
import 'appender_test.dart';


main() {
  group('syslog_appender', () {
    test('should not fail', () {
      var appender = new SyslogAppender(new SyslogFormatter());
      var logger = new SimpleLogger();
      appender.attachLogger(logger);

      logger.info('test message');

    });
  });
}
