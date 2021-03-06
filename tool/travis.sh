#!/bin/bash

# Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Verify that the libraries are error free.
dartanalyzer --fatal-warnings \
  bin/services.dart \
  lib/services_server.dart \
  test/all.dart

# Run the tests.
dart test/all.dart

# Run the benchmarks.
dart tool/grind.dart travis-bench

# Install dart_coveralls; gather and send coverage data.
if [ "$REPO_TOKEN" ]; then
  pub global activate dart_coveralls
  pub global run dart_coveralls report \
    --token $REPO_TOKEN \
    --retry 2 \
    --exclude-test-files \
    test/all.dart
fi
