import 'dart:convert';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

import 'brick_yaml.dart';
import 'mason_bundle.dart';

final _binaryFileTypes = RegExp(
  r'\.(jpe?g|png|gif|ico|svg|ttf|eot|woff|woff2|otf)$',
  caseSensitive: false,
);

/// Generates a [MasonBundle] from the provided [brick] directory.
MasonBundle createBundle(Directory brick) {
  final brickYamlFile = File(path.join(brick.path, BrickYaml.file));
  final brickYaml = checkedYamlDecode(
    brickYamlFile.readAsStringSync(),
    (m) => BrickYaml.fromJson(m!),
  );
  final brickDir = Directory(path.join(brick.path, BrickYaml.dir));
  final files = brickDir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) => !brickYaml.exclude.any(
          (toExclude) => Glob(toExclude).matches(
            path.relative(f.path, from: brickDir.path),
          ),
        ),
      )
      .map(_bundleBrickFile)
      .toList();
  final hooksDirectory = Directory(path.join(brick.path, BrickYaml.hooks));
  final hooks = hooksDirectory.existsSync()
      ? hooksDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .map(_bundleHookFile)
          .toList()
      : <MasonBundledFile>[];
  return MasonBundle(
    brickYaml.name,
    brickYaml.description,
    brickYaml.vars,
    files,
    hooks,
  );
}

MasonBundledFile _bundleBrickFile(File file) {
  final fileType =
      _binaryFileTypes.hasMatch(path.basename(file.path)) ? 'binary' : 'text';
  final data = base64.encode(file.readAsBytesSync());
  final filePath = path.joinAll(
    path.split(file.path).skipWhile((value) => value != BrickYaml.dir).skip(1),
  );
  return MasonBundledFile(filePath, data, fileType);
}

MasonBundledFile _bundleHookFile(File file) {
  final data = base64.encode(file.readAsBytesSync());
  final filePath = path.basename(file.path);
  return MasonBundledFile(filePath, data, 'text');
}
