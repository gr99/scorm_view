import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class OfflineDownloads extends StatefulWidget with WidgetsBindingObserver {
  @override
  _OfflineDownloadsState createState() => _OfflineDownloadsState();
}

class _OfflineDownloadsState extends State<OfflineDownloads> {
  final ReceivePort _port = ReceivePort();
  List<Map> downloadsListMaps = [];

  @override
  void initState() {
    super.initState();
    task();
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      int progress = data[2];

      // Find the task by its ID and update the progress and status
      var task = downloadsListMaps.firstWhere(
        (element) => element['id'] == id,
      );

      if (task != null) {
        setState(() {
          task['progress'] = progress;
          task['status'] = status;
        });
      }
    });
  }

  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  Future task() async {
    List<DownloadTask>? getTasks = await FlutterDownloader.loadTasks();
    getTasks?.forEach((_task) {
      Map _map = Map();
      _map['status'] = _task.status;
      _map['progress'] = _task.progress;
      _map['id'] = _task.taskId;
      _map['filename'] = _task.filename;
      _map['savedDirectory'] = _task.savedDir;
      downloadsListMaps.add(_map);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Downloads'),
      ),
      body: downloadsListMaps.isEmpty
          ? const Center(child: Text("No Downloads yet"))
          : ListView.builder(
              itemCount: downloadsListMaps.length,
              itemBuilder: (BuildContext context, int i) {
                Map _map = downloadsListMaps[
                    downloadsListMaps.length - 1 - i]; // Reversed order
                String _filename = _map['filename'];
                int _progress = _map['progress'];
                DownloadTaskStatus _status = _map['status'];
                String _id = _map['id'];
                String _savedDirectory = _map['savedDirectory'];
                List<FileSystemEntity> _directories =
                    Directory(_savedDirectory).listSync(followLinks: true);
                FileSystemEntity? _file =
                    _directories.isNotEmpty ? _directories.first : null;

                return GestureDetector(
                  onTap: () {
                    if (_status == DownloadTaskStatus.complete) {
                      showDialogue(_file!);
                    }
                  },
                  child: Card(
                    elevation: 10,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ListTile(
                          isThreeLine: false,
                          title: Text(_filename),
                          subtitle: downloadStatus(_status),
                          trailing: SizedBox(
                            width: 60,
                            child: buttons(
                                _status, _id, downloadsListMaps.length - 1 - i),
                          ),
                        ),
                        _status == DownloadTaskStatus.complete
                            ? Container()
                            : const SizedBox(height: 5),
                        _status == DownloadTaskStatus.complete
                            ? Container()
                            : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text('$_progress%'),
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: _progress / 100,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 10)
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget downloadStatus(DownloadTaskStatus _status) {
    return _status == DownloadTaskStatus.canceled
        ? const Text('Download canceled')
        : _status == DownloadTaskStatus.complete
            ? const Text('Download completed')
            : _status == DownloadTaskStatus.failed
                ? const Text('Download failed')
                : _status == DownloadTaskStatus.paused
                    ? const Text('Download paused')
                    : _status == DownloadTaskStatus.running
                        ? const Text('Downloading..')
                        : const Text('Download waiting');
  }

  Widget buttons(DownloadTaskStatus _status, String taskid, int index) {
    void changeTaskID(String taskid, String newTaskID) {
      Map? task = downloadsListMaps.firstWhere(
        (element) => element['id'] == taskid,
      );
      task?['id'] = newTaskID;
      setState(() {});
    }

    return _status == DownloadTaskStatus.canceled
        ? GestureDetector(
            child: const Icon(Icons.cached, size: 20, color: Colors.green),
            onTap: () {
              FlutterDownloader.retry(taskId: taskid).then((newTaskID) {
                changeTaskID(taskid, newTaskID!);
              });
            },
          )
        : _status == DownloadTaskStatus.failed
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    child:
                        const Icon(Icons.cached, size: 20, color: Colors.green),
                    onTap: () {
                      FlutterDownloader.retry(taskId: taskid).then((newTaskID) {
                        changeTaskID(taskid, newTaskID!);
                      });
                    },
                  ),
                  GestureDetector(
                    child:
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                    onTap: () {
                      downloadsListMaps.removeAt(index);
                      FlutterDownloader.remove(
                          taskId: taskid, shouldDeleteContent: true);
                      setState(() {});
                    },
                  )
                ],
              )
            : _status == DownloadTaskStatus.paused
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      GestureDetector(
                        child: const Icon(Icons.play_arrow,
                            size: 20, color: Colors.blue),
                        onTap: () {
                          FlutterDownloader.resume(taskId: taskid).then(
                            (newTaskID) => changeTaskID(taskid, newTaskID!),
                          );
                        },
                      ),
                      GestureDetector(
                        child: const Icon(Icons.close,
                            size: 20, color: Colors.red),
                        onTap: () {
                          FlutterDownloader.cancel(taskId: taskid);
                        },
                      )
                    ],
                  )
                : _status == DownloadTaskStatus.running
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          GestureDetector(
                            child: const Icon(Icons.pause,
                                size: 20, color: Colors.green),
                            onTap: () {
                              FlutterDownloader.pause(taskId: taskid);
                            },
                          ),
                          GestureDetector(
                            child:
                                const Icon(Icons.close, size: 20, color: Colors.red),
                            onTap: () {
                              FlutterDownloader.cancel(taskId: taskid);
                            },
                          )
                        ],
                      )
                    : _status == DownloadTaskStatus.complete
                        ? GestureDetector(
                            child: const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            onTap: () {
                              downloadsListMaps.removeAt(index);
                              FlutterDownloader.remove(
                                  taskId: taskid, shouldDeleteContent: true);
                              setState(() {});
                            },
                          )
                        : Container();
  }

  showDialogue(FileSystemEntity file) {
    return showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Container(
                  // child: Image.file(
                  //   file,
                  //   fit: BoxFit.cover,
                  // ),
                  ),
            ),
          );
        });
  }
}
