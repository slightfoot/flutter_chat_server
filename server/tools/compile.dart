import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

final Directory binDir = File(Platform.resolvedExecutable).parent;

final String executableSuffix = Platform.isWindows ? '.exe' : '';

final String dartaotruntime = path.join(binDir.path, 'dartaotruntime${executableSuffix}');

final String genKernel = path.join(binDir.path, 'snapshots', 'gen_kernel.dart.snapshot');

final String genSnapshot = path.join(binDir.path, 'utils', 'gen_snapshot${executableSuffix}');

final String productPlatformDill =
    path.join(binDir.parent.path, 'lib', '_internal', 'vm_platform_strong_product.dill');

const appSnapshotPageSize = 4096;
const appjitMagicNumber = <int>[0xdc, 0xdc, 0xf6, 0xf6, 0, 0, 0, 0];

///
/// I created this script from the official dart2native sources
/// https://github.com/dart-lang/sdk/tree/master/pkg/dart2native
///
/// because it currently does not support the --no-sound-null-safety flag.
///
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tools/compile.dart bin/server.dart');
    stderr.flush();
    exit(1);
  }

  final String sourceFile = args[0];
  if (!FileSystemEntity.isFileSync(sourceFile)) {
    stderr.writeln('"${sourceFile}" is not a file.');
    stderr.flush();
    exit(1);
  }

  final sourcePath = path.canonicalize(path.normalize(sourceFile));
  final sourceWithoutDart = sourcePath.replaceFirst(RegExp(r'\.dart$'), '');
  final outputPath = path.canonicalize(path.normalize('${sourceWithoutDart}${executableSuffix}'));

  final Directory tempDir = Directory.systemTemp.createTempSync();

  print('Generating AOT kernel dill.');

  final String kernelFile = path.join(tempDir.path, 'kernel.dill');
  final kernelResult = Process.runSync(Platform.executable, [
    genKernel,
    '--platform',
    productPlatformDill,
    '--aot',
    '-Ddart.vm.product=true',
    '-o',
    kernelFile,
    '--no-sound-null-safety',
    sourcePath,
  ]);
  if (kernelResult.exitCode != 0) {
    stderr.writeln(kernelResult.stdout);
    stderr.writeln(kernelResult.stderr);
    stderr.flush();
    throw 'Generating AOT kernel dill failed!';
  }

  print('Generating AOT snapshot.');

  final String snapshotFile = path.join(tempDir.path, 'snapshot.aot');
  final snapshotResult = Process.runSync(genSnapshot, [
    '--snapshot-kind=app-aot-elf',
    '--elf=$snapshotFile',
    kernelFile,
  ]);
  if (snapshotResult.exitCode != 0) {
    stderr.writeln(snapshotResult.stdout);
    stderr.writeln(snapshotResult.stderr);
    stderr.flush();
    throw 'Generating AOT snapshot failed!';
  }

  print('Generating executable.');
  writeAppendedExecutable(dartaotruntime, snapshotFile, outputPath);

  if (Platform.isLinux || Platform.isMacOS) {
    Process.runSync('chmod', ['+x', outputPath]);
  }
}

Future writeAppendedExecutable(
    String dartaotruntimePath, String payloadPath, String outputPath) async {
  final dartaotruntime = File(dartaotruntimePath);
  final int dartaotruntimeLength = dartaotruntime.lengthSync();

  final padding = ((appSnapshotPageSize - dartaotruntimeLength) % appSnapshotPageSize);
  final padBytes = Uint8List(padding);
  final offset = dartaotruntimeLength + padding;

  // Note: The offset is always Little Endian regardless of host.
  final offsetBytes = ByteData(8) // 64 bit in bytes.
    ..setUint64(0, offset, Endian.little);

  final outputFile = File(outputPath).openWrite();
  outputFile.add(dartaotruntime.readAsBytesSync());
  outputFile.add(padBytes);
  outputFile.add(File(payloadPath).readAsBytesSync());
  outputFile.add(offsetBytes.buffer.asUint8List());
  outputFile.add(appjitMagicNumber);
  await outputFile.close();
}
