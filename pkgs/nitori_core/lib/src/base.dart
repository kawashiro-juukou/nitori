interface class Pagination<T> {
  T data;
  String? next;

  Pagination(this.data, {this.next});
}

enum EventType {
  internal(0);

  final int value;
  const EventType(this.value);
}

interface class Event<T> {
  EventType type;
  T data;

  Event(this.type, this.data);
}
