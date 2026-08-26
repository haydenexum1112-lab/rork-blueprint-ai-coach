import { Link } from "react-router-dom";

const Support = () => {
  return (
    <div className="min-h-screen bg-[#F5F8FC] text-[#1a1a1a]">
      <header className="border-b border-slate-200/60 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-5">
          <Link to="/" className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-[#00B2E0]">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="3" width="7" height="7" rx="1" />
                <rect x="14" y="3" width="7" height="7" rx="1" />
                <rect x="3" y="14" width="7" height="7" rx="1" />
                <rect x="14" y="14" width="7" height="7" rx="1" />
              </svg>
            </div>
            <span className="text-lg font-black tracking-tight">PhyziqAi</span>
          </Link>
          <nav className="flex items-center gap-6 text-sm font-semibold text-slate-600">
            <Link to="/support" className="text-[#00B2E0]">Support</Link>
            <Link to="/privacy" className="hover:text-[#00B2E0] transition-colors">Privacy</Link>
            <Link to="/terms" className="hover:text-[#00B2E0] transition-colors">Terms</Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-16">
        <h1 className="mb-2 text-4xl font-black tracking-tight">Support</h1>
        <p className="mb-10 text-slate-500">We're here to help. Here's how to reach us and what to include.</p>

        <div className="space-y-8">
          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Contact Us</h2>
            <p className="mb-2 text-slate-600">For any questions, bug reports, or feedback, email us at:</p>
            <a href="mailto:myphyziqai@gmail.com" className="font-bold text-[#00B2E0]">myphyziqai@gmail.com</a>
            <p className="mt-3 text-sm text-slate-500">We aim to respond within 48 hours.</p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">When You Reach Out, Please Include</h2>
            <ul className="space-y-2 text-slate-600">
              <li className="flex gap-3"><span className="text-[#00B2E0]">•</span> App version (found in Profile tab)</li>
              <li className="flex gap-3"><span className="text-[#00B2E0]">•</span> Device model (e.g., iPhone 15 Pro)</li>
              <li className="flex gap-3"><span className="text-[#00B2E0]">•</span> iOS version (Settings → General → About)</li>
              <li className="flex gap-3"><span className="text-[#00B2E0]">•</span> Account email or user ID if you have one</li>
              <li className="flex gap-3"><span className="text-[#00B2E0]">•</span> Screenshots or a description of what happened</li>
            </ul>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Subscriptions & Billing</h2>
            <p className="mb-3 text-slate-600">
              PhyziqAi offers three plans: Workouts ($12.99/mo or $79/yr), Nutrition ($7.99/mo or $49/yr),
              and Everything ($16.99/mo or $99/yr — best value). All plans start with a 7-day free trial.
            </p>
            <p className="text-slate-600">
              To manage or cancel a subscription: open the Settings app on your iPhone → tap your name →
              tap Subscriptions → select PhyziqAi. You can also request billing help by emailing us.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Physique Score & Confidence</h2>
            <p className="mb-3 text-slate-600">
              Your physique score (1-100) is an AI-generated estimate based on your photos, relative to
              your training experience level. It includes a confidence rating (Low, Medium, or High)
              that reflects how clearly the AI could assess your photos.
            </p>
            <p className="text-slate-600">
              <strong>Low confidence</strong> means the photos were poorly lit, angled, or partially
              obscured. <strong>High confidence</strong> means all three frames were clear and well-lit.
              The score is for motivation and tracking — it is not a clinical or medical-grade assessment.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Health Screener (PAR-Q)</h2>
            <p className="mb-3 text-slate-600">
              Before your first training plan, PhyziqAi asks you to complete a 7-question health
              questionnaire (the PAR-Q, used by fitness professionals worldwide). If you answer yes to
              any question, we recommend consulting a physician before starting.
            </p>
            <p className="text-slate-600">
              You can still proceed anyway, but we strongly encourage you to check with your doctor first
              and bring your PhyziqAi plan to that conversation.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">iCloud Backup</h2>
            <p className="mb-3 text-slate-600">
              PhyziqAi offers an optional iCloud backup for your scan analysis metadata (scores, dates,
              and training plans). When enabled, this data is encrypted with a device-generated key and
              stored in your iCloud account. Physique photos are never included in cloud backup.
            </p>
            <p className="text-slate-600">
              To enable: Profile → Privacy & data → toggle on "iCloud backup." You can back up, restore,
              or delete your cloud backup at any time from the same screen.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Account Deletion & Data Requests</h2>
            <p className="mb-3 text-slate-600">
              To delete your account, remove stored data, or request a data export, visit our
              <Link to="/privacy-choices" className="text-[#00B2E0] font-semibold"> Privacy Choices</Link> page
              or email us with "Data Request" in the subject line.
            </p>
            <p className="text-slate-600">
              Note: Your physique scan photos are stored only on your device and are never uploaded to
              our servers. Deleting the app removes them immediately.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Troubleshooting</h2>
            <ul className="space-y-3 text-slate-600">
              <li><strong>Camera not working?</strong> Go to Settings → PhyziqAi → Camera and make sure it's enabled.</li>
              <li><strong>Apple Health not syncing?</strong> Go to Profile → Apple Health and tap "Connect" again. Confirm permissions in the Health app.</li>
              <li><strong>AI scan failed?</strong> Ensure good lighting, wear fitted clothing, and capture front, side, and back angles from head to toe.</li>
              <li><strong>Workout plan locked?</strong> Day 1 is free with the 7-day trial. Choose a plan to unlock your full weekly schedule.</li>
            </ul>
          </section>
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

export default Support;
