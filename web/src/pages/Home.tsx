import { Link } from "react-router-dom";

const Home = () => {
  return (
    <div className="min-h-screen bg-[#F5F8FC] text-[#1a1a1a]">
      {/* Hero */}
      <header className="border-b border-slate-200/60 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-5">
          <div className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#00B2E0]">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="3" width="7" height="7" rx="1" />
                <rect x="14" y="3" width="7" height="7" rx="1" />
                <rect x="3" y="14" width="7" height="7" rx="1" />
                <rect x="14" y="14" width="7" height="7" rx="1" />
              </svg>
            </div>
            <span className="text-lg font-black tracking-tight">PhyziqAi</span>
          </div>
          <nav className="flex items-center gap-6 text-sm font-semibold text-slate-600">
            <Link to="/support" className="hover:text-[#00B2E0] transition-colors">Support</Link>
            <Link to="/privacy" className="hover:text-[#00B2E0] transition-colors">Privacy</Link>
            <Link to="/terms" className="hover:text-[#00B2E0] transition-colors">Terms</Link>
          </nav>
        </div>
      </header>

      {/* Main */}
      <main className="mx-auto max-w-4xl px-6 py-20">
        <div className="text-center">
          <p className="mb-4 text-sm font-black uppercase tracking-[0.3em] text-[#00B2E0]">AI Physique Coach</p>
          <h1 className="mb-6 text-5xl font-black leading-tight tracking-tight">
            See the gap.<br />
            <span className="text-[#00B2E0]">Close it.</span>
          </h1>
          <p className="mx-auto mb-12 max-w-xl text-lg text-slate-600 leading-relaxed">
            PhyziqAi scans your physique, compares it to your goal, and builds a personalized
            week-by-week training plan — with nutrition tracking, food scanning, and Apple Health
            integration.
          </p>
        </div>

        {/* Feature grid */}
        <div className="mt-16 grid gap-6 sm:grid-cols-3">
          <div className="rounded-2xl border border-slate-200 bg-white p-6">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-[#00B2E0]/10">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#00B2E0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                <line x1="12" y1="19" x2="12" y2="22" />
              </svg>
            </div>
            <h3 className="mb-1 font-bold">Physique Scan</h3>
            <p className="text-sm text-slate-500">AI-powered photo analysis maps your current physique and measures the gap to your goal body.</p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-white p-6">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-[#00B2E0]/10">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#00B2E0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="m6.5 6.5 11 11" />
                <path d="m21 21-1-1" />
                <path d="m3 3 1 1" />
                <path d="m18 22 4-4" />
                <path d="m2 6 4-4" />
                <path d="m3 10 7-7" />
                <path d="m14 21 7-7" />
              </svg>
            </div>
            <h3 className="mb-1 font-bold">Smart Training Plan</h3>
            <p className="text-sm text-slate-500">Week-by-week workouts with progressive overload, deload weeks, and equipment-aware exercise selection.</p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-white p-6">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-[#00B2E0]/10">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#00B2E0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M11 12H3a16 16 0 0 0 3.5 8.5" />
                <path d="M21 12a16 16 0 0 1-3.5 8.5" />
                <path d="M12 21a16 16 0 0 0 8.5-3.5" />
                <path d="M12 3a16 16 0 0 1 8.5 3.5" />
                <path d="M3.5 11.5 12 3l8.5 8.5" />
              </svg>
            </div>
            <h3 className="mb-1 font-bold">Nutrition & Health</h3>
            <p className="text-sm text-slate-500">Food photo scanning, barcode lookup, macro tracking, and two-way Apple Health sync for weight and workouts.</p>
          </div>
        </div>

        {/* Legal links */}
        <div className="mt-16 rounded-2xl border border-slate-200 bg-white p-8 text-center">
          <h2 className="mb-2 text-xl font-bold">Legal & Support</h2>
          <p className="mb-6 text-slate-500">These pages support App Store publishing, account help, privacy requests, and product support.</p>
          <div className="flex flex-wrap justify-center gap-4">
            <Link to="/support" className="rounded-lg bg-[#00B2E0] px-5 py-2.5 text-sm font-bold text-white transition-opacity hover:opacity-90">Support</Link>
            <Link to="/privacy" className="rounded-lg border border-slate-300 px-5 py-2.5 text-sm font-bold text-slate-700 transition-colors hover:border-[#00B2E0] hover:text-[#00B2E0]">Privacy Policy</Link>
            <Link to="/terms" className="rounded-lg border border-slate-300 px-5 py-2.5 text-sm font-bold text-slate-700 transition-colors hover:border-[#00B2E0] hover:text-[#00B2E0]">Terms of Use</Link>
            <Link to="/privacy-choices" className="rounded-lg border border-slate-300 px-5 py-2.5 text-sm font-bold text-slate-700 transition-colors hover:border-[#00B2E0] hover:text-[#00B2E0]">Privacy Choices</Link>
          </div>
        </div>
      </main>

      <footer className="border-t border-slate-200/60 bg-white py-8">
        <div className="mx-auto max-w-4xl px-6 text-center text-sm text-slate-400">
          <p>&copy; 2026 PhyziqAi. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default Home;
