import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_client/http_client.dart' as http;
import 'package:xml/xml.dart';

import 'src/credentials.dart';
import 'src/request.dart';

export 'src/request.dart';

/// AWS SQS (Simple Queue Service).
class S3 {
  /// AWS SQS
  S3({Credentials credentials, String region, http.Client httpClient})
      : _credentials = credentials,
        _httpClient = httpClient,
        _region = region {
    assert(this._credentials != null);
    assert(this._httpClient != null);
    assert(this._region != null);
  }

  final Credentials _credentials;
  final http.Client _httpClient;
  final String _region;

  /// execute real request
  Future<AwsResponse> _sendRequest(
      String method,
      String bucketName,
      Map<String, String> headers,
      Map<String, String> parameters,
      List<int> body,
      String key,
      {int timeout: 180,
      int retry: 3,
      String extra: ''}) async {
    final endpoint = 'https://$bucketName.s3-$_region.amazonaws.com/$key$extra';
    try {
      AwsResponse response;
      if (body != null) {
        response = await new AwsRequestBuilder(
                method: method,
                baseUrl: endpoint,
                headers: headers,
                queryParameters: parameters,
                body: body,
                credentials: this._credentials,
                httpClient: this._httpClient,
                region: _region,
                service: "s3")
            .sendRequest(timeout: timeout);
      } else {
        response = await new AwsRequestBuilder(
                method: method,
                baseUrl: endpoint,
                headers: headers,
                queryParameters: parameters,
                credentials: this._credentials,
                httpClient: this._httpClient,
                region: _region,
                service: "s3")
            .sendRequest(timeout: timeout);
      }
      try {
        response.validateStatus();
      } on AwsAuthException catch (e) {
        print("${await response.readAsString()}");
        throw e;
      }

      return response;
    } on Exception catch (e) {
      throw e;
    }
  }

  Future<String> putObject(
      String bucketName, String objectKey, Uint8List fileData,
      {int timeout: 180}) async {
    final headers = <String, String>{};
    headers['Content-Length'] = "${fileData.length}";
    headers['X-Amz-Acl'] = 'public-read';
    final resp = await this._sendRequest(
        'PUT', bucketName, headers, null, fileData.toList(), objectKey,
        timeout: timeout);
    return await resp.readAsString();
  }

  Future rmObject(String bucketName, String objectKey,
      {int timeout: 30}) async {
    final headers = <String, String>{};
    final resp = await this._sendRequest(
        'DELETE', bucketName, headers, <String, String>{}, null, objectKey,
        timeout: timeout);
  }

  /// init partial upload request get upload id
  Future<AwsResponse> initPartialUpload(String bucketName, String objectKey,
      {int timeout: 180}) async {
    final headers = <String, String>{};
    headers['X-Amz-Acl'] = 'public-read';
    final resp = await this._sendRequest(
        'POST', bucketName, headers, null, null, objectKey,
        timeout: timeout, extra: "?uploads");
    return resp;
  }

  Future<AwsResponse> partialUpload(String bucketName, String objectKey,
      String uploadId, int partNumber, List<int> data,
      {int timeout: 180}) async {
    final params = <String, String>{};
    params["partNumber"] = '$partNumber';
    params["uploadId"] = uploadId;
    final resp = await this._sendRequest(
        'PUT', bucketName, null, params, data, objectKey,
        timeout: timeout);
    return resp;
  }

  /// complete partial upload
  Future<AwsResponse> completeMultipartUpload(
      String bucketName, String objectKey, String uploadId, List<String> etags,
      {int timeout: 180}) async {
    final params = {"uploadId": uploadId};
    final builder = XmlBuilder();
    builder.element("CompleteMultipartUpload", nest: () {
      for (var i = 0; i < etags.length; i++) {
        builder.element("Part", nest: () {
          builder.element("PartNumber", nest: () {
            builder.text("${i + 1}");
          });
          builder.element("ETag", nest: () {
            builder.text("${etags[i]}");
          });
        });
      }
    });
    final xml_request = builder.buildDocument().toXmlString();
    print("complete xml:\n$xml_request");
    final resp = await this._sendRequest(
        'POST', bucketName, null, params, utf8.encode(xml_request), objectKey,
        timeout: timeout);
    return resp;
  }
}
