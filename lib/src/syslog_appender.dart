library bwu_log.src.syslog_appender;

import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:bwu_log/bwu_log.dart' as log;
import 'package:logging/logging.dart';
import 'dart:async' show Future;

enum TransgressionAction {
  split,
  truncate,
}

enum Protocol {
  tcp,
  udp,
}

abstract class SyslogTransport {
  bool get isOpen;
  Future<Null> open();
  void close();
  void send(List<int> data);
}

class SyslogUdpTransport implements SyslogTransport {
  @override
  bool get isOpen => _socket != null;
  io.RawDatagramSocket _socket;
  final dynamic host;
  final int port;
  final int maxMessageLength;
  final TransgressionAction transgressionAction;

  io.InternetAddress _resolvedHost;

  static Future<io.InternetAddress> _getHost(dynamic host) async {
    if (host is io.InternetAddress) {
      return host;
    }
    if (host != null) {
      try {
        return new io.InternetAddress(host as String);
      } catch (_) {}
      try {
        return (await io.InternetAddress.lookup(host as String)).first;
      } catch (_) {}
    }
    return null;
  }

  SyslogUdpTransport(
      {dynamic host,
      int port: 514,
      int maxMessageLength: 2048,
      TransgressionAction transgressionAction: TransgressionAction.split})
      : host = host != null ? host : io.InternetAddress.LOOPBACK_IP_V4,
        port = port != null ? port : 514,
        maxMessageLength = maxMessageLength != null ? maxMessageLength : 2048,
        transgressionAction = transgressionAction != null
            ? transgressionAction
            : TransgressionAction.split;

  @override
  Future<Null> open() async {
    try {
      _resolvedHost = await _getHost(this.host);
      if (_resolvedHost == null) {
        return;
      }
      _socket =
          await io.RawDatagramSocket.bind(io.InternetAddress.ANY_IP_V4, 0);
    } catch (e) {
      // Prevent logging from crashing the app
      // TODO(zoechi) find some way to handle this properly
    }
  }

  @override
  Future close() async {
    _socket.close();
    await _socket.drain<dynamic>();
    _socket = null;
  }

  @override
  int send(List<int> data) {
    if (isOpen) {
      return _socket.send(data, _resolvedHost, port);
    }
    return 0;
  }
}

class SyslogAppender extends log.Appender<SyslogMessage> {
  @override
  SyslogFormatter get formatter => super.formatter as SyslogFormatter;
  final SyslogTransport transport;

  SyslogAppender(
      {SyslogFormatter formatter, SyslogTransport transport, log.Filter filter})
      : transport = transport ?? new SyslogUdpTransport(),
        super(formatter ?? new SimpleSyslogFormatter(), filter: filter);

  @override
  void append(LogRecord record, log.Formatter<SyslogMessage> formatter) {
    final SyslogMessage msg = formatter(record);
    final content = '${msg.tag} | ${msg.message}';
    if (content.isNotEmpty) {
      final header = new io.BytesBuilder();

      _addHeader(header, msg);

      _addStructuredData(header, null);
      header.add(_space);

      int pos = 0;
      final maxPartLen = maxMessageLength - header.length;

      while (pos < content.length) {
        final message = new io.BytesBuilder()..add(header.toBytes());

        final len = math.min(content.length - pos, maxPartLen);
        final msgPart = content.substring(pos, len);
        pos += len;
        message.add(msgPart.codeUnits);
        _send(new Uint8List.fromList(message.toBytes()));
      }
    }
  }

  final _space = ' '.codeUnits;
  void _addHeader(io.BytesBuilder header, SyslogMessage msg) {
    _addPri(header, msg.facility, msg.severity);
    _addVersion(header);
    _addTimeStamp(header, msg.timeStamp);
    _addHostname(header, msg.hostname);
    _addAppName(header, msg.appName);
    _addProcessId(header, msg.processId);
    _addMessageId(header, msg.messageId);
  }

  void _addPri(io.BytesBuilder header, Facility facility, Severity severity) {
    header
      ..add('<'.codeUnits)
      ..add(((facility.index << 3) + severity.index).toString().codeUnits)
      ..add('>'.codeUnits);
  }

  void _addTimeStamp(io.BytesBuilder header, DateTime timeStamp) {
    // RFC 5424
    header..add(_space)..add(timeStamp.toUtc().toIso8601String().codeUnits);
  }

  void _addVersion(io.BytesBuilder header) {
    header.add('1'.codeUnits);
  }

  void _addHostname(io.BytesBuilder header, String hostname) {
    /// if FQN is provided extract the hostname
    if (hostname != null) {
      // TODO(zoechi) don't do this for IP addresses
      header.add(' ${hostname.split('.').first}'.codeUnits);
    } else {
      header.add(' -'.codeUnits);
    }
  }

  void _addAppName(io.BytesBuilder header, String appName) {
    if (appName != null) {
      header.add(' $appName'.codeUnits);
    } else {
      header.add(' -'.codeUnits);
    }
  }

  void _addProcessId(io.BytesBuilder header, String processId) {
    if (processId != null) {
      header.add(' $processId'.codeUnits);
    } else {
      header.add(' -'.codeUnits);
    }
  }

  void _addStructuredData(io.BytesBuilder header, String data) {
    // TODO(zoechi) not yet supported
//    if (data != null) {
//      header.add(' $data '.codeUnits);
//    } else {
    header.add(' -'.codeUnits);
//    }
  }

  void _addMessageId(io.BytesBuilder header, int messageId) {
    if (messageId != null) {
      header.add(' $messageId'.codeUnits);
    } else {
      header.add(' -'.codeUnits);
    }
  }

  Future<Null> _send(List<int> bytes) async {
    if (!transport.isOpen) {
      await transport.open();
    }
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
  final Facility facility;
  final String applicationName;

  SimpleSyslogFormatter(
      {Facility facility = Facility.user, this.applicationName})
      : facility = facility ?? Facility.user;

  Severity severity(LogRecord record) {
    if (record.level.value >= 1600) {
      return Severity.emergency;
    } else if (record.level.value >= 1400) {
      return Severity.alert;
    } else if (record.level.value >= Level.SHOUT.value) {
      return Severity.critical;
    } else if (record.level.value >= Level.SEVERE.value) {
      return Severity.error;
    } else if (record.level.value >= Level.WARNING.value) {
      return Severity.warning;
    } else if (record.level.value >= Level.INFO.value) {
      return Severity.notice;
    } else if (record.level.value >= Level.CONFIG.value) {
      return Severity.informational;
    } else if (record.level.value <= Level.FINE.value) {
      return Severity.debug;
    }
    throw new Exception('This line must not be reached');
  }

  @override
  SyslogMessage call(LogRecord record) {
    final severity = this.severity(record);

    String message = record.message;
    if (message == null) {
      message = '';
    }
    if (record.error != null) {
      message = '$message$splitter${record.error}';
    }
    if (record.stackTrace != null) {
      message = '$message$splitter${record.stackTrace}';
    }

    final tag = record.loggerName;

    return new SyslogMessage(
        severity,
        facility,
        record.time,
        io.Platform.localHostname,
        tag,
        record.sequenceNumber,
        message,
        applicationName,
        record.zone['LOGGING_ZONE_NAME'] as String ?? '${io.pid}');
  }
}
