
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:archive/archive.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:flutter/services.dart';

class ScormViewModel extends ChangeNotifier {
  // late WebViewController _webViewController;
  late HttpServer _server;
  final TextEditingController urlController = TextEditingController();

  bool _isServerRunning = false;
  String _scormDirectory = "";
  String _serverUrl = "http://127.0.0.1:8080";
  late String pageUrl;

  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isExtracting = false;
  String _serverMessage = "";
  bool _isUsingUrl = true; // Toggle for URL or local file

  // WebViewController get webViewController => _webViewController;

  bool get isServerRunning => _isServerRunning;

  bool get isDownloading => _isDownloading;

  bool get isExtracting => _isExtracting;

  double get downloadProgress => _downloadProgress;

  String get serverMessage => _serverMessage;

  bool get isUsingUrl => _isUsingUrl;

  String _fileName = '';
  String _fileSize = '';

  // Other properties...

  String get fileName => _fileName;

  String get fileSize => _fileSize;

  ScormViewModel() {
    // _initializeWebView();
  }

  // Future<void> _initializeWebView() async {
  //   _webViewController = WebViewController()
  //     ..enableZoom(true)
  //     ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //     ..setNavigationDelegate(NavigationDelegate(
  //       onProgress: (int progress) {
  //         debugPrint("Loading: $progress%");
  //       },
  //       onPageStarted: (String url) {
  //         debugPrint("Page started: $url");
  //       },
  //       onPageFinished: (String url) async {
  //         debugPrint("Page finished: $url");
  //       },
  //       onWebResourceError: (WebResourceError error) {
  //         debugPrint("Error: ${error.description}");
  //       },
  //       onNavigationRequest: (NavigationRequest request) {
  //
  //         return NavigationDecision.navigate;
  //       },
  //     ));
  // }

  void toggleIsUsingUrl(bool value) {
    _isUsingUrl = value;
    notifyListeners();
  }

  Future<void> pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      _fileName = result.files.single.name;
      _fileSize =
      '${(await file.length() / (1024 * 1024)).toStringAsFixed(2)} MB'; // Convert bytes to MB

      notifyListeners();
    }
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.single.path;
      if (path != null) {
        await downloadAndExtractSCORM(path);
      }
    }
  }

  void onStartStopButtonPressed() async {
    if (_isServerRunning) {
      stopServer();
    } else {
      final scormUrl = urlController.text;
      if (scormUrl.isNotEmpty) {
        await downloadAndExtractSCORM(scormUrl);
      } else {
        _serverMessage = "Please enter a valid SCORM URL";
        notifyListeners();
      }
    }
  }

  Future<void> downloadAndExtractSCORM(String input) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _scormDirectory = '${appDocDir.path}/scorm_player/';

      // Create the base SCORM directory
      final scormBaseDir = Directory(_scormDirectory);
      if (!scormBaseDir.existsSync()) {
        scormBaseDir.createSync(recursive: true);
      }

      final Directory extractedDir = Directory('${_scormDirectory}scorm/');
      if (!extractedDir.existsSync()) {
        extractedDir.createSync(recursive: true);
      }

      if (_isUsingUrl) {
        // Handle input as URL for downloading
        _isDownloading = true;
        notifyListeners();

        final File scormZipFile = File('${appDocDir.path}/scorm.zip');

        final request = http.Client();
        final response = await request
            .send(http.Request('GET', Uri.parse(input)))
            .timeout(Duration(minutes: 30));

        final contentLength = response.contentLength;
        int bytesReceived = 0;
        List<int> downloadedBytes = [];

        await for (var chunk in response.stream) {
          bytesReceived += chunk.length;
          downloadedBytes.addAll(chunk);
          _downloadProgress =
          contentLength != null ? bytesReceived / contentLength : 0.0;
          notifyListeners();
        }

        if (response.statusCode == 200) {
          await scormZipFile.writeAsBytes(downloadedBytes);
          await _extractSCORMPackage(scormZipFile);
        } else {
          throw Exception('Failed to download SCORM ZIP');
        }
      } else {
        // Handle input as local file path
        final localFile = File(input);
        if (await localFile.exists()) {
          await _extractSCORMPackage(localFile);
        } else {
          throw Exception('Local file does not exist');
        }
      }
    } catch (e) {
      _handleError(e);
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _addRequiredFiles(String schemaVersion) async {
    // Create paths for additional JavaScript files
    final lmsJsFile = File('${_scormDirectory}lms.js');
    final commonJsFile = File('${_scormDirectory}common.js');
    final indexFile = File('${_scormDirectory}index.html');

    // Write the contents of the additional JS files to the SCORM directory
    await lmsJsFile.writeAsString(await rootBundle.loadString(
        'assets/scorm/lms.js')); // Make sure to add these files to your assets
    await commonJsFile.writeAsString(await rootBundle
        .loadString('assets/scorm/common.js')); // Same for common.js
    // Write the appropriate index.html based on the schema version
    if (schemaVersion.contains('2004')) {
      await indexFile.writeAsString(
          await rootBundle.loadString('assets/scorm/index2004.html'));
    } else {
      await indexFile.writeAsString(
          await rootBundle.loadString('assets/scorm/index.html'));
    }
    // else{
    //   throw Exception('Scorm version not found in imsmanifest.xml');
    // }
  }

  Future<void> _modifyIndexHtml(String entryPoint) async {
    final indexPath = '$_scormDirectory/index.html';
    final indexFile = File(indexPath);

    if (await indexFile.exists()) {
      String content = await indexFile.readAsString();
      // Replace the placeholder for the iframe source
      content = content.replaceAll('start_of_the_scrom', entryPoint);
      await indexFile.writeAsString(content);
    } else {
      throw Exception('index.html does not exist');
    }
  }

  Future<void> _extractSCORMPackage(File scormZipFile) async {
    try {
      _isExtracting = true;
      notifyListeners();

      final bytes = await scormZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Loop through each file in the archive
      for (var file in archive) {
        final String filename =
            '${_scormDirectory}scorm/${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9\-_\/\.]'), '_')}';
        final outFile = File(filename);
        if (file.isFile) {
          final fileDir = Directory(outFile.parent.path);
          if (!fileDir.existsSync()) {
            fileDir.createSync(recursive: true);
          }
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }

      final manifestFile = File('${_scormDirectory}scorm/imsmanifest.xml');
      final manifestContent = await manifestFile.readAsString();
      final document = xml.XmlDocument.parse(manifestContent);

      final href =
      document.findAllElements('resource').first.getAttribute('href');

      if (href != null) {
        var schemaVersion="1.4";
        try{
          schemaVersion  =document.findAllElements('schemaversion').first.innerText;
        }catch(e){

        }
        if (schemaVersion != null) {
          await _addRequiredFiles(schemaVersion);
          String entryPoint = 'scorm/$href';
          await _modifyIndexHtml(entryPoint);
          pageUrl =
          '$_serverUrl/$entryPoint'; // Update path for correct serving
          await _startServer();
        } else {
          throw Exception('No launch URL found in imsmanifest.xml');
        }
      } else {
        throw Exception('No launch URL found in imsmanifest.xml');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      _isExtracting = false;
      notifyListeners();
    }
  }

  Future<void> _startServer() async {
    try {
      final staticHandler =
      createStaticHandler(_scormDirectory, defaultDocument: 'index.html');
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(staticHandler);

      _server = await shelf_io.serve(handler, '127.0.0.1', 8080);
      _serverUrl = 'http://${_server.address.host}:${_server.port}';
      _isServerRunning = true;
      _serverMessage = 'Server running at $_serverUrl';
      notifyListeners();

    } catch (e) {
      _handleError(e);
    }
  }

  void stopServer() async {
    try {
      if (_isServerRunning) {
        await _server.close();
        clearFiles();
        // _webViewController.loadHtmlString('<H1>Stopped</H1>');
        _serverMessage = "";
        _isServerRunning = false;
        notifyListeners();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void clearFiles() {
    final scormDir = Directory('${_scormDirectory}scorm');
    if (scormDir.existsSync()) {
      scormDir.deleteSync(recursive: true);
      scormDir.createSync(recursive: true);
    }
  }


  void _handleError(Object error) {
    print("Error occurred: $error");
    _serverMessage = "Error occurred: $error";
    notifyListeners();
  }

  @override
  void dispose() {
    urlController.dispose();
    stopServer();
    super.dispose();
  }
}