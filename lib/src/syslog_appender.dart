library bwu_log.src.syslog_appender;

import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:bwu_log/bwu_log.dart' as log;
import 'package:bwu_log/bwu_log_io.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'dart:async' show Future;
import 'package:collection/wrappers.dart';

enum TransgressionAction { split, truncate, }

enum Protocol { tcp, udp, }

abstract class SyslogTransport {
  bool get isOpen;
  void open();
  void close();
  void send(List<int> data);
}

class SyslogUdpTransport implements SyslogTransport {
  bool get isOpen => _socket != null;
  io.RawDatagramSocket _socket;
  final host;
  final int port;
  final int maxMessageLength;
  final int transgressionAction;

  io.InternetAddress _resolvedHost;

  static Future<io.InternetAddress> _getHost(host) async {
    if (host is io.InternetAddress) {
      return host;
    }
    if (host != null) {
      try {
        return new io.InternetAddress(host);
      } catch (_) {}
      try {
        return (await io.InternetAddress.lookup(host)).first;
      } catch (_) {}
    }
    return null;
  }

  SyslogUdpTransport({this.host, this.port: 514, this.maxMessageLength: 2048,
      this.transgressionAction: TransgressionAction.split})
      : host = host != null ? host : io.InternetAddress.LOOPBACK_IP_V4,
        port = port != null ? port : 514,
        maxMessageLength = maxMessageLength != null ? maxMessageLength : 2048,
        transgressionAction = transgressionAction != null
            ? transgressionAction
            : TransgressionAction.split;

  Future open() async {
    try {
      _resolvedHost = await _getHost(this.host);
      if (_resolvedHost == null) {
        return;
      }
      _socket = await io.RawDatagramSocket.bind(
          await io.InternetAddress.ANY_IP_V4, 0);
    } catch (e) {
      // Prevent logging from crashing the app
      // TODO(zoechi) find some way to handle this properly
    }
  }

  Future close() async {
    _socket.close();
    await _socket.drain();
    _socket = null;
  }

  int send(List<int> data) {
    if (isOpen) {
      return _socket.send(data, _resolvedHost, port);
    }
    return 0;
  }
}

class SyslogAppender extends log.Appender<SyslogMessage> {
  SyslogFormatter get formatter => super.formatter;
  final SyslogTransport transport;

  SyslogAppender({SyslogFormatter formatter, this.transport, log.Filter filter})
      : formatter = formatter != null ? formatter : new SimpleSyslogFormatter(),
        transport = transport != null ? transport : new SyslogUdpTransport(),
        super(formatter, filter: filter);

  static final DateFormat _dateFormat = new DateFormat("MMM dd hh:mm:ss");

  void append(LogRecord record, log.Formatter<SyslogMessage> formatter) {
    final SyslogMessage msg = formatter(record);
    if (msg.message.isNotEmpty) {
      io.BytesBuilder header = new io.BytesBuilder();

      _addHeader(header, msg);

      if (msg.tag != null) {
        header.add(msg.tag.substring(0, math.min(
            31 - msg.messageId.toString().length, msg.tag.length)).codeUnits);
      }
      header.add('-'.codeUnits);
      header.add(msg.messageId.toString().codeUnits);
      header.add(':'.codeUnits);

      int pos = 0;
      final maxPartLen = maxMessageLength - header.length;

      while (pos < msg.message.length) {
        io.BytesBuilder message = new io.BytesBuilder();
        message.add(header.toBytes());

        final len = math.min(msg.message.length - pos, maxPartLen);
        final msgPart = msg.message.substring(pos, len);
        pos += len;
        message.add(msgPart.codeUnits);
        _send(new Uint8List.fromList(message.toBytes()));
        //_send(new Uint8List.fromList('<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - BOM\'su root\' failed for lonvick on /dev/pts/8'.codeUnits));

      }
    }
  }

  final _space = ' '.codeUnits;
  void _addHeader(io.BytesBuilder header, SyslogMessage msg) {
    _addPri(header, msg.facility, msg.severity);
    _addVersion(header);
    header.add(_space);
    _addTimeStamp(header, msg.timeStamp);
    header.add(_space);
    _addHostname(header, msg.hostname);
    header.add(_space);
    _addAppName(header, msg.appName);
    header.add(_space);
  }

  void _addPri(io.BytesBuilder header, Facility facility, Severity severity) {
    header.add('<'.codeUnits);
    header.add(((facility.index << 3) + severity.index).toString().codeUnits);
    header.add('>'.codeUnits);
  }

  void _addTimeStamp(io.BytesBuilder header, DateTime timeStamp) {
    // RFC 5424
    header.add(timeStamp.toUtc().toIso8601String().codeUnits);

    // RFC 3164
//    String ts = _dateFormat.format(timeStamp);
//    if (ts[4] == '0') {
//      ts = ts.replaceRange(4, 5, ' ');
//    }
//    header.add(ts.codeUnits);
//    header.add(' '.codeUnits);
  }

  void _addVersion(io.BytesBuilder header) {
    header.add('1'.codeUnits);
  }

  void _addHostname(io.BytesBuilder header, String hostname) {
    /// if FQN is provided extract the hostname
    if (hostname != null) {
      header.add(hostname.split('.').first.codeUnits);
    }
    header.add(' '.codeUnits);
  }

  void _addAppName(io.BytesBuilder header, String appName) {}

  Future<Null> _send(List<int> bytes) async {
    if (!transport.isOpen) {
      await transport.open();
    }
    // print(new String.fromCharCodes(bytes));
    transport.send(bytes);
  }
}

enum Severity {
  emergency,
  alert,
  critical, // shout
  error, // severe
  warning, // warning
  notice, // info
  informational, // config
  debug, // fine
}

enum Facility {
  /// 0 - kernel messages
  kern,
  /// 1 - user-level messages
  user,
  /// 2 - mail system
  mail,
  /// 3 - system daemons
  daemon,
  /// 4 - security/authorization messages
  auth,
  /// 5 - messages generated internally by syslogd
  syslog,
  /// 6 - line printer subsystem
  lpr,
  /// 7 - network news subsystem
  news,
  /// 8 - UUCP subsystem
  uucp,
  /// 9 - clock daemon
  clock,
  /// 10 - security/authorization messages
  authpriv,
  /// 11 - FTP daemon
  ftp,
  /// 12 - NTP subsystem
  ntp,
  /// 13 - log audit
  logAudit,
  /// 14 - log alert
  logAlert,
  /// 15 - clock daemon (note 2)
  cron,
  /// 16 - local use 0 (local0)
  local0,
  /// 17 - local use 0 (local1)
  local1,
  /// 18 - local use 0 (local2)
  local2,
  /// 19 - local use 0 (local3)
  local3,
  /// 20 - local use 0 (local4)
  local4,
  /// 21 - local use 0 (local5)
  local5,
  /// 22 - local use 0 (local6)
  local6,
  /// 23 - local use 0 (local7)
  local7,
}

class SyslogMessage {
  // RFC 3164
  // 0 - Emergency: system is unusable
  final Severity severity;
  // 1 - Alert: action must be taken immediately
  final Facility facility;
  // 2 - Critical: critical conditions
  final DateTime timeStamp;
  // 3 - Error: error conditions
  final String hostname;
  // 4 - Warning: warning conditions
  final String tag;
  // 5 - Notice: normal but significant condition
  //final int sequenceNumber;
  // renamed by RFC 5424
  final int messageId;
  // 6 - Informational: informational messages
  final String message;

  // added by RFC 5424
  final String appName;
  final String processId;

  const SyslogMessage(this.severity, this.facility, this.timeStamp,
      this.hostname, this.tag, this.messageId, this.message,
      [this.appName, this.processId]);
}

const int maxMessageLength = 1024;
const String splitter = '\n>>>\n';

abstract class SyslogFormatter extends log.FormatterBase<SyslogMessage> {}

class SimpleSyslogFormatter extends SyslogFormatter {
  SyslogMessage call(LogRecord record) {
    Severity severity;
    if (record.level.value >= 1600) {
      severity = Severity.emergency;
    } else if (record.level.value >= 1400) {
      severity = Severity.alert;
    } else if (record.level.value >= Level.SHOUT.value) {
      severity = Severity.critical;
    } else if (record.level.value >= Level.SEVERE.value) {
      severity = Severity.error;
    } else if (record.level.value >= Level.WARNING.value) {
      severity = Severity.warning;
    } else if (record.level.value >= Level.INFO.value) {
      severity = Severity.notice;
    } else if (record.level.value >= Level.CONFIG.value) {
      severity = Severity.informational;
    } else if (record.level.value >= Level.FINE.value) {
      severity = Severity.debug;
    }
    String message = record.message;
    if (message == null) {
      message = '';
    }
    if (record.error != null) {
      message = '${message}${splitter}${record.error}';
    }
    if (record.stackTrace != null) {
      message = '${message}${splitter}${record.stackTrace}';
    }

    String tag = record.loggerName;

    return new SyslogMessage(severity, Facility.user, record.time,
        io.Platform.localHostname, tag, record.sequenceNumber, message, null,
        record.zone['LOGGING_ZONE_NAME']);
  }
}
