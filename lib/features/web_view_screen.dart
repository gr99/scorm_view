import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class web_view_screen extends StatefulWidget {
  final String url;
  const web_view_screen({Key? key, required this.url}) : super(key: key);

  @override
  State<web_view_screen> createState() => _web_view_screenState();
}

class _web_view_screenState extends State<web_view_screen> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Popup Window"),
        ),
        body: Column(children: <Widget>[
          Expanded(
            child: InAppWebView(
              key: webViewKey,
              initialUrlRequest:URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onCreateWindow: (controller, createWindowAction) async {
                showDialog(
                  context: context,
                  builder: (context) {
                    return WindowPopup(createWindowAction: createWindowAction);
                  },
                );
                return true;
              },
            ),
          ),
        ]));
  }
}

class WindowPopup extends StatefulWidget {
  final CreateWindowAction createWindowAction;

  const WindowPopup({Key? key, required this.createWindowAction})
      : super(key: key);

  @override
  State<WindowPopup> createState() => _WindowPopupState();
}

class _WindowPopupState extends State<WindowPopup> {
  String title = '';

  @override
  Widget build(BuildContext context) {
    // Get the screen size using MediaQuery
    final screenSize = MediaQuery.of(context).size;

    return AlertDialog(
      insetPadding: EdgeInsets.zero, // Remove the default padding
      contentPadding: EdgeInsets.zero, // Remove the default content padding
      content: SizedBox(
        width: screenSize.width, // Set width to screen width
        height: screenSize.height, // Set height to screen height
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InAppWebView(
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                  ),
                },
                windowId: widget.createWindowAction.windowId,
                onTitleChanged: (controller, title) {
                  setState(() {
                    this.title = title ?? '';
                  });
                },
                onCloseWindow: (controller) {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

