const cors = require('cors');
const express = require('express');
const http = require('http');
const { context, trace } = require('@opentelemetry/api');
const { v4: uuidv4 } = require('uuid');

const logger = require('./logger');
const {
  getMetrics,
  getMetricsContentType,
  observeHttpRequest,
  resetMetrics,
  setTasksTotal
} = require('./metrics');

const app = express();

const MAX_TITLE_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 500;
const MAX_DELAY_MS = 5000;
const UUID_PATTERN =
  /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi;

let tasks = [];
setTasksTotal(0);

function getHealthSnapshot() {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    tasksCount: tasks.length
  };
}

function normalizePath(path) {
  if (!path) {
    return 'unknown';
  }

  return path
    .replace(UUID_PATTERN, ':id')
    .replace(/\/\d+(?=\/|$)/g, '/:id');
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function parseDelayMs(queryValue) {
  if (queryValue === undefined) {
    return 0;
  }

  const parsedDelay = Number(queryValue);
  if (!Number.isFinite(parsedDelay) || parsedDelay <= 0) {
    return 0;
  }

  return Math.min(parsedDelay, MAX_DELAY_MS);
}

function extractErrorFields(error) {
  if (!(error instanceof Error)) {
    return { error };
  }

  return {
    error_name: error.name,
    error_message: error.message,
    error_stack: error.stack
  };
}

function resetInMemoryData() {
  tasks = [];
  resetMetrics();
  setTasksTotal(0);
}

function validateTaskPayload(title, description) {
  if (typeof title !== 'string' || title.trim().length === 0) {
    return 'Title is required';
  }

  if (title.trim().length > MAX_TITLE_LENGTH) {
    return `Title must be ${MAX_TITLE_LENGTH} characters or less`;
  }

  if (typeof description === 'string' && description.length > MAX_DESCRIPTION_LENGTH) {
    return `Description must be ${MAX_DESCRIPTION_LENGTH} characters or less`;
  }

  return null;
}

function fetchInternalHealth() {
  if (process.env.NODE_ENV === 'test') {
    return Promise.resolve(getHealthSnapshot());
  }

  const timeoutMs = Number(process.env.INTERNAL_HEALTH_TIMEOUT_MS || 2000);
  const port = Number(process.env.PORT || 5000);

  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: '/health',
        method: 'GET',
        timeout: timeoutMs,
        headers: {
          'x-observability-probe': 'internal'
        }
      },
      (response) => {
        let body = '';

        response.on('data', (chunk) => {
          body += chunk;
        });

        response.on('end', () => {
          if (response.statusCode && response.statusCode >= 400) {
            reject(new Error(`Upstream health check failed with status ${response.statusCode}`));
            return;
          }

          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(new Error('Failed to parse upstream health response'));
          }
        });
      }
    );

    request.on('timeout', () => {
      request.destroy(new Error('Upstream health check timed out'));
    });

    request.on('error', (error) => {
      reject(error);
    });

    request.end();
  });
}

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  const startTime = process.hrtime.bigint();
  const spanContext = trace.getSpan(context.active())?.spanContext();
  const traceContext = spanContext
    ? {
        trace_id: spanContext.traceId,
        span_id: spanContext.spanId
      }
    : {};

  res.on('finish', () => {
    const elapsed = process.hrtime.bigint() - startTime;
    const durationSeconds = Number(elapsed) / 1e9;
    const route = normalizePath(req.path);
    const statusCode = res.statusCode;

    observeHttpRequest({
      method: req.method,
      route,
      statusCode,
      durationSeconds
    });

    const baseLogFields = {
      method: req.method,
      route,
      status_code: statusCode,
      duration_ms: Number((durationSeconds * 1000).toFixed(2)),
      remote_ip: req.ip,
      user_agent: req.get('user-agent') || 'unknown',
      ...traceContext
    };

    if (statusCode >= 500) {
      logger.error('http_request_completed', baseLogFields);
      return;
    }

    if (statusCode >= 400) {
      logger.warn('http_request_completed', baseLogFields);
      return;
    }

    logger.info('http_request_completed', baseLogFields);
  });

  next();
});

app.get('/metrics', async (req, res) => {
  try {
    const metricsPayload = await getMetrics();
    res.set('Content-Type', getMetricsContentType());
    res.status(200).send(metricsPayload);
  } catch (error) {
    logger.error('metrics_collection_failed', {
      ...extractErrorFields(error)
    });
    res.status(500).json({ error: 'Unable to collect metrics' });
  }
});

app.get('/health', (req, res) => {
  res.status(200).json(getHealthSnapshot());
});

app.get('/api/system/overview', async (req, res) => {
  try {
    const upstreamHealth = await fetchInternalHealth();

    res.status(200).json({
      service: process.env.OTEL_SERVICE_NAME || 'taskflow-backend',
      timestamp: new Date().toISOString(),
      tasksCount: tasks.length,
      upstreamHealth
    });
  } catch (error) {
    logger.error('system_overview_failed', {
      ...extractErrorFields(error)
    });
    res.status(502).json({ error: 'Unable to retrieve internal health state' });
  }
});

app.post('/api/tasks', (req, res) => {
  try {
    const { title, description } = req.body;
    const validationError = validateTaskPayload(title, description);
    if (validationError) {
      return res.status(400).json({ error: validationError });
    }

    const now = new Date().toISOString();
    const newTask = {
      id: uuidv4(),
      title: title.trim(),
      description: typeof description === 'string' ? description.trim() : '',
      completed: false,
      createdAt: now,
      updatedAt: now
    };

    tasks.push(newTask);
    setTasksTotal(tasks.length);
    return res.status(201).json(newTask);
  } catch (error) {
    logger.error('task_create_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/tasks', async (req, res) => {
  try {
    const delayMs = parseDelayMs(req.query.delay_ms);
    if (delayMs > 0) {
      await delay(delayMs);
    }

    const sortedTasks = [...tasks].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.status(200).json(sortedTasks);
  } catch (error) {
    logger.error('task_list_failed', {
      ...extractErrorFields(error)
    });
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.patch('/api/tasks/:id', (req, res) => {
  try {
    const { id } = req.params;
    const { completed } = req.body;
    const taskIndex = tasks.findIndex((task) => task.id === id);

    if (taskIndex === -1) {
      return res.status(404).json({ error: 'Task not found' });
    }

    if (typeof completed !== 'boolean') {
      return res.status(400).json({ error: 'Completed status must be a boolean' });
    }

    tasks[taskIndex] = {
      ...tasks[taskIndex],
      completed,
      updatedAt: new Date().toISOString()
    };

    return res.status(200).json(tasks[taskIndex]);
  } catch (error) {
    logger.error('task_update_status_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/tasks/:id', (req, res) => {
  try {
    const { id } = req.params;
    const { title, description } = req.body;
    const taskIndex = tasks.findIndex((task) => task.id === id);

    if (taskIndex === -1) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const validationError = validateTaskPayload(title, description);
    if (validationError) {
      return res.status(400).json({ error: validationError });
    }

    tasks[taskIndex] = {
      ...tasks[taskIndex],
      title: title.trim(),
      description: typeof description === 'string' ? description.trim() : '',
      updatedAt: new Date().toISOString()
    };

    return res.status(200).json(tasks[taskIndex]);
  } catch (error) {
    logger.error('task_update_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/api/tasks/:id', (req, res) => {
  try {
    const { id } = req.params;
    const taskIndex = tasks.findIndex((task) => task.id === id);

    if (taskIndex === -1) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const [deletedTask] = tasks.splice(taskIndex, 1);
    setTasksTotal(tasks.length);
    return res.status(200).json({ message: 'Task deleted successfully', task: deletedTask });
  } catch (error) {
    logger.error('task_delete_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Test route for error simulation (observability validation)
app.get('/api/test/error', (req, res) => {
  const errorRate = parseFloat(req.query.rate) || 0.5;
  
  if (Math.random() < errorRate) {
    logger.error('simulated_error', {
      error_rate: errorRate,
      random_value: Math.random()
    });
    return res.status(500).json({ error: 'Simulated error for observability testing' });
  }
  
  res.status(200).json({ message: 'Success', error_rate: errorRate });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.use((err, req, res, _next) => {
  logger.error('unhandled_error', {
    route: req.path,
    method: req.method,
    ...extractErrorFields(err)
  });
  res.status(500).json({ error: 'Something went wrong!' });
});

module.exports = {
  app,
  resetInMemoryData
};
