import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

/// Implements the plugin interface using the Webview interface (currently used
/// by Windows and Linux).
class FlutterWebAuth2WebViewPlugin extends FlutterWebAuth2Platform {
  bool _authenticated = false;

  /// Webview instance.
  Webview? webview;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) async {
    if (!await WebviewWindow.isWebviewAvailable()) {
      // Microsoft's WebView2 must be installed for this to work
      throw StateError('Webview is not available');
    }
    // Reset
    _authenticated = false;
    webview?.close();

    final c = Completer<String>();
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowHeight: 720,
        windowWidth: 1280,
        title: 'Authenticate',
        titleBarTopPadding: 0,
        userDataFolderWindows: (await getTemporaryDirectory()).path,
      ),
    );
    webview!.addOnUrlRequestCallback((url) {
      final uri = Uri.parse(url);
      if (uri.scheme == callbackUrlScheme) {
        _authenticated = true;
        webview?.close();
        /**
         * Not setting the webview to null will cause a crash if the
         * application tries to open another webview
         */
        webview = null;
        c.complete(url);
      }
    });
    unawaited(
      webview!.onClose.whenComplete(
        () {
          /**
           * Not setting the webview to null will cause a crash if the
           * application tries to open another webview
           */
          webview = null;
          if (!_authenticated) {
            c.completeError(
              PlatformException(code: 'CANCELED', message: 'User canceled'),
            );
          }
        },
      ),
    );
    webview!.launch(url);
    webview?.close();
    webview = null;
    return c.future;
  }

  @override
  Future<void> clearAllDanglingCalls() async {
    print('webview closed on clearAllDanglingCalls');
    webview?.close();
  }
}
