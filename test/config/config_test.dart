library bwu_log.test.config;

import 'package:test/test.dart';
import 'package:bwu_log/src/syslog_appender.dart';
import 'bwu_log_config_io.dart';

main() {
  group('file config', () {
    test('should load from file', () {
      initLogging();
//      expect(conf.appender, new isInstanceOf<SyslogAppender>());
//      expect(new SyslogAppenderConfig(conf.appenderConfiguration).formatter,
//          new isInstanceOf<SimpleSyslogFormatter>());
    });
  });
}
