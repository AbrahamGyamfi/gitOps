# TaskFlow - Task Management Web Application

[![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-red)](https://jenkins.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-blue)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/Deploy-AWS%20EC2-orange)](https://aws.amazon.com/ec2/)

A lightweight, intuitive task management web application built following Agile principles and DevOps practices.

## Project Overview

TaskFlow is a full-stack task management application developed as part of an Agile Development project. The application demonstrates:

- **Agile Methodology**: Iterative development across multiple sprints
- **DevOps Practices**: Complete Jenkins CI/CD pipeline with Docker & EC2 deployment
- **Modern Web Stack**: React frontend with Node.js/Express backend
- **Test-Driven Development**: High code coverage with automated tests
- **Containerization**: Docker multi-stage builds for production deployment

## Features

### Sprint 1 Features (Completed)
- **US-001**: Create tasks with title and description
- **US-002**: View all tasks in a organized list
- **US-003**: Mark tasks as complete/incomplete

### Sprint 2 Features (Completed)
- **US-004**: Delete tasks with confirmation
- **US-005**: Edit existing task details
- **US-006**: Filter tasks by status (All/Active/Completed)

## Technology Stack

### Frontend
- React 18
- CSS3 (with CSS Modules)
- Fetch API for HTTP requests

### Backend
- Node.js
- Express.js
- UUID for unique identifiers
- CORS for cross-origin requests

### DevOps & Testing
- Jest for unit and integration testing
- Supertest for API testing
- **Jenkins** for complete CI/CD pipeline
- **Docker** for containerization
- **AWS EC2** for production deployment
- ESLint for code quality

## Installation & Setup

### Prerequisites
- Node.js 18+ and npm
- Git
- Docker (for containerized deployment)
- Jenkins (for CI/CD pipeline)

## Installation & Setup

### Prerequisites
- Node.js 18+ and npm
- Git
- Docker (for containerized deployment)
- Jenkins (for CI/CD pipeline)

### Project Structure & Running Apps

This repository uses a monorepo layout with both backend and frontend apps in their own folders.
There is **no package.json at the project root**.
**All npm commands should be run in the appropriate subdirectory.**

```
Jenkins-project/
├── backend/    # Node.js/Express server
└── frontend/   # React app
```

### Installation Steps

1. **Clone the repository**
    ```bash
    git clone https://github.com/AbrahamGyamfi/Jenkins-project.git
    cd Jenkins-project
    ```

2. **Install backend dependencies**
    ```bash
    cd backend
    npm install
    ```

3. **Install frontend dependencies**
    ```bash
    cd ../frontend
    npm install
    ```

### Running the Backend Server
(from the project root)
```bash
cd backend
npm start
# Server runs on http://localhost:5000
```

### Running the Frontend App
(from the project root)
```bash
cd frontend
npm start
# Frontend runs on http://localhost:3000
```

### Running Tests

- **Backend tests**
    ```bash
    cd backend
    npm test
    ```
    To run with coverage:
    ```bash
    npm test -- --coverage
    ```

- **Frontend tests**
    ```bash
    cd frontend
    npm test
    ```
    To run with coverage:
    ```bash
    npm test -- --coverage
    ```

### Access the Application

Open your browser and navigate to [http://localhost:3000](http://localhost:3000)

## Testing

### Run all tests
```bash
npm test
```

### Run tests with coverage
```bash
npm test -- --coverage
```

### Test Coverage Goals
- Minimum 80% code coverage across all metrics
- All tests must pass before merging to main branch

## CI/CD Pipeline (Jenkins)

The project implements a complete end-to-end Jenkins CI/CD pipeline that builds, tests, containerizes, and deploys the application to AWS EC2.

### Live Infrastructure
- **Production App**: http://34.245.23.234/ (EC2 t3.micro)
- **AWS Region**: eu-west-1 (Ireland)
- **Registry**: AWS ECR (697863031884.dkr.ecr.eu-west-1.amazonaws.com)

### Pipeline Stages
1. **Checkout**: Clone repository from GitHub
2. **Build Docker Images**: Build backend and frontend containers in parallel
3. **Run Unit Tests**: Execute backend (Jest+Supertest) and frontend (React Testing Library) tests in Docker containers
4. **Code Quality**: Run ESLint and verify Docker images
5. **Integration Tests**: Test live API endpoints with containerized backend
6. **Push to ECR**: Upload images to AWS ECR with build number tags
7. **Deploy to EC2**: SSH deployment to production server with docker-compose
8. **Health Check**: Verify application is running and responsive
9. **Cleanup**: Remove old Docker images and containers

### Key Features
- Containerized test execution (tests run inside Docker, not on Jenkins host)
- Parallel build and test stages for faster execution (~2-3 minutes)
- Health checks before and after deployment
- AWS ECR integration for secure image storage
- Separate backend and frontend Docker images
- Image versioning with build numbers and latest tags
- Automated cleanup to prevent disk space issues

### Test Execution
All tests run inside Docker containers to ensure consistency:

**Backend Tests** (16 tests):
```bash
docker run --rm -v $(pwd):/app -w /app node:18-alpine sh -c 'npm install && npm test'
```
- Health check endpoint
- GET/POST/PATCH/PUT/DELETE /api/tasks
- Validation tests (required fields, length limits)
- Error handling (404, 400 responses)

**Frontend Tests** (8 tests):
```bash
docker run --rm -v $(pwd):/app -w /app node:18-alpine sh -c 'npm install --legacy-peer-deps && CI=true npm test'
```
- Component rendering
- Form submission and user interactions
- Task filtering (All/Active/Completed)
- API integration and error handling

## Docker Deployment

### Separate Backend and Frontend Images

**Backend Image** (Node.js + Express):
```bash
cd backend
docker build -t taskflow-backend .
# Image size: 202MB (node:18-alpine base)
```

**Frontend Image** (React + Nginx):
```bash
cd frontend
docker build -t taskflow-frontend .
# Image size: 93.3MB (multi-stage: node build → nginx serve)
```

### Run Containers Locally
```bash
# Backend
docker run -d -p 5000:5000 --name taskflow-backend taskflow-backend

# Frontend
docker run -d -p 80:80 --name taskflow-frontend taskflow-frontend
```

### Using Docker Compose
```bash
# Development
docker-compose up -d

# Production (on EC2)
docker-compose -f docker-compose.prod.yml up -d
```

### Production Deployment (EC2)
Images are pulled from AWS ECR:
```bash
# Login to ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 697863031884.dkr.ecr.eu-west-1.amazonaws.com

# Pull latest images
docker pull 697863031884.dkr.ecr.eu-west-1.amazonaws.com/taskflow-backend:latest
docker pull 697863031884.dkr.ecr.eu-west-1.amazonaws.com/taskflow-frontend:latest

# Deploy with docker-compose
docker-compose -f docker-compose.prod.yml up -d
```

### Health Checks
```bash
# Local
curl http://localhost:5000/health
curl http://localhost/health

# Production
curl http://54.170.165.207/health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-02-16T10:30:00.000Z",
  "tasksCount": 0
}
```

## Project Structure

```
Agile_development/
├── backend/
│   ├── server.js              # Express server and API routes
│   ├── server.test.js         # Backend unit tests (16 tests: CRUD + validation)
│   ├── Dockerfile             # Backend container (node:18-alpine)
│   └── package.json           # Backend dependencies
├── frontend/
│   ├── public/
│   │   └── index.html         # HTML template
│   ├── src/
│   │   ├── components/        # React components
│   │   │   ├── TaskForm.js
│   │   │   ├── TaskList.js
│   │   │   ├── TaskItem.js
│   │   │   └── TaskFilter.js
│   │   ├── App.js             # Main application component
│   │   ├── App.test.js        # Frontend tests (8 tests: rendering + interactions)
│   │   ├── setupTests.js      # Jest configuration for React Testing Library
│   │   ├── App.css            # Global styles
│   │   └── index.js           # React entry point
│   ├── Dockerfile             # Frontend container (multi-stage: build + nginx)
│   ├── nginx.conf             # Nginx configuration (SPA routing + API proxy)
│   └── package.json           # Frontend dependencies
├── Jenkinsfile                # Jenkins pipeline (8 stages, containerized tests)
├── docker-compose.yml         # Docker compose for development
├── docker-compose.prod.yml    # Docker compose for production (ECR images)
├── provision-ec2.sh           # AWS EC2 provisioning script
├── JENKINS_SETUP.md           # Complete Jenkins setup guide
├── CI_CD_EVIDENCE.md          # Build #18 logs, test results, deployment evidence
├── AWS_PROVISIONING.md        # AWS infrastructure documentation
├── docs/                      # Documentation directory
│   ├── SPRINT_0_PLANNING.md   # Sprint 0 planning documents
│   ├── SPRINT_1_REVIEW.md     # Sprint 1 review and retrospective
│   └── SPRINT_2_REVIEW.md     # Sprint 2 review and retrospective
└── README.md                  # This file
```

## Agile Process

### Sprint Structure
- **Sprint 0**: Planning and setup
- **Sprint 1**: Core features + CI/CD setup
- **Sprint 2**: Additional features + monitoring

### Sprint Documents
- [Sprint 0 Planning](docs/SPRINT_0_PLANNING.md)
- [Sprint 1 Review & Retrospective](docs/SPRINT_1_REVIEW.md)
- [Sprint 2 Review & Retrospective](docs/SPRINT_2_REVIEW.md)

### Definition of Done
1. Code complete and reviewed
2. All tests passing with >80% coverage
3. CI pipeline green
4. Feature works per acceptance criteria
5. Code follows quality standards
6. Documentation updated
7. No critical bugs

## API Endpoints

### Tasks
- `POST /api/tasks` - Create a new task
- `GET /api/tasks` - Get all tasks
- `PATCH /api/tasks/:id` - Update task status
- `PUT /api/tasks/:id` - Edit task details
- `DELETE /api/tasks/:id` - Delete a task

### Monitoring
- `GET /health` - Health check endpoint

## Development Guidelines

### Branching Strategy
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature branches
- `bugfix/*` - Bug fix branches

### Commit Message Format
```
<type>: <subject>

<body>

Example:
feat: Add task filtering by status (US-006)

Implemented filter component with All, Active, and Completed tabs
```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `style`: Code style changes
- `chore`: Build or auxiliary tool changes

## Learning Outcomes

This project demonstrates:
1. Application of Agile principles (user stories, sprints, retrospectives)
2. DevOps practices (CI/CD, automated testing, monitoring)
3. Iterative development with incremental delivery
4. Test-driven development approach
5. Git workflow with meaningful commit history
6. Code quality and documentation standards




**Project Date**: February 2026  
**Version**: 1.0.0  
**Status**: Completed  
