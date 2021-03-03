import 'dart:convert';
import 'dart:typed_data';

import 'package:aws_client/s3.dart';
import 'package:aws_client/src/credentials.dart';
import 'package:http_client/console.dart';
import "package:test/test.dart";

void main() {
  // Define the test
  test("put object", () async {
    ConsoleClient httpClient = new ConsoleClient();
    final client = new S3(
        credentials: Credentials(accessKey: "", secretKey: ""),
        region: "us-west-1",
        httpClient: httpClient);
    final resp = await client.putObject("testforbigbigeye", "test.txt",
        Uint8List.fromList(utf8.encode("test content")));
    print(resp);
    expect(true, true);
  });

  test("del object", () async {
    ConsoleClient httpClient = new ConsoleClient();
    final client = new S3(
        credentials: Credentials(accessKey: "", secretKey: ""),
        region: "us-west-1",
        httpClient: httpClient);
    await client.rmObject("", "test.txt");
    expect(true, true);
  });

  test("multi part upload", () async {
    ConsoleClient httpClient = new ConsoleClient();
    final client = new S3(
        credentials: Credentials(accessKey: "", secretKey: ""),
        region: "us-west-1",
        httpClient: httpClient);
  });
}
