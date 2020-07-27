// Copyright (c) 2016, project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'package:meta/meta.dart';
import 'src/request.dart';
import 'src/credentials.dart';
import 'package:http_client/http_client.dart' as http;
import 'package:xml/xml.dart';

/// AWS SQS (Simple Queue Service).
class Sqs {
  final Credentials _credentials;
  final http.Client _httpClient;

  /// AWS SQS
  Sqs({Credentials credentials, http.Client httpClient})
      : _credentials = credentials,
        _httpClient = httpClient {
    assert(this._credentials != null);
    assert(this._httpClient != null);
  }

  /// Returns a new SQS queue, inheriting the properties of this instance.
  SqsQueue queue(String queueUrl) => new SqsQueue(queueUrl,
      credentials: _credentials, httpClient: _httpClient);

  /// Create a new SQS queue
  Future<SqsQueue> create({@required String region, @required String queueName, String maxSize:'1024', String retentionPeriod:'345600', bool isFifo: false}) async {
    assert(region!='');
    assert(queueName!='');
    final endpoint = "https://sqs.${region}.amazonaws.com/";
    Map<String, String> parameters = {
      'Action': 'CreateQueue',
      'QueueName': queueName,
      'Attribute.1.Name': 'MaximumMessageSize',
      'Attribute.1.Value': maxSize,
      'Attribute.2.Name': 'MessageRetentionPeriod',
      'Attribute.2.Value': retentionPeriod
    };
    if (isFifo){
      parameters.addAll({
        'Attribute.3.Name': 'FifoQueue',
        'Attribute.3.Value': 'true'
      });
      parameters['QueueName'] = parameters['QueueName'] + ".fifo";
    }
    AwsResponse response = await new AwsRequestBuilder(
      method: 'GET',
      baseUrl: endpoint,
      queryParameters: parameters,
      credentials: this._credentials,
      httpClient: this._httpClient,
    ).sendRequest();
    final txt_resp = await response.readAsString();
    print(txt_resp);
    XmlDocument xml = parse(txt_resp);
    response.validateStatus();
    final url = xml.findAllElements('QueueUrl').first.text;
    return this.queue(url);
  }
}

/// AWS SQS message.
class SqsMessage {
  /// The message ID
  final String messageId;

  /// The receipt handle that can be used to delete the message from the queue.
  final String receiptHandle;

  /// The message body.
  final String body;

  /// AWS SQS message.
  SqsMessage(this.messageId, this.receiptHandle, this.body);

  @override
  String toString() => '[$messageId, $receiptHandle, $body]';
}

/// AWS SQS Queue
class SqsQueue {
  final String _queueUrl;
  final Credentials _credentials;
  final http.Client _httpClient;

  ///
  SqsQueue(
    String queueUrl, {
    Credentials credentials,
    http.Client httpClient,
  })  : _credentials = credentials,
        _httpClient = httpClient,
        _queueUrl = queueUrl {
    assert(this._credentials != null);
    assert(this._httpClient != null);
    assert(this._queueUrl != null);
  }

  String get queueUrl => _queueUrl;
  
  /// Receives a single message from the queue.
  Future<SqsMessage> receiveOne({int waitSeconds}) async {
    List<SqsMessage> messages =
        await receiveMessage(1, waitSeconds: waitSeconds);
    if (messages.isEmpty) return null;
    return messages.first;
  }

  /// Receives up to 10 (or up to [number], whichever is lower) messages from
  /// the queue.
  ///
  /// The call will block up to [waitSeconds] if there are not enough messages
  /// available immediately.
  ///
  /// http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ReceiveMessage.html
  Future<List<SqsMessage>> receiveMessage(int number, {int waitSeconds, int retry:3}) async {
    assert(number > 0);
    Map<String, String> parameters = {
      'Action': 'ReceiveMessage',
      'MaxNumberOfMessages': number.toString(),
      'VisibilityTimeout': '360',
      'Version': '2012-11-05',
    };
    if (waitSeconds != null) {
      parameters['WaitTimeSeconds'] = waitSeconds.toString();
    }
    var lastE;
    for(var i=0; i<retry; i++){
      try {
        AwsResponse response = await new AwsRequestBuilder(
          method: 'POST',
          baseUrl: _queueUrl,
          formParameters: parameters,
          credentials: _credentials,
          httpClient: _httpClient,
        ).sendRequest(timeout: 22);
        response.validateStatus();
        XmlDocument xml = parse(await response.readAsString());
        return xml
            .findAllElements('Message')
        // LOW PRIORITY: check MD5 signature
            .map((XmlElement elem) =>
        new SqsMessage(
          elem
              .findElements('MessageId')
              .first
              .text,
          elem
              .findElements('ReceiptHandle')
              .first
              .text,
          elem
              .findElements('Body')
              .first
              .text,
        ))
            .toList();
      } on Exception catch (e){
        lastE = e;
      }
    }
    if (lastE!=null){
      throw lastE;
    }
  }

  /// Delete a message from the queue by its [receiptHandle].
  ///
  /// http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_DeleteMessage.html
  Future deleteMessage(String receiptHandle, {int retry:3}) async {
    Map<String, String> parameters = {
      'Action': 'DeleteMessage',
      'ReceiptHandle': receiptHandle,
      'Version': '2012-11-05',
    };
    var lastE;
    for(var i=0; i<retry; i++) {
      try {
        AwsResponse response = await new AwsRequestBuilder(
          method: 'POST',
          baseUrl: _queueUrl,
          formParameters: parameters,
          credentials: _credentials,
          httpClient: _httpClient,
        ).sendRequest(timeout: 10);
        response.validateStatus();
        return;
      }
      on Exception catch (e){
        lastE = e;
      }
    }
    if (lastE!=null){
      throw lastE;
    }
  }

  Future deleteMassges(List<String> receiptHandles, {int retry:3}) async {
    Map<String, String> parameters = {
      'Action': 'DeleteMessageBatch',
      'Version': '2012-11-05',
    };
    int _idx = 1;
    for(String handle in receiptHandles){
        final key1 = "DeleteMessageBatchRequestEntry.$_idx.Id";
        final key2 = "DeleteMessageBatchRequestEntry.$_idx.ReceiptHandle";
        parameters.addAll({
          key1: "msg$_idx",
          key2: handle
        });
        _idx++;
    }
    var lastE;
    for(var i=0; i<retry; i++) {
      try {
        AwsResponse response = await new AwsRequestBuilder(
          method: 'POST',
          baseUrl: _queueUrl,
          formParameters: parameters,
          credentials: _credentials,
          httpClient: _httpClient,
        ).sendRequest(timeout: 10);
        response.validateStatus();
        return;
      }
      on Exception catch (e){
        lastE = e;
      }
    }
    if (lastE!=null){
      throw lastE;
    }
  }


  /// Sends a new message into the queue.
  ///
  /// http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessage.html
  Future sendMessage(String body, {int retry:3, int timeout}) async {
    Map<String, String> parameters = {
      'Action': 'SendMessage',
      'MessageBody': body,
      'Version': '2012-11-05',
    };
    var lastE;
    for (var i = 0; i < retry; i++) {
      try {
        AwsResponse response = await new AwsRequestBuilder(
          method: 'POST',
          baseUrl: _queueUrl,
          formParameters: parameters,
          credentials: _credentials,
          httpClient: _httpClient,
        ).sendRequest(timeout: timeout);
        response.validateStatus();
        return;
      }
      on Exception catch (e) {
        lastE = e;
      }
    }
    if (lastE != null) {
      throw lastE;
    }
  }
}
