import React from 'react';
import './TaskList.css';
import TaskItem from './TaskItem';

function TaskList({ tasks, onToggleComplete, onDeleteTask, onEditTask }) {
  if (tasks.length === 0) {
    return (
      <div className="task-list-container">
        <div className="empty-state">
          <div className="empty-icon">📝</div>
          <h3>No tasks yet</h3>
          <p>Create your first task to get started!</p>
        </div>
      </div>
    );
  }

  return (
    <div className="task-list-container">
      <h2>Your Tasks ({tasks.length})</h2>
      <div className="task-list">
        {tasks.map((task) => (
          <TaskItem
            key={task.id}
            task={task}
            onToggleComplete={onToggleComplete}
            onDeleteTask={onDeleteTask}
            onEditTask={onEditTask}
          />
        ))}
      </div>
    </div>
  );
}

export default TaskList;
