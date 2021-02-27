import 'dart:async';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'src/request.dart';
import 'src/credentials.dart';
import 'package:http_client/http_client.dart' as http;

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
  Future<String> _sendRequest(
      String method,
      String bucketName,
      Map<String, String> headers,
      Map<String, String> parameters,
      List<int> body,
      String key,
      {int retry:3}
      ) async {

    final endpoint = 'https://$bucketName.s3.amazonaws.com/$key';
    try {
      AwsResponse response;
      if (body != null){
        response = await new AwsRequestBuilder(
          method: method,
          baseUrl: endpoint,
          headers: headers,
          body:body,
          credentials: this._credentials,
          httpClient: this._httpClient,
          region: _region,
            service: "s3"
        ).sendRequest(timeout: 10);

      }else{
        response = await new AwsRequestBuilder(
          method: method,
          baseUrl: endpoint,
          headers: headers,
          formParameters: parameters,
          credentials: this._credentials,
          httpClient: this._httpClient,
            region: _region,
            service: "s3"
        ).sendRequest(timeout: 10);

      }
      final respString = await response.readAsString();
      print('resp:${respString}');
      response.validateStatus();
      return respString;
    } on Exception catch (e){
      throw e;
    }

  }


  Future<String> putObject(String bucketName, String objectKey, Uint8List fileData) async {
    final headers = <String, String>{};
    headers['Content-Length'] = "${fileData.length}";
    headers['X-Amz-Acl'] = 'public-read';
    final resp = await this._sendRequest('PUT', bucketName, headers, null, fileData.toList(), objectKey);
    return resp;
  }

  Future rmObject(String bucketName, String objectKey) async {
    final headers = <String, String>{};
    final resp = await this._sendRequest('DELETE', bucketName, headers, <String, String>{}, null, objectKey);
    print(resp);
  }



}