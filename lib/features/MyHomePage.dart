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

  Future<void> _downloadAndExtractSCORM(String url) async {
    final Directory appDocDir = await getTemporaryDirectory();
    _scormDirectory = '${appDocDir.path}/scorm_package/';
    final scormDir = Directory(_scormDirectory);
    if (!scormDir.existsSync()) {
      scormDir.createSync(recursive: true);
    }

    final File scormZipFile = File('${appDocDir.path}/scorm.zip');

    // Download the SCORM ZIP file from the URL
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await scormZipFile.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download SCORM ZIP');
    }

    // Unzip the SCORM package
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
      // Use the href to load the starting page in the WebView
      // _webViewController.loadRequest(Uri.parse('$_serverUrl/$href'));
      pageUrl='$_serverUrl/$href';
    } else {
      throw Exception('No launch URL found in imsmanifest.xml');
    }
  }

  // Start a local server to serve unzipped SCORM files
  Future<void> _startServer() async {
    final staticHandler = createStaticHandler(_scormDirectory, defaultDocument: 'index.html');

    final handler = const Pipeline()
        .addMiddleware(logRequests()) // Log requests for debugging
        .addHandler(staticHandler); // Serve static files

    _server = await shelf_io.serve(handler, '127.0.0.1', 8080);
    print('Server running at http://${_server.address.host}:${_server.port}');

    setState(() {
      _serverUrl = 'http://${_server.address.host}:${_server.port}';
      _isServerRunning = true;
    });

    // Load the SCORM content into WebView
    _webViewController..loadRequest(Uri.parse('$pageUrl'));
  }

  // Stop the local server
  void _stopServer() async {
    // Close the server
    await _server.close();

    // Delete the temporary SCORM directory and its contents
    final scormDir = Directory(_scormDirectory);
    if (scormDir.existsSync()) {
      // Delete the directory and all its contents
      scormDir.deleteSync(recursive: true);
    }

    // Show a SnackBar to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("SCORM files have been deleted and the server stopped.")),
    );

    // Update the state to reflect that the server is no longer running
    setState(() {
      _isServerRunning = false;
    });
  }


  // Button to trigger server actions (start/stop)
  void _onStartStopButtonPressed() async {
    if (_isServerRunning) {
      _stopServer();
    } else {
      final scormUrl = _urlController.text;
      if (scormUrl.isNotEmpty) {
        await _downloadAndExtractSCORM(scormUrl);
        _startServer();
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
          Expanded(
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }
}
