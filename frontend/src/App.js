import React, { useState, useEffect } from 'react';
import './App.css';
import TaskForm from './components/TaskForm';
import TaskList from './components/TaskList';
import TaskFilter from './components/TaskFilter';

const API_URL = process.env.REACT_APP_API_URL || '/api';

function App() {
  const [tasks, setTasks] = useState([]);
  const [filter, setFilter] = useState('all'); // all, active, completed
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [notification, setNotification] = useState(null);

  // US-002: Fetch tasks on component mount
  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${API_URL}/tasks`);
      if (!response.ok) {
        throw new Error('Failed to fetch tasks');
      }
      const data = await response.json();
      setTasks(data);
      setError(null);
    } catch (err) {
      console.error('Error fetching tasks:', err);
      setError('Failed to load tasks. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // US-001: Create new task
  const handleCreateTask = async (taskData) => {
    try {
      const response = await fetch(`${API_URL}/tasks`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(taskData),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to create task');
      }

      const newTask = await response.json();
      setTasks([newTask, ...tasks]);
      showNotification('Task created successfully!', 'success');
      return true;
    } catch (err) {
      console.error('Error creating task:', err);
      setError(err.message);
      showNotification(err.message, 'error');
      return false;
    }
  };

  // US-003: Toggle task completion status
  const handleToggleComplete = async (taskId, currentStatus) => {
    try {
      const response = await fetch(`${API_URL}/tasks/${taskId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ completed: !currentStatus }),
      });

      if (!response.ok) {
        throw new Error('Failed to update task');
      }

      const updatedTask = await response.json();
      setTasks(tasks.map(task => 
        task.id === taskId ? updatedTask : task
      ));
      showNotification('Task status updated!', 'success');
    } catch (err) {
      console.error('Error updating task:', err);
      setError('Failed to update task. Please try again.');
      showNotification('Failed to update task', 'error');
    }
  };

  // US-004: Delete task (Sprint 2)
  const handleDeleteTask = async (taskId) => {
    if (!window.confirm('Are you sure you want to delete this task?')) {
      return;
    }

    try {
      const response = await fetch(`${API_URL}/tasks/${taskId}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete task');
      }

      setTasks(tasks.filter(task => task.id !== taskId));
      showNotification('Task deleted successfully!', 'success');
    } catch (err) {
      console.error('Error deleting task:', err);
      setError('Failed to delete task. Please try again.');
      showNotification('Failed to delete task', 'error');
    }
  };

  // US-005: Edit task (Sprint 2)
  const handleEditTask = async (taskId, updatedData) => {
    try {
      const response = await fetch(`${API_URL}/tasks/${taskId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(updatedData),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to update task');
      }

      const updatedTask = await response.json();
      setTasks(tasks.map(task => 
        task.id === taskId ? updatedTask : task
      ));
      showNotification('Task updated successfully!', 'success');
      return true;
    } catch (err) {
      console.error('Error updating task:', err);
      setError(err.message);
      showNotification(err.message, 'error');
      return false;
    }
  };

  // Show notification helper
  const showNotification = (message, type) => {
    setNotification({ message, type });
    setTimeout(() => setNotification(null), 3000);
  };

  // US-006: Filter tasks by status
  const getFilteredTasks = () => {
    switch (filter) {
      case 'active':
        return tasks.filter(task => !task.completed);
      case 'completed':
        return tasks.filter(task => task.completed);
      default:
        return tasks;
    }
  };

  const filteredTasks = getFilteredTasks();
  const activeCount = tasks.filter(task => !task.completed).length;
  const completedCount = tasks.filter(task => task.completed).length;

  return (
    <div className="App">
      <header className="App-header">
        <h1>📋 TaskFlow</h1>
        <p className="subtitle">Stay organized, stay productive</p>
      </header>

      {notification && (
        <div className={`notification ${notification.type}`}>
          {notification.message}
        </div>
      )}

      {error && !notification && (
        <div className="error-banner">
          {error}
          <button onClick={() => setError(null)}>✕</button>
        </div>
      )}

      <main className="App-main">
        <div className="container">
          {/* US-001: Task creation form */}
          <TaskForm onCreateTask={handleCreateTask} />

          {/* US-006: Task filter */}
          <TaskFilter 
            currentFilter={filter}
            onFilterChange={setFilter}
            activeCount={activeCount}
            completedCount={completedCount}
            totalCount={tasks.length}
          />

          {/* US-002: Task list display */}
          {loading ? (
            <div className="loading">Loading tasks...</div>
          ) : (
            <TaskList 
              tasks={filteredTasks}
              onToggleComplete={handleToggleComplete}
              onDeleteTask={handleDeleteTask}
              onEditTask={handleEditTask}
            />
          )}
        </div>
      </main>

      <footer className="App-footer">
        <p>TaskFlow v1.0 - Agile Development Project</p>
      </footer>
    </div>
  );
}

export default App;
