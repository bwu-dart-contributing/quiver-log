library bwu_log.test.syslog_appender;

import 'package:test/test.dart';
import 'package:bwu_log/bwu_log_io.dart';
import '../simple_logger.dart';


main() {
  group('syslog_appender', () {
    test('should not fail', () {
      var appender = appenderFactories['Syslog']();
      var logger = new SimpleLogger();
      appender.attachLogger(logger);

      logger.info('test message');

    });

    test('should calculate PRI correctly', () {
      var appender = appenderFactories['Syslog']();;
      var logger = new SimpleLogger();
      appender.attachLogger(logger);

      logger.info('test message');

    });

  });
}
