import { Link } from "react-router-dom";

const PrivacyChoices = () => {
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
            <span className="text-lg font-black tracking-tight">Blueprint</span>
          </Link>
          <nav className="flex items-center gap-6 text-sm font-semibold text-slate-600">
            <Link to="/support" className="hover:text-[#00B2E0] transition-colors">Support</Link>
            <Link to="/privacy" className="hover:text-[#00B2E0] transition-colors">Privacy</Link>
            <Link to="/terms" className="hover:text-[#00B2E0] transition-colors">Terms</Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-16">
        <h1 className="mb-2 text-4xl font-black tracking-tight">Privacy Choices</h1>
        <p className="mb-10 text-slate-500">Your data, your control. Here's how to manage everything.</p>

        <div className="space-y-8">
          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Access Your Data</h2>
            <p className="mb-3 text-slate-600">
              Most of your data — physique photos, food logs, workout history, and profile — is stored locally
              on your device. To see it, simply open the app.
            </p>
            <p className="text-slate-600">
              To request a copy of any server-side account data (such as your auth profile), email
              <a href="mailto:support@blueprint.app?subject=Data Access Request" className="text-[#00B2E0] font-semibold"> support@blueprint.app</a>
              with "Data Access Request" in the subject.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Delete Your Data</h2>
            <div className="space-y-3 text-slate-600">
              <p><strong>Physique photos, food photos, workout logs, and profile:</strong> Delete the Blueprint app from your iPhone. This immediately removes all locally stored data.</p>
              <p><strong>iCloud backup:</strong> Open Blueprint → Profile → Privacy & data → tap "Delete cloud backup." This removes all encrypted scan metadata from your iCloud account. Your on-device data is not affected.</p>
              <p><strong>Server-side account data:</strong> Email <a href="mailto:support@blueprint.app?subject=Data Deletion Request" className="text-[#00B2E0] font-semibold">support@blueprint.app</a> with "Data Deletion Request" in the subject. We will permanently delete your account and associated server-side records within 30 days.</p>
              <p><strong>Apple Health data:</strong> Go to the Health app → Summary → Blueprint → scroll to "Data Sources & Access" → tap "Delete All Recorded Data" or revoke access entirely.</p>
            </div>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Export Your Data</h2>
            <p className="mb-3 text-slate-600">
              To export your account data, email
              <a href="mailto:support@blueprint.app?subject=Data Export Request" className="text-[#00B2E0] font-semibold"> support@blueprint.app</a>
              with "Data Export Request" in the subject. We will provide your server-side data in a portable format within 30 days.
            </p>
            <p className="text-slate-600">
              For workout and nutrition data stored in Apple Health, use the Health app → tap your profile
              icon → "Export All Health Data" to receive a ZIP file.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Revoke Permissions</h2>
            <ul className="space-y-3 text-slate-600">
              <li>
                <strong>Camera:</strong> Settings → Blueprint → Camera → turn off. Blueprint will no longer
                be able to capture scan or food photos.
              </li>
              <li>
                <strong>Apple Health:</strong> Open Blueprint → Profile → Apple Health → tap "Disconnect."
                Or go to Settings → Privacy & Security → Health → Blueprint → turn off all access.
              </li>
              <li>
                <strong>iCloud Backup:</strong> Open Blueprint → Profile → Privacy & data → toggle off
                "iCloud backup." Then tap "Delete cloud backup" to remove existing backed-up data.
              </li>
              <li>
                <strong>AI Processing:</strong> Simply stop using scan, food scanning, or meal plan features.
                No AI processing occurs unless you initiate it.
              </li>
            </ul>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Opt Out of AI Photo Analysis</h2>
            <p className="text-slate-600">
              If you prefer not to have your photos processed by AI, you can still use Blueprint's manual
              workout logging and food entry features without triggering any AI analysis. Simply avoid the
              scan, food photo, and barcode features.
            </p>
          </section>

          <section className="rounded-2xl border border-slate-200 bg-white p-8">
            <h2 className="mb-3 text-xl font-bold">Verification</h2>
            <p className="text-slate-600">
              When submitting a data request, please include the email address associated with your Blueprint
              account so we can verify your identity. We may ask for additional confirmation for sensitive
              requests.
            </p>
          </section>
        </div>
      </main>

      <footer className="border-t border-slate-200/60 bg-white py-8">
        <div className="mx-auto max-w-4xl px-6 text-center text-sm text-slate-400">
          <p>&copy; 2026 Blueprint. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default PrivacyChoices;
