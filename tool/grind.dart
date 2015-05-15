library bwu_log.tool.grind;

import 'package:grinder/grinder.dart';

const sourceDirs = const ['lib', 'tool', 'test', 'example'];

main(List<String> args) => grind(args);

@Task('Run analyzer')
analyze() => _analyze();

@Task('Runn all tests')
test() => _test();

@Task('Check everything')
@Depends(analyze, /*checkFormat,*/ lint, test)
check() => _check();

// TODO(zoechi) fix when it's possible the check the outcome
//@Task('Check source code format')
//checkFormat() => checkFormatTask(['.']);

/// format-all - fix all formatting issues
@Task('Fix all source format issues')
formatAll() => _formatAll();

@Task('Run lint checks')
lint() => _lint();

_analyze() => new PubApp.global('tuneup').run(['check']);

_check() => run('pub', arguments: ['publish', '-n']);

_formatAll() => new PubApp.global('dart_style').run(['-w']..addAll(sourceDirs),
    script: 'format');

_lint() => new PubApp.global('linter')
    .run(['--stats', '-ctool/lintcfg.yaml']..addAll(sourceDirs));

// TODO(zoechi) enable firefox when the issue with timed-out connection is fixed
_test() => new PubApp.local('test').run(['-pvm', '-pdartium', '-pchrome', /*'-pfirefox'*/]);
