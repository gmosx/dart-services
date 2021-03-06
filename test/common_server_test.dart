// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:services/src/common.dart';
import 'package:services/src/common_server.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:rpc/rpc.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  CommonServer server;
  ApiServer apiServer;

  MockLogger logger = new MockLogger();
  MockCache cache = new MockCache();

  Future<HttpApiResponse> _sendPostRequest(String path, json) {
    assert(apiServer != null);
    var body = new Stream.fromIterable([UTF8.encode(JSON.encode(json))]);
    var request =
        new HttpApiRequest('POST', path, {}, ContentType.JSON.toString(), body);
    return apiServer.handleHttpRequest(request);
  }

  group('CommonServer', () {
    setUp(() {
      if (server == null) {
        String sdkPath = grinder.getSdkDir().path;
        server = new CommonServer(sdkPath, logger, cache);
        apiServer = new ApiServer(prettyPrint: true)..addApi(server);
      }
    });

    test('analyze', () async {
      var json = {'source': sampleCode};
      var response = await _sendPostRequest('dartservices/v1/analyze', json);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(JSON.decode(UTF8.decode(data)), { 'issues': [] });
    });

    test('analyze errors', () async {
      var json = {'source': sampleCodeError};
      var response = await _sendPostRequest('dartservices/v1/analyze', json);
      expect(response.status, 200);
      expect(response.headers['content-type'],
             'application/json; charset=utf-8');
      var data = await response.body.first;
      var expectedJson = {
        'issues': [
          {
            "kind": "error",
            "line": 2,
            "message": "Expected to find \';\'",
            "charStart": 29,
            "charLength": 1,
            "location": "main.dart"
          }
      ]};
      expect(JSON.decode(UTF8.decode(data)), expectedJson);
    });

    test('compile', () async {
      var json = {'source': sampleCode};
      var response = await _sendPostRequest('dartservices/v1/compile', json);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(JSON.decode(UTF8.decode(data)), isNotEmpty);
    });

    test('compile error', () async {
      var json = {'source': sampleCodeError};
      var response = await _sendPostRequest('dartservices/v1/compile', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
      expect(data['error']['message'], "Compilation failed with errors: "
          "[error, line 2] Expected ';' after this.");
    });

    test('complete', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 1};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 501);
    });

    test('complete no data', () async {
      var response = await _sendPostRequest('dartservices/v1/complete', {});
      expect(response.status, 400);
    });

    test('complete param missing', () async {
      var json = {'offset': 1};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['error']['message'], 'Required field source is missing');
    });

    test('complete param missing 2', () async {
      var json = {'source': 'void main() {print("foo");}'};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 17};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 2};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {"staticType": "void"}});
    });

    test('document no data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 12};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {}});
    });
  });
}

class MockLogger implements ServerLogger {
  StringBuffer builder = new StringBuffer();

  void info(String message) => builder.write('${message}\n');
  void warn(String message) => builder.write('${message}\n');
  void error(String message) => builder.write('${message}\n');

  void clear() => builder.clear();
  String getLog() => builder.toString();
}

class MockCache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}
