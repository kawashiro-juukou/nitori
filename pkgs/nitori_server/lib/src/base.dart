import 'dart:io';

base class BaseController<T> {
  // ignore: unused_field
  final T _interface;

  BaseController(this._interface);

  get prefix => throw UnimplementedError();

  Future<void> handleRequest(HttpRequest request) async {
    try {
      switch (request.method) {
        case 'POST':
          await handlePost(request);
          break;
        default:
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..write('Method not allowed');
      }
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Internal Server Error');
    } finally {
      await request.response.close();
    }
  }

  Future<void> handlePost(HttpRequest request) async {
    throw UnimplementedError();
  }
}
