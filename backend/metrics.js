const client = require('prom-client');

const register = new client.Registry();

client.collectDefaultMetrics({
  register,
  prefix: 'taskflow_process_'
});

const httpRequestsTotal = new client.Counter({
  name: 'taskflow_http_requests_total',
  help: 'Total number of HTTP requests handled by the backend',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpErrorsTotal = new client.Counter({
  name: 'taskflow_http_errors_total',
  help: 'Total number of HTTP requests that returned 4xx or 5xx status codes',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'taskflow_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.03, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5],
  registers: [register]
});

const tasksTotal = new client.Gauge({
  name: 'taskflow_tasks_total',
  help: 'Current number of tasks stored in memory',
  registers: [register]
});

function sanitizeMethod(method) {
  if (!method) {
    return 'UNKNOWN';
  }

  return method.toUpperCase();
}

function sanitizeRoute(route) {
  if (!route) {
    return 'unknown';
  }

  return route;
}

function sanitizeStatusCode(statusCode) {
  if (!statusCode) {
    return '0';
  }

  return String(statusCode);
}

function observeHttpRequest({ method, route, statusCode, durationSeconds }) {
  const labels = {
    method: sanitizeMethod(method),
    route: sanitizeRoute(route),
    status_code: sanitizeStatusCode(statusCode)
  };

  httpRequestsTotal.inc(labels);
  httpRequestDurationSeconds.observe(labels, durationSeconds);

  if (statusCode >= 400) {
    httpErrorsTotal.inc(labels);
  }
}

function setTasksTotal(value) {
  tasksTotal.set(value);
}

function getMetrics() {
  return register.metrics();
}

function getMetricsContentType() {
  return register.contentType;
}

function resetMetrics() {
  httpRequestsTotal.reset();
  httpErrorsTotal.reset();
  httpRequestDurationSeconds.reset();
  tasksTotal.reset();
}

module.exports = {
  getMetrics,
  getMetricsContentType,
  observeHttpRequest,
  resetMetrics,
  setTasksTotal
};
