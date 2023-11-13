interface class Pagination<T> {
  T data;
  String? next;

  Pagination(this.data, {this.next});
}
