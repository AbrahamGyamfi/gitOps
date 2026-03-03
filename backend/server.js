const logger = require('./logger');
const { shutdownTelemetry } = require('./telemetry');
const { app } = require('./app');

const PORT = Number(process.env.PORT || 5000);
let server;
let shuttingDown = false;

function startServer() {
  server = app.listen(PORT, () => {
    logger.info('server_started', {
      port: PORT,
      health_endpoint: `http://localhost:${PORT}/health`,
      metrics_endpoint: `http://localhost:${PORT}/metrics`
    });
  });

  return server;
}

function closeServer() {
  return new Promise((resolve, reject) => {
    if (!server) {
      resolve();
      return;
    }

    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }

      resolve();
    });
  });
}

async function shutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;

  logger.info('shutdown_started', { signal });

  try {
    await closeServer();
    await shutdownTelemetry();
    logger.info('shutdown_completed', { signal });
    process.exit(0);
  } catch (error) {
    logger.error('shutdown_failed', {
      signal,
      error_message: error.message,
      error_stack: error.stack
    });
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});

process.on('SIGINT', () => {
  shutdown('SIGINT');
});

module.exports = { startServer };
