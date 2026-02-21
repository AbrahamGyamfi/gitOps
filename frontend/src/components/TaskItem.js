import React, { useState } from 'react';
import './TaskItem.css';

function TaskItem({ task, onToggleComplete, onDeleteTask, onEditTask }) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(task.title);
  const [editDescription, setEditDescription] = useState(task.description);
  const [errors, setErrors] = useState({});

  const handleSaveEdit = async () => {
    const newErrors = {};

    if (!editTitle.trim()) {
      newErrors.title = 'Title is required';
    } else if (editTitle.length > 100) {
      newErrors.title = 'Title must be 100 characters or less';
    }

    if (editDescription.length > 500) {
      newErrors.description = 'Description must be 500 characters or less';
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    const success = await onEditTask(task.id, {
      title: editTitle.trim(),
      description: editDescription.trim(),
    });

    if (success) {
      setIsEditing(false);
      setErrors({});
    }
  };

  const handleCancelEdit = () => {
    setEditTitle(task.title);
    setEditDescription(task.description);
    setIsEditing(false);
    setErrors({});
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  if (isEditing) {
    return (
      <div className="task-item editing">
        <div className="task-edit-form">
          <input
            type="text"
            value={editTitle}
            onChange={(e) => setEditTitle(e.target.value)}
            placeholder="Task title"
            maxLength="100"
            className={errors.title ? 'error' : ''}
          />
          {errors.title && <span className="error-message">{errors.title}</span>}
          
          <textarea
            value={editDescription}
            onChange={(e) => setEditDescription(e.target.value)}
            placeholder="Description"
            maxLength="500"
            rows="3"
            className={errors.description ? 'error' : ''}
          />
          {errors.description && <span className="error-message">{errors.description}</span>}
          
          <div className="edit-actions">
            <button onClick={handleSaveEdit} className="btn-save">
              ✓ Save
            </button>
            <button onClick={handleCancelEdit} className="btn-cancel">
              ✕ Cancel
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`task-item ${task.completed ? 'completed' : ''}`}>
      <div className="task-checkbox">
        <input
          type="checkbox"
          checked={task.completed}
          onChange={() => onToggleComplete(task.id, task.completed)}
          id={`task-${task.id}`}
        />
        <label htmlFor={`task-${task.id}`}></label>
      </div>

      <div className="task-content">
        <h3 className="task-title">{task.title}</h3>
        {task.description && (
          <p className="task-description">{task.description}</p>
        )}
        <div className="task-meta">
          <span className="task-date">Created: {formatDate(task.createdAt)}</span>
          {task.completed && (
            <span className="task-status">✓ Completed</span>
          )}
        </div>
      </div>

      <div className="task-actions">
        <button
          onClick={() => setIsEditing(true)}
          className="btn-edit"
          title="Edit task"
        >
          ✏️
        </button>
        <button
          onClick={() => onDeleteTask(task.id)}
          className="btn-delete"
          title="Delete task"
        >
          🗑️
        </button>
      </div>
    </div>
  );
}

export default TaskItem;
