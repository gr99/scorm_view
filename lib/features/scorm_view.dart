import 'package:app/features/multipage/multi_page_screen.dart';
import 'package:app/features/scorm_view_model.dart';
import 'package:app/features/web_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScormView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ScormViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SCORM Viewer'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Radio(
                value: true,
                groupValue: viewModel.isUsingUrl,
                onChanged: (value) {
                  viewModel.toggleIsUsingUrl(true);
                },
              ),
              const Text('From URL'),
              Radio(
                value: false,
                groupValue: viewModel.isUsingUrl,
                onChanged: (value) {
                  viewModel.toggleIsUsingUrl(false);
                },
              ),
              const Text('From Local File'),
            ],
          ),
          if (viewModel.isUsingUrl)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: viewModel.urlController,
                decoration: const InputDecoration(
                  labelText: 'Enter SCORM ZIP URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                enabled: viewModel
                    .isUsingUrl, // Enable or disable based on the option
              ),
            ),
          if (!viewModel.isUsingUrl)
            Column(
              children: [
                ElevatedButton(
                  onPressed: viewModel.pickLocalFile,
                  child: const Text('Select Local SCORM ZIP'),
                ),
                if (viewModel.fileName.isNotEmpty)
                  Column(
                    children: [
                      Text('Selected file: ${viewModel.fileName}'),
                      Text('File size: ${viewModel.fileSize}'),
                    ],
                  ),
              ],
            ),
          ElevatedButton(
            onPressed: viewModel.onStartStopButtonPressed,
            child: Text(
              viewModel.isServerRunning ? 'Stop Server' : 'Start Server',
            ),
          ),
          if (viewModel.isDownloading)
            Column(
              children: [
                CircularProgressIndicator(),
                Text(
                    'Downloading: ${(viewModel.downloadProgress * 100).toStringAsFixed(2)}%'),
              ],
            ),
          if (viewModel.isExtracting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Extracting SCORM files...'),
            ),
          if (viewModel.serverMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(viewModel.serverMessage),
            ),
          if (viewModel.isServerRunning)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    new MaterialPageRoute(
                        builder: (BuildContext context) => new MultiPageScreen()
                        // new web_view_screen(url:'http://127.0.0.1:8080')

                    ));
              },
              child: const Text('Launch Course'),
            ),
          // Expanded(
          //   child: WebViewWidget(controller: viewModel.webViewController),
          // ),
        ],
      ),
    );
  }
}