// Copyright (c) 2016, project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:aws_client/s3.dart';
import 'package:http_client/http_client.dart' as http;
import 'package:xml/xml.dart';

import 'sns.dart';
import 'sqs.dart';
import 'src/credentials.dart';

/// AWS access facade that helps to initialize multiple services with common
/// settings (credentials and HTTP client).
class Aws {
  final Credentials _credentials;
  final http.Client _httpClient;

  Sqs _sqs;

  ///
  // ignore: sort_constructors_first
  Aws({Credentials credentials, http.Client httpClient})
      : _credentials = credentials,
        _httpClient = httpClient {
    assert(this._credentials != null);
    assert(this._httpClient != null);
  }

  /// Returns an SQS service, inheriting the properties of this instance.
  Sqs get sqs =>
      _sqs ??= new Sqs(credentials: _credentials, httpClient: _httpClient);

  /// Returns an SNS service, inheriting the properties of this instance.
  Sns sns(String region) => new Sns(
      credentials: _credentials, httpClient: _httpClient, region: region);

  /// Return an S3 service
  S3 s3(String region) => new S3(
      credentials: _credentials, httpClient: _httpClient, region: region);
}

/// Exception used to execute response
class AwsResponseException implements Exception {
  /// Err constuctor
  AwsResponseException(this.errStr);

  /// error message
  String errStr;

  /// return err message
  String errMsg() => this.errStr;
  @override
  String toString() => this.errStr;
}

/// Execute Xml Response
class AwsXmlResponse {
  /// constuctor from xml string
  AwsXmlResponse(this.respTxt) {
    print("resp:${this.respTxt}");
    this.respRoot = XmlDocument.parse(this.respTxt);
  }

  /// xml String
  String respTxt;

  /// xml node
  XmlDocument respRoot;

  /// dict response
  Map<String, String> responseDict;

  /// check if return faild
  void raiseException() {
    final rootTagName = this.respRoot.rootElement.name;
    // ignore: literal_only_boolean_expressions
    if ('$rootTagName' != "Error") {
      final root = this.respRoot.children[2];
      responseDict = <String, String>{};
      root.children.forEach((node) {
        if (node.nodeType == XmlNodeType.ELEMENT) {
          final tagName = (node as XmlElement).name.toString();
          final value = node.text;
          responseDict.addAll({tagName: value});
        }
      });
    } else {
      throw AwsResponseException(this.respRoot.children[2].toXmlString());
    }
  }

  /// get data from dict
  String getKey(String key) {
    return responseDict.containsKey(key) ? responseDict[key] : '';
  }
}
