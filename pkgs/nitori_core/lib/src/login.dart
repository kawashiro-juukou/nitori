import './user.dart';

enum Status {
  OFFLINE(0),
  ONLINE(1),
  CONNECT(2),
  DISCONNECT(3),
  RECONNECT(4);

  const Status(this.value);
  final int value;
}

class Login {
  Status status;
  User? user;
  String? selfId;
  String? platform;

  Login(this.status, {this.user, this.selfId, this.platform});

  factory Login.fromJson(Map<String, dynamic> json) {
    return Login(
      Status.values[json['status']],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      selfId: json['self_id'],
      platform: json['platform'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.value,
      'user': user?.toJson(),
      'self_id': selfId,
      'platform': platform,
    };
  }
}

abstract class LoginInterface {
  Future<Login> getLogin();
}