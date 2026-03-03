const request = require('supertest');
const { app, resetInMemoryData } = require('./app');

describe('TaskFlow API Tests', () => {
  beforeEach(() => {
    resetInMemoryData();
  });

  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const res = await request(app).get('/health');

      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body.tasksCount).toBe(0);
    });
  });

  describe('GET /api/system/overview', () => {
    it('should include internal health payload', async () => {
      const res = await request(app).get('/api/system/overview');

      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('service');
      expect(res.body).toHaveProperty('upstreamHealth');
      expect(res.body.upstreamHealth.status).toBe('healthy');
    });
  });

  describe('POST /api/tasks', () => {
    it('should create a new task', async () => {
      const taskData = {
        title: 'Test Task',
        description: 'Test Description'
      };

      const res = await request(app).post('/api/tasks').send(taskData);

      expect(res.statusCode).toBe(201);
      expect(res.body).toHaveProperty('id');
      expect(res.body.title).toBe(taskData.title);
      expect(res.body.completed).toBe(false);
    });

    it('should reject empty title', async () => {
      const res = await request(app).post('/api/tasks').send({ title: '   ' });

      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBe('Title is required');
    });
  });

  describe('GET /api/tasks', () => {
    it('should return empty array initially', async () => {
      const res = await request(app).get('/api/tasks');

      expect(res.statusCode).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('should return tasks in newest-first order', async () => {
      await request(app).post('/api/tasks').send({ title: 'Older Task' });
      await new Promise((resolve) => setTimeout(resolve, 10));
      await request(app).post('/api/tasks').send({ title: 'Newer Task' });

      const res = await request(app).get('/api/tasks');
      expect(res.statusCode).toBe(200);
      expect(res.body.length).toBe(2);
      expect(res.body[0].title).toBe('Newer Task');
      expect(res.body[1].title).toBe('Older Task');
    });

    it('should support response delay injection for latency testing', async () => {
      const start = Date.now();
      const res = await request(app).get('/api/tasks?delay_ms=120');
      const elapsed = Date.now() - start;

      expect(res.statusCode).toBe(200);
      expect(elapsed).toBeGreaterThanOrEqual(100);
    });
  });

  describe('PATCH /api/tasks/:id', () => {
    it('should update task completion status', async () => {
      const createRes = await request(app).post('/api/tasks').send({ title: 'Task to Update' });
      const taskId = createRes.body.id;

      const patchRes = await request(app).patch(`/api/tasks/${taskId}`).send({ completed: true });

      expect(patchRes.statusCode).toBe(200);
      expect(patchRes.body.completed).toBe(true);
    });

    it('should return 400 for invalid completion value', async () => {
      const createRes = await request(app).post('/api/tasks').send({ title: 'Task to Update' });
      const taskId = createRes.body.id;

      const patchRes = await request(app).patch(`/api/tasks/${taskId}`).send({ completed: 'yes' });
      expect(patchRes.statusCode).toBe(400);
    });
  });

  describe('PUT /api/tasks/:id', () => {
    it('should update a task title and description', async () => {
      const createRes = await request(app).post('/api/tasks').send({ title: 'Initial title' });
      const taskId = createRes.body.id;

      const updateRes = await request(app).put(`/api/tasks/${taskId}`).send({
        title: 'Updated title',
        description: 'Updated description'
      });

      expect(updateRes.statusCode).toBe(200);
      expect(updateRes.body.title).toBe('Updated title');
      expect(updateRes.body.description).toBe('Updated description');
    });
  });

  describe('DELETE /api/tasks/:id', () => {
    it('should delete a task', async () => {
      const createRes = await request(app).post('/api/tasks').send({ title: 'Task to Delete' });
      const taskId = createRes.body.id;

      const deleteRes = await request(app).delete(`/api/tasks/${taskId}`);
      expect(deleteRes.statusCode).toBe(200);

      const listRes = await request(app).get('/api/tasks');
      expect(listRes.body.length).toBe(0);
    });

    it('should return 404 for non-existent task', async () => {
      const res = await request(app).delete('/api/tasks/invalid-id');
      expect(res.statusCode).toBe(404);
    });
  });

  describe('GET /metrics', () => {
    it('should expose Prometheus RED metrics', async () => {
      await request(app).get('/health');
      const metricsRes = await request(app).get('/metrics');

      expect(metricsRes.statusCode).toBe(200);
      expect(metricsRes.text).toContain('taskflow_http_requests_total');
      expect(metricsRes.text).toContain('taskflow_http_errors_total');
      expect(metricsRes.text).toContain('taskflow_http_request_duration_seconds');
      expect(metricsRes.text).toContain('taskflow_tasks_total');
    });
  });

  describe('Error Handling', () => {
    it('should return 404 for unknown routes', async () => {
      const res = await request(app).get('/api/unknown');
      expect(res.statusCode).toBe(404);
    });

    it('should return 404 for updating non-existent task', async () => {
      const res = await request(app)
        .put('/api/tasks/non-existent-id')
        .send({ title: 'Updated' });
      expect(res.statusCode).toBe(404);
    });

    it('should return 404 for patching non-existent task', async () => {
      const res = await request(app)
        .patch('/api/tasks/non-existent-id')
        .send({ completed: true });
      expect(res.statusCode).toBe(404);
    });
  });

  describe('CORS', () => {
    it('should have CORS headers', async () => {
      const res = await request(app).get('/health');
      expect(res.headers['access-control-allow-origin']).toBeDefined();
    });
  });

  describe('Task Validation', () => {
    it('should reject task with missing title', async () => {
      const res = await request(app).post('/api/tasks').send({});
      expect(res.statusCode).toBe(400);
    });

    it('should trim whitespace from title', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: '  Test Task  ' });
      expect(res.statusCode).toBe(201);
      expect(res.body.title).toBe('Test Task');
    });

    it('should handle empty description', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: 'Task', description: '' });
      expect(res.statusCode).toBe(201);
      expect(res.body.description).toBe('');
    });
  });

  describe('Task Filtering', () => {
    beforeEach(async () => {
      await request(app).post('/api/tasks').send({ title: 'Task 1' });
      await request(app).post('/api/tasks').send({ title: 'Task 2' });
      const task3 = await request(app).post('/api/tasks').send({ title: 'Task 3' });
      await request(app).patch(`/api/tasks/${task3.body.id}`).send({ completed: true });
    });

    it('should return all tasks', async () => {
      const res = await request(app).get('/api/tasks');
      expect(res.statusCode).toBe(200);
      expect(res.body.length).toBe(3);
    });

    it('should count tasks correctly in health endpoint', async () => {
      const res = await request(app).get('/health');
      expect(res.body.tasksCount).toBe(3);
    });
  });

  describe('Performance Testing', () => {
    it('should handle delay_ms parameter', async () => {
      const start = Date.now();
      const res = await request(app).get('/api/tasks?delay_ms=100');
      const elapsed = Date.now() - start;
      
      expect(res.statusCode).toBe(200);
      expect(elapsed).toBeGreaterThanOrEqual(90);
    });
  });
});
