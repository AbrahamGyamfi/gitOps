import { render, screen, waitFor } from '@testing-library/react';
import App from './App';

// Mock fetch globally
global.fetch = jest.fn();

describe('App Component', () => {
  beforeEach(() => {
    fetch.mockClear();
    fetch.mockResolvedValue({
      ok: true,
      json: async () => []
    });
  });

  test('renders TaskFlow heading', async () => {
    render(<App />);
    const headingElement = screen.getByRole('heading', { name: /taskflow/i });
    expect(headingElement).toBeInTheDocument();
    
    // Wait for async operations to complete
    await waitFor(() => {
      expect(fetch).toHaveBeenCalled();
    });
  });

  test('renders task form', async () => {
    render(<App />);
    const inputElement = screen.getByPlaceholderText(/task title/i);
    expect(inputElement).toBeInTheDocument();
    
    // Wait for async operations to complete
    await waitFor(() => {
      expect(fetch).toHaveBeenCalled();
    });
  });

  test('fetches tasks on mount', async () => {
    render(<App />);
    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith(expect.stringContaining('/api/tasks'));
    });
  });
});
