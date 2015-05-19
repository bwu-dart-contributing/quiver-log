library bwu_log.test.config;

import 'package:test/test.dart';
import 'package:bwu_log/bwu_log_io.dart';
import 'package:bwu_log/src/syslog_appender.dart';

main() {
  group('file config', () {
    test('should load from file', () {
      IoConfig conf = logConfig..loadConfig('test/config/bwu_log.yaml');
      expect(conf.appender, new isInstanceOf<SyslogAppender>());
      expect(conf.appender.formatter,new isInstanceOf<SimpleSyslogFormatter>());
    });
  });
}
