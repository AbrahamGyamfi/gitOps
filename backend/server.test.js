const request = require('supertest');
const express = require('express');
const cors = require('cors');

// Create test app
const app = express();
app.use(cors());
app.use(express.json());

let tasks = [];

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        tasksCount: tasks.length
    });
});

// GET all tasks
app.get('/api/tasks', (req, res) => {
    res.json(tasks);
});

// POST new task
app.post('/api/tasks', (req, res) => {
    const { title, description, priority, dueDate } = req.body;
    const newTask = {
        id: Date.now().toString(),
        title,
        description: description || '',
        priority: priority || 'medium',
        dueDate: dueDate || null,
        completed: false,
        createdAt: new Date().toISOString()
    };
    tasks.push(newTask);
    res.status(201).json(newTask);
});

// PATCH task
app.patch('/api/tasks/:id', (req, res) => {
    const { id } = req.params;
    const taskIndex = tasks.findIndex(t => t.id === id);
    if (taskIndex === -1) {
        return res.status(404).json({ error: 'Task not found' });
    }
    tasks[taskIndex] = { ...tasks[taskIndex], ...req.body };
    res.json(tasks[taskIndex]);
});

// DELETE task
app.delete('/api/tasks/:id', (req, res) => {
    const { id } = req.params;
    const taskIndex = tasks.findIndex(t => t.id === id);
    if (taskIndex === -1) {
        return res.status(404).json({ error: 'Task not found' });
    }
    tasks.splice(taskIndex, 1);
    res.status(204).send();
});

describe('TaskFlow API Tests', () => {
    beforeEach(() => {
        tasks = [];
    });

    describe('GET /health', () => {
        it('should return healthy status', async () => {
            const res = await request(app).get('/health');
            expect(res.statusCode).toBe(200);
            expect(res.body.status).toBe('healthy');
            expect(res.body).toHaveProperty('timestamp');
        });
    });

    describe('GET /api/tasks', () => {
        it('should return empty array initially', async () => {
            const res = await request(app).get('/api/tasks');
            expect(res.statusCode).toBe(200);
            expect(res.body).toEqual([]);
        });
    });

    describe('POST /api/tasks', () => {
        it('should create a new task', async () => {
            const taskData = {
                title: 'Test Task',
                description: 'Test Description',
                priority: 'high'
            };
            const res = await request(app)
                .post('/api/tasks')
                .send(taskData);
            
            expect(res.statusCode).toBe(201);
            expect(res.body).toHaveProperty('id');
            expect(res.body.title).toBe(taskData.title);
            expect(res.body.completed).toBe(false);
        });

        it('should create task with minimal data', async () => {
            const res = await request(app)
                .post('/api/tasks')
                .send({ title: 'Minimal Task' });
            
            expect(res.statusCode).toBe(201);
            expect(res.body.title).toBe('Minimal Task');
            expect(res.body.priority).toBe('medium');
        });
    });

    describe('PATCH /api/tasks/:id', () => {
        it('should update a task', async () => {
            const createRes = await request(app)
                .post('/api/tasks')
                .send({ title: 'Task to Update' });
            
            const taskId = createRes.body.id;
            const updateRes = await request(app)
                .patch(`/api/tasks/${taskId}`)
                .send({ completed: true });
            
            expect(updateRes.statusCode).toBe(200);
            expect(updateRes.body.completed).toBe(true);
        });

        it('should return 404 for non-existent task', async () => {
            const res = await request(app)
                .patch('/api/tasks/invalid-id')
                .send({ completed: true });
            
            expect(res.statusCode).toBe(404);
        });
    });

    describe('DELETE /api/tasks/:id', () => {
        it('should delete a task', async () => {
            const createRes = await request(app)
                .post('/api/tasks')
                .send({ title: 'Task to Delete' });
            
            const taskId = createRes.body.id;
            const deleteRes = await request(app).delete(`/api/tasks/${taskId}`);
            
            expect(deleteRes.statusCode).toBe(204);
            
            const getRes = await request(app).get('/api/tasks');
            expect(getRes.body.length).toBe(0);
        });

        it('should return 404 for non-existent task', async () => {
            const res = await request(app).delete('/api/tasks/invalid-id');
            expect(res.statusCode).toBe(404);
        });
    });
});
