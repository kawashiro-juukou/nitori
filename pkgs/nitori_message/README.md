![](https://img.shields.io/pub/v/nitori_message.svg)
![](https://img.shields.io/pub/publisher/nitori_message.svg)
![](https://img.shields.io/github/license/kawashiro-juukou/nitori.svg)

A message builder for [Nitori](https://pub.dev/packages/nitori), provides several useful functions to construct or parse message elements of [Satori Protocol](https://satori.js.org/).

## Usage

### Construct a message

```dart
import 'package:nitori_message/nitori_message.dart' as n;

var message = n.Message(
  children: [
    n.At(id: '001', name: 'Kawashiro Nitori'),
    n.Text('Hello, world!'),
    n.Image(src: 'https://example.com/image.png'),
    n.LineBreak(),
    n.Bold('Welcome to Nitori: '),
    n.Sharp(id: '001', name: 'Kawashiro Channel'),
  ],
); // n.Message
```

The code above will produce:

```html
<message>
  <at id="001" name="Kawashiro Nitori" />
  Hello, world!
  <img src="https://example.com/image.png" />
  <br />
  <b>Welcome to Nitori: </b>
  <sharp id="001" name="Kawashiro Channel" />
</message>
```

You will notice there are some differences between the class names and the produced tags, this is because the class names are designed to be more readable and easy to use, while the tags are should be the same as those in Satori Protocol.
You could see the [Elements Cheat Sheet](#elements-cheat-sheet) for more details.

### Parse a message

```dart
import 'package:nitori_message/nitori_message.dart' as n;

var message = n.Message.parse(
  '<message>'
  '<at id="001" name="Kawashiro Nitori" />'
  'Hello, world!'
  '<img src="https://example.com/image.png" />'
  '<br />'
  '<b>Welcome to Nitori: </b>'
  '<sharp id="001" name="Kawashiro Channel" />'
  '</message>',
); // n.Message
```

The code above will produce a structure like this:

```dart
n.Message(
  children: [
    n.At(id: '001', name: 'Kawashiro Nitori'),
    n.Text('Hello, world!'),
    n.Image(src: 'https://example.com/image.png'),
    n.LineBreak(),
    n.Bold('Welcome to Nitori: '),
    n.Sharp(id: '001', name: 'Kawashiro Channel'),
  ],
); // n.Message
```

Since Nitori overrides the `toString()` method of each element, you could use `print(message)` to see the result.

```dart
print(message);

// =>
// <message>
//   <at id="001" name="Kawashiro Nitori" />
//   Hello, world!
//   <img src="https://example.com/image.png" />
//   <br />
//   <b>Welcome to Nitori: </b>
//   <sharp id="001" name="Kawashiro Channel" />
// </message>
```

## Elements Cheat Sheet

| Class Name | Satori Element Name | Note |
|:---:|:---:|:---:|
| `Text` | [plain text](https://satori.js.org/zh-CN/protocol/elements.html#%E7%BA%AF%E6%96%87%E6%9C%AC) | Represent a text node. |
| `At` | [`<at>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%8F%90%E5%8F%8A%E7%94%A8%E6%88%B7) | |
| `Sharp` | [`<sharp>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%8F%90%E5%8F%8A%E9%A2%91%E9%81%93) | |
| `Anchor` | [`<a>`](https://satori.js.org/zh-CN/protocol/elements.html#%E9%93%BE%E6%8E%A5) | |
| `Image` | [`<img>`](https://satori.js.org/zh-CN/protocol/elements.html#%E5%9B%BE%E7%89%87) | |
| `Audio` | [`<audio>`](https://satori.js.org/zh-CN/protocol/elements.html#%E8%AF%AD%E9%9F%B3) | |
| `Video` | [`<video>`](https://satori.js.org/zh-CN/protocol/elements.html#%E8%A7%86%E9%A2%91) | |
| `File` | [`<file>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%87%E4%BB%B6) | |
| `Bold` | [`<b>`](https://satori.js.org/zh-CN/protocol/elements.html#%E7%B2%97%E4%BD%93) | |
| `Idiomatic` | [`<i>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%96%9C%E4%BD%93) | |
| `Underline` | [`<u>`](https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E5%88%92%E7%BA%BF) | |
| `Strikethrough` | [`<s>`](https://satori.js.org/zh-CN/protocol/elements.html#%E5%88%A0%E9%99%A4%E7%BA%BF) | |
| `Spoler` | [`<spl>`](https://satori.js.org/zh-CN/protocol/elements.html#%E5%89%A7%E9%80%8F) | |
| `Code` | [`<code>`](https://satori.js.org/zh-CN/protocol/elements.html#%E4%BB%A3%E7%A0%81) | |
| `Superscript` | [`<sup>`](https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8A%E6%A0%87) | |
| `Subscript` | [`<sub>`](https://satori.js.org/zh-CN/protocol/elements.html#%E4%B8%8B%E6%A0%87) | |
| `LineBreak` | [`<br>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%8D%A2%E8%A1%8C) | |
| `Paragraph` | [`<p>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%AE%B5%E8%90%BD) | |
| `Message` | [`<message>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%B6%88%E6%81%AF) | |
| `Quote` | [`<quote>`](https://satori.js.org/zh-CN/protocol/elements.html#%E5%BC%95%E7%94%A8) | |
| `Author` | [`<author>`](https://satori.js.org/zh-CN/protocol/elements.html#%E4%BD%9C%E8%80%85) | |
| `Button` | [`<button>`](https://satori.js.org/zh-CN/protocol/elements.html#%E6%8C%89%E9%92%AE-%E5%AE%9E%E9%AA%8C%E6%80%A7) | **Not implemented yet** |
