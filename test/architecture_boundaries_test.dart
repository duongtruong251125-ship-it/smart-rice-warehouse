import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final directives = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  Iterable<File> sources(String folder) => Directory(folder)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  test('logic and data never depend on presentation or Flutter UI libraries',
      () {
    final forbidden = [
      'package:smart_rice_warehouse/presentation/',
      'package:flutter/material.dart',
      'package:flutter/widgets.dart',
      'package:flutter/cupertino.dart',
    ];
    for (final file in [...sources('lib/logic'), ...sources('lib/data')]) {
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        expect(forbidden.any(uri.startsWith), isFalse,
            reason: '${file.path} imports UI dependency $uri');
      }
    }
  });

  test('presentation accesses persistence through logic APIs', () {
    for (final file in sources('lib/presentation')) {
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        expect(uri.startsWith('package:smart_rice_warehouse/data/'), isFalse,
            reason: '${file.path} directly imports storage $uri');
      }
    }
  });

  test('logic never depends on data layer', () {
    for (final file in sources('lib/logic')) {
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        expect(uri.startsWith('package:smart_rice_warehouse/data/'), isFalse,
            reason: '${file.path} directly imports data layer $uri');
      }
    }
  });

  test(
      'contracts never depend on external database, cloud, or device platform drivers',
      () {
    final forbiddenDrivers = [
      'package:cloud_firestore/',
      'package:firebase_auth/',
      'package:firebase_core/',
      'package:sqflite/',
      'package:path_provider/',
      'package:shared_preferences/',
    ];
    for (final file in sources('lib/logic/contracts')) {
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        expect(forbiddenDrivers.any(uri.startsWith), isFalse,
            reason: '${file.path} contract leaks driver dependency $uri');
      }
    }
  });

  test('no source or test imports a retired source directory', () {
    final retired = RegExp(
      r'^package:smart_rice_warehouse/(screens|widgets|models|providers|services|repositories|core/(services|theme|routes|firebase))/',
    );
    for (final file in [...sources('lib'), ...sources('test')]) {
      for (final match in directives.allMatches(file.readAsStringSync())) {
        expect(retired.hasMatch(match.group(1)!), isFalse,
            reason: 'Stale import in ${file.path}: ${match.group(1)}');
      }
    }
  });
}
