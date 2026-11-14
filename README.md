<h1 align="center"> Nitori </h1>

<p align="center">
A Dart Implementation for <a href="https://github.com/satorijs/satori">Satori Protocol</a>.
</p>

<p align="center">

<img alt="GitHub Workflow Status (with event)" src="https://img.shields.io/github/actions/workflow/status/kawashiro-juukou/nitori/dart.yml?style=for-the-badge">
<img alt="GitHub issues" src="https://img.shields.io/github/issues/kawashiro-juukou/nitori?style=for-the-badge">
<img alt="GitHub License" src="https://img.shields.io/github/license/kawashiro-juukou/nitori?style=for-the-badge">

</p>

<hr>

## Usage

This project is still **Working in progress**, use it at your own risk.

## Packages

> Note: some packages are not published yet.

| Package | Description | Version |
|---|---|---|
| [nitori](pkgs/nitori/) | A Dart Implementation for Satori Protocol | [![pub package](https://img.shields.io/pub/v/nitori.svg)](https://pub.dev/packages/nitori) |
| [nitori_client](pkgs/nitori_client/) | Dart Client Implementation for Satori Protocol. | [![pub package](https://img.shields.io/pub/v/nitori_client.svg)](https://pub.dev/packages/nitori_client) |
| [nitori_core](pkgs/nitori_core/) | Core Module for Nitori. | [![pub package](https://img.shields.io/pub/v/nitori_core.svg)](https://pub.dev/packages/nitori_core) |
| [nitori_message](pkgs/nitori_message/) | Message Builder for Nitori. | [![pub package](https://img.shields.io/pub/v/nitori_message.svg)](https://pub.dev/packages/nitori_message) |
| [nitori_server](pkgs/nitori_server/) | Dart Server Implementation for Satori Protocol. | [![pub package](https://img.shields.io/pub/v/nitori_server.svg)](https://pub.dev/packages/nitori_server) |

## Protocol Bridge

`nitori_server` includes a protocol bridge: a local `SatoriServer` fronted by a
`RemoteSatoriAdapter` that mirrors a remote Satori server (running upstream
Node adapters like `@satorijs/adapter-telegram`) for local Satori clients.
See [pkgs/nitori_server/PROTOCOL_BRIDGE.md](pkgs/nitori_server/PROTOCOL_BRIDGE.md)
and the runnable example in
[pkgs/nitori_server/example/remote_bridge_example.dart](pkgs/nitori_server/example/remote_bridge_example.dart).
