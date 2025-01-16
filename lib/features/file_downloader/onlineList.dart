import 'dart:io';
import 'package:app/features/file_downloader/offline_downloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

class OnlineList extends StatefulWidget with WidgetsBindingObserver {
  @override
  _OnlineListState createState() => _OnlineListState();
}

class _OnlineListState extends State<OnlineList> {
  final _urls = [
    'https://www.ludiscape.com/chamilo/plugins/scorm-packages/ScormBilanMoodle.zip',
    'https://www.ludiscape.com/chamilo/plugins/scorm-packages/ScormBilanChamilo.zip'
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online links'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfflineDownloads(),
          ),
        ),
        label: const Text('Downloads'),
      ),
      body: ListView.builder(
        itemCount: _urls.length,
        itemBuilder: (BuildContext context, int i) {
          String _fileName = 'File ${i + 1}';
          return Card(
            elevation: 10,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_fileName),
                    ),
                    RawMaterialButton(
                      textStyle: const TextStyle(color: Colors.blueGrey),
                      onPressed: () => requestDownload(_urls[i], _fileName),
                      child: const Icon(Icons.file_download),
                    )
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> requestDownload(String _url, String _name) async {
    final dir =
        await getApplicationDocumentsDirectory(); //From path_provider package
    var _localPath = dir.path + _name;
    final savedDir = Directory(_localPath);
    await savedDir.create(recursive: true).then((value) async {
      String? _taskid = await FlutterDownloader.enqueue(
        url: _url,
        fileName: _name,
        savedDir: _localPath,
        showNotification: true,
        openFileFromNotification: false,
      );
      print(_taskid);
    });
  }
}
