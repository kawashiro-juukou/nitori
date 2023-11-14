import 'dart:convert';
import 'dart:io';

import 'package:nitori_core/nitori_core.dart';

import './base.dart';

final class ChannelController extends BaseController<ChannelInterface> {
  @override
  var prefix = '/channel';
  ChannelController(ChannelInterface interface) : super(interface);

  @override
  Future<void> handlePost(HttpRequest request) async {
    final body = await request
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(json.decoder)
        .single as Map<String, dynamic>;

    final channel = Channel.fromJson(body);

    request.response
      ..statusCode = HttpStatus.ok
      ..write(json.encode(channel.toJson()));
  }
}
