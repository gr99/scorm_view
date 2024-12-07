import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:archive/archive.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebViewController _webViewController;
  late HttpServer _server;
  final TextEditingController _urlController = TextEditingController();
  bool _isServerRunning = false;
  String _scormDirectory = "";
  String _serverUrl = "http://127.0.0.1:8080";
  late String pageUrl;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isExtracting = false;
  String _serverMessage = "";

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  // Initialize WebView
  Future<void> _initializeWebView() async {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint("Loading: $progress%");
          },
          onPageStarted: (String url) {
            debugPrint("Page started: $url");
          },
          onPageFinished: (String url) {
            debugPrint("Page finished: $url");
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("Error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  // Download SCORM ZIP and extract it
  Future<void> _downloadAndExtractSCORM(String url) async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final Directory appDocDir = await getTemporaryDirectory();
      _scormDirectory = '${appDocDir.path}/scorm_package/';
      final scormDir = Directory(_scormDirectory);
      if (!scormDir.existsSync()) {
        scormDir.createSync(recursive: true);
      }

      final File scormZipFile = File('${appDocDir.path}/scorm.zip');

      // Download the SCORM ZIP file from the URL
      final request = http.Client();
      final response = await request.send(http.Request('GET', Uri.parse(url)));

      final contentLength = response.contentLength;
      int bytesReceived = 0;
      List<int> downloadedBytes = [];

      // Listen to the stream for progress
      await for (var chunk in response.stream) {
        bytesReceived += chunk.length;
        downloadedBytes.addAll(chunk); // Collect the chunk data
        setState(() {
          _downloadProgress = contentLength != null ? bytesReceived / contentLength : 0.0;
        });
      }

      if (response.statusCode == 200) {
        // Save the downloaded bytes to a file
        await scormZipFile.writeAsBytes(downloadedBytes);
        await _extractSCORMPackage(scormZipFile);  // Pass the file to extract
        setState(() {
          _isDownloading = false; // Hide the downloading loader once the download is complete
        });
      } else {
        throw Exception('Failed to download SCORM ZIP');
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _serverMessage = "Error occurred: $e";
      });
      _stopServer(); // Stop the server in case of error
      _clearFiles(); // Delete any temporary files
    }
  }

  // Extract the SCORM ZIP package
  Future<void> _extractSCORMPackage(File scormZipFile) async {
    try {
      setState(() {
        _isExtracting = true;
      });

      // Extract the SCORM zip package using the saved file
      final bytes = await scormZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Write the extracted files to the directory
      for (var file in archive) {
        final String filename = '$_scormDirectory${file.name}';
        final outFile = File(filename);
        if (file.isFile) {
          final fileDir = Directory(outFile.parent.path);
          if (!fileDir.existsSync()) {
            fileDir.createSync(recursive: true);
          }
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }

      // Now, parse the imsmanifest.xml to get the launch URL
      final manifestFile = File('$_scormDirectory/imsmanifest.xml');
      final manifestContent = await manifestFile.readAsString();
      final document = xml.XmlDocument.parse(manifestContent);

      // Extract the href attribute from the <resource> tag
      final href = document.findAllElements('resource').first.getAttribute('href');
      if (href != null) {
        pageUrl = '$_serverUrl/$href';
        setState(() {
          _isExtracting = false;
        });
        _startServer(); // Start the server after extraction
      } else {
        throw Exception('No launch URL found in imsmanifest.xml');
      }
    } catch (e) {
      setState(() {
        _isExtracting = false;
        _serverMessage = "Error occurred during extraction: $e";
      });
      _stopServer(); // Stop the server in case of error
      _clearFiles(); // Delete any temporary files
    }
  }

  // Start a local server to serve unzipped SCORM files
  Future<void> _startServer() async {
    try {
      setState(() {
        _serverMessage = "Starting the server...";
      });

      final staticHandler =
      createStaticHandler(_scormDirectory, defaultDocument: 'index.html');

      final handler = const Pipeline()
          .addMiddleware(logRequests()) // Log requests for debugging
          .addHandler(staticHandler); // Serve static files

      _server = await shelf_io.serve(handler, '127.0.0.1', 8080);
      setState(() {
        _serverUrl = 'http://${_server.address.host}:${_server.port}';
        _isServerRunning = true;
        _serverMessage = 'Server running at $_serverUrl';
      });

      // Load the SCORM content into WebView
      _webViewController.loadRequest(Uri.parse(pageUrl));
    } catch (e) {
      setState(() {
        _serverMessage = "Error occurred while starting the server: $e";
      });
      _stopServer(); // Stop the server in case of error
      _clearFiles(); // Delete any temporary files
    }
  }

  // Stop the server and delete SCORM directory
  void _stopServer() async {
    try {
      setState(() {
        _serverMessage = "Stopping server...";
      });

      // Close the server
      await _server.close();

      // Delete the temporary SCORM directory and its contents
      _clearFiles();

      // Show a SnackBar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SCORM files have been deleted and the server stopped.")),
      );

      // Reset WebView to a blank page or placeholder
      _webViewController.loadHtmlString('<H1>Stopped</H1>');

      // Update the state to reflect that the server is no longer running
      setState(() {
        _isServerRunning = false;
        _serverMessage = "";
      });
    } catch (e) {
      setState(() {
        _serverMessage = "Error occurred while stopping the server: $e";
      });
    }
  }

  // Clear the downloaded SCORM files
  void _clearFiles() {
    final scormDir = Directory(_scormDirectory);
    if (scormDir.existsSync()) {
      // Delete the directory and all its contents
      scormDir.deleteSync(recursive: true);
    }
  }

  // Button to trigger server actions (start/stop)
  void _onStartStopButtonPressed() async {
    if (_isServerRunning) {
      _stopServer();
    } else {
      final scormUrl = _urlController.text;
      if (scormUrl.isNotEmpty) {
        await _downloadAndExtractSCORM(scormUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a valid SCORM URL")),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    if (_isServerRunning) {
      _stopServer();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCORM Viewer'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter SCORM ZIP URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          ElevatedButton(
            onPressed: _onStartStopButtonPressed,
            child: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
          ),
          if (_isDownloading)
            Column(
              children: [
                CircularProgressIndicator(),
                Text(
                    'Downloading: ${(_downloadProgress * 100).toStringAsFixed(2)}%'),
              ],
            ),
          if (_isExtracting)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Extracting SCORM files...'),
            ),
          if (_serverMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_serverMessage),
            ),
          Expanded(
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }
}
