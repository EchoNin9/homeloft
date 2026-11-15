import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { initTheme } from './theme';

initTheme();
// Vite replaces MODE at build time, so normal builds drop this branch and the mock with it.
if (import.meta.env.MODE === 'demo') (await import('../mock/demo')).installDemoApi();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
