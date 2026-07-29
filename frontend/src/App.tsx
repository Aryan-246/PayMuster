import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <main style={{ padding: '2rem', fontFamily: 'Inter, sans-serif' }}>
        <h1>PayMuster Admin</h1>
        <p>Project foundation scaffold is ready.</p>
      </main>
    </QueryClientProvider>
  );
}

export default App;
