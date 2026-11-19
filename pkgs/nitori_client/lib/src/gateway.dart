/// WebSocket gateway of the Satori protocol.
///
/// The implementation lives in [SatoriGatewayClient]; the names here are
/// deprecated aliases kept for backward compatibility.
library;

import 'gateway_client.dart';

/// One EVENT frame received from the gateway.
@Deprecated('renamed to SatoriGatewayEvent')
typedef GatewayEvent = SatoriGatewayEvent;

/// Thrown when the gateway gives up reconnecting after too many failed
/// initial attempts.
@Deprecated('renamed to SatoriGatewayException')
typedef GatewayException = SatoriGatewayException;

/// A single `/v1/events` connection lifecycle.
@Deprecated('renamed to SatoriGatewayClient')
typedef Gateway = SatoriGatewayClient;
