import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef ErrorCallback = void Function(Object error, StackTrace stackTrace);

class FlutterErrorLogger {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://api.fel.grod.ovh",
      validateStatus: (status) => true,
    ),
  );

  static final int _timeoutDelay = 10;

  static String _errorMessage = "";
  static String? _appIdentifier;
  static String? _apiKey;
  static ErrorCallback? _onError;

  static int? _appId;

  static String? get appIdentifier => _appIdentifier;
  static String? get apiKey => _apiKey;
  static String get errorMessage => _errorMessage;

  /// Fetches the platform/device information for logging purposes
  ///
  /// Returns a [List] containing [String]
  static Future<List<String>> _getPlatformDetails() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return ["Web", webInfo.appVersion ?? ""];
    } else {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return ["Android", androidInfo.version.release];
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return ["IOS", "${iosInfo.model} ${iosInfo.systemVersion}"];
      } else if (Platform.isMacOS) {
        final macOs = await deviceInfo.macOsInfo;
        return ["MacOS", "${macOs.model} ${macOs.majorVersion}"];
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return ["Linux", "${linuxInfo.name} ${linuxInfo.versionId}"];
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return ["Windows", windowsInfo.productName];
      }

      return [];
    }
  }

  /// Calculates the severity for the log based on the error runtimeType
  ///
  /// Returns a [String]
  ///
  /// [error] The given error object to calculate
  static String _calculateSeverity(Object error) {
    List<Type> infoList = [DeferredLoadException, TickerCanceled];
    List<Type> warningList = [
      FormatException,
      UnsupportedError,
      PathExistsException,
      PathNotFoundException,
      PathAccessException,
      TimeoutException,
    ];
    List<Type> errorList = [
      IOException,
      PictureRasterizationException,
      PlatformException,
      NetworkImageLoadException,
    ];
    List<Type> criticalList = [
      IsolateSpawnException,
      MissingPluginException,
      OSError,
    ];

    if (criticalList.contains(error.runtimeType)) {
      return "critical";
    }

    if (errorList.contains(error.runtimeType)) {
      return "error";
    }

    if (warningList.contains(error.runtimeType)) {
      return "warning";
    }

    if (infoList.contains(error.runtimeType)) {
      return "info";
    }

    return "error";
  }

  /// Handles the logging to the API
  ///
  /// Returns [void]
  ///
  /// [error] The given error object;
  /// ;[stackTrace] The given stackTrace for logging
  static Future _handleError(Object error, StackTrace stackTrace) async {
    try {
      String severity = _calculateSeverity(error);

      List<String> details = await _getPlatformDetails();

      await _dio
          .post(
            "https://api.fel.grod.ovh/errors",
            options: Options(
              headers: {"api_key": _apiKey},
              contentType: "application/json",
              responseType: ResponseType.plain,
            ),
            data: {
              "appId": _appId ?? 0,
              "severity": severity,
              "errorMessage": error.toString(),
              "stackTrace": stackTrace.toString(),
              "platform": details[0],
              "platformVersion": details[1],
              "errorDatetime": DateTime.now().toUtc().toIso8601String(),
            },
          )
          .timeout(Duration(seconds: _timeoutDelay));
    } on TimeoutException catch (e, stackTrace) {
      _errorMessage = "API Timedout";
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  /// Initializes the logging for the flutter app
  ///
  /// Returns [void]
  ///
  /// [appIdentifier] The given app identifier fetched from the web platform;
  /// [apiKey] The given user api key fetched from the web platform;
  static Future setup({
    required String appIdentifier,
    required String apiKey,
  }) async {
    try {
      _appIdentifier = appIdentifier;
      _apiKey = apiKey;

      Response response = await _dio
          .post(
            "https://api.fel.grod.ovh/app/validate",
            options: Options(headers: {"api_key": _apiKey}),
            data: {"appIdentifier": _appIdentifier},
          )
          .timeout(Duration(seconds: _timeoutDelay));

      if (response.statusCode != 200) {
        debugPrint(response.data);
        _errorMessage = "Either App Identifier or Api Key is invalid!";
        return;
      }

      int? appId = response.data['data'];
      _appId = appId;
    } on TimeoutException catch (e, stackTrace) {
      _errorMessage = "API Timedout";
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  static void initialize({
    required Widget Function() appBuilder,
    ErrorCallback? appOnError,
  }) {
    _onError = _handleError;

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      appOnError?.call(details.exception, details.stack ?? StackTrace.empty);
      _onError?.call(details.exception, details.stack ?? StackTrace.empty);
    };

    runApp(appBuilder());
  }
}
