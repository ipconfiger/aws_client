import 'package:aws_client/aws_client.dart';
import 'package:aws_client/s3.dart';
import 'package:aws_client/src/credentials.dart';
import 'package:http_client/console.dart';
import "package:test/test.dart";

void main() {
  // Define the test
  /*
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
   */
  test("multi part upload", () async {
    ConsoleClient httpClient = new ConsoleClient();
    final client = new S3(
        credentials: Credentials(accessKey: "", secretKey: ""),
        region: "us-west-1",
        httpClient: httpClient);
    final bucketName = 'testforbigbigeye';
    final fileKey = 'mt.txt';
    final rpInit = await client.initPartialUpload(bucketName, fileKey);
    AwsXmlResponse reponseInit = AwsXmlResponse(await rpInit.readAsString());
    reponseInit.raiseException();
    print("response dict:${reponseInit.responseDict}");

    final uploadId = reponseInit.getKey('UploadId');

    final data = [
      [50, 51, 52, 53, 54, 55, 56, 57],
      [60, 61, 62, 63, 64, 65, 66, 67],
      [70, 71, 72, 73, 74, 75, 76, 77]
    ];
    final etags = <String>[];
    for (int i = 0; i < data.length; i++) {
      final upResp = await client.partialUpload(
          bucketName, fileKey, uploadId, i + 1, data[i]);
      print('${upResp.headers}');
      etags.add(upResp.headers['etag']);
    }

    final completeResp = await client.completeMultipartUpload(
        bucketName, fileKey, uploadId, etags);
    print(completeResp.readAsString());

    expect(true, true);
  });
}
