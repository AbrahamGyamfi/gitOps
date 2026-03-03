const { context, trace } = require('@opentelemetry/api');

const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || 'taskflow-backend';

function getTraceFields() {
  const activeSpan = trace.getSpan(context.active());
  if (!activeSpan) {
    return {};
  }

  const spanContext = activeSpan.spanContext();
  if (!spanContext.traceId || !spanContext.spanId) {
    return {};
  }

  return {
    trace_id: spanContext.traceId,
    span_id: spanContext.spanId
  };
}

function writeLog(level, message, fields = {}) {
  const logPayload = {
    timestamp: new Date().toISOString(),
    level,
    service: SERVICE_NAME,
    message,
    ...getTraceFields(),
    ...fields
  };

  process.stdout.write(`${JSON.stringify(logPayload)}\n`);
}

function info(message, fields) {
  writeLog('info', message, fields);
}

function warn(message, fields) {
  writeLog('warn', message, fields);
}

function error(message, fields) {
  writeLog('error', message, fields);
}

module.exports = {
  info,
  warn,
  error
};
