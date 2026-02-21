import React from 'react';
import './TaskFilter.css';

function TaskFilter({ currentFilter, onFilterChange, activeCount, completedCount, totalCount }) {
  return (
    <div className="task-filter-container">
      <div className="filter-buttons">
        <button
          className={`filter-btn ${currentFilter === 'all' ? 'active' : ''}`}
          onClick={() => onFilterChange('all')}
        >
          All <span className="count">{totalCount}</span>
        </button>
        <button
          className={`filter-btn ${currentFilter === 'active' ? 'active' : ''}`}
          onClick={() => onFilterChange('active')}
        >
          Active <span className="count">{activeCount}</span>
        </button>
        <button
          className={`filter-btn ${currentFilter === 'completed' ? 'active' : ''}`}
          onClick={() => onFilterChange('completed')}
        >
          Completed <span className="count">{completedCount}</span>
        </button>
      </div>
    </div>
  );
}

export default TaskFilter;
