import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <main className="min-h-screen bg-[#0b1114] px-6 py-10 text-slate-100">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 rounded-2xl border border-white/10 bg-[#182126] p-8 shadow-2xl">
          <div className="space-y-2">
            <p className="text-sm uppercase tracking-[0.3em] text-[#f4b400]">PayMuster</p>
            <h1 className="text-3xl font-semibold">Project foundation scaffold</h1>
            <p className="max-w-2xl text-sm text-slate-300">
              The web foundation is in place with React, Vite, Tailwind CSS, and TanStack Query for the admin experience.
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-3">
            <div className="rounded-xl border border-white/10 bg-[#121a1f] p-4">
              <h2 className="font-medium">Foundation</h2>
              <p className="mt-2 text-sm text-slate-400">Base app shell and build pipeline.</p>
            </div>
            <div className="rounded-xl border border-white/10 bg-[#121a1f] p-4">
              <h2 className="font-medium">Stack</h2>
              <p className="mt-2 text-sm text-slate-400">React, Vite, Tailwind, TanStack Query.</p>
            </div>
            <div className="rounded-xl border border-white/10 bg-[#121a1f] p-4">
              <h2 className="font-medium">Ready</h2>
              <p className="mt-2 text-sm text-slate-400">Build verified and waiting for the next phase.</p>
            </div>
          </div>
        </div>
      </main>
    </QueryClientProvider>
  );
}

export default App;
