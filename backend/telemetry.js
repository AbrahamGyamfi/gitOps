const { diag, DiagConsoleLogger, DiagLogLevel } = require('@opentelemetry/api');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || 'taskflow-backend';
const OTEL_ENDPOINT =
  process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT ||
  `${process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318'}/v1/traces`;

if (process.env.OTEL_DIAGNOSTIC_LOG_LEVEL === 'debug') {
  diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);
}

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'production'
  }),
  traceExporter: new OTLPTraceExporter({
    url: OTEL_ENDPOINT
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': {
        enabled: false
      },
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => request.url === '/metrics'
      }
    })
  ]
});

let telemetryStarted = false;

async function startTelemetry() {
  if (telemetryStarted || process.env.OTEL_SDK_DISABLED === 'true') {
    return;
  }

  try {
    await sdk.start();
    telemetryStarted = true;
    process.stdout.write(
      `${JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'info',
        service: SERVICE_NAME,
        message: 'otel_sdk_started',
        otlp_endpoint: OTEL_ENDPOINT
      })}\n`
    );
  } catch (error) {
    process.stdout.write(
      `${JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'error',
        service: SERVICE_NAME,
        message: 'otel_sdk_start_failed',
        error_message: error.message
      })}\n`
    );
  }
}

async function shutdownTelemetry() {
  if (!telemetryStarted) {
    return;
  }

  try {
    await sdk.shutdown();
    process.stdout.write(
      `${JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'info',
        service: SERVICE_NAME,
        message: 'otel_sdk_stopped'
      })}\n`
    );
  } catch (error) {
    process.stdout.write(
      `${JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'error',
        service: SERVICE_NAME,
        message: 'otel_sdk_shutdown_failed',
        error_message: error.message
      })}\n`
    );
  }
}

startTelemetry();

module.exports = {
  shutdownTelemetry
};
