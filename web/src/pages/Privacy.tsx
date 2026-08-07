import { Link } from "react-router-dom";

const Privacy = () => {
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
            <Link to="/support" className="hover:text-[#00B2E0] transition-colors">Support</Link>
            <Link to="/privacy" className="text-[#00B2E0]">Privacy</Link>
            <Link to="/terms" className="hover:text-[#00B2E0] transition-colors">Terms</Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-16">
        <h1 className="mb-2 text-4xl font-black tracking-tight">Privacy Policy</h1>
        <p className="mb-10 text-sm text-slate-400">Effective date: July 23, 2026</p>

        <div className="space-y-8 text-slate-700 leading-relaxed">
          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Who We Are</h2>
            <p>
              PhyziqAi is an AI physique coaching app for iOS. This policy explains what data we collect,
              why we collect it, and your rights regarding that data. For any privacy questions, email
              <a href="mailto:support@phyziqai.app" className="text-[#00B2E0] font-semibold"> support@phyziqai.app</a>.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Data We Collect</h2>
            <div className="space-y-4">
              <div>
                <h3 className="font-semibold mb-1">Account & Profile Data</h3>
                <p className="text-sm text-slate-600">
                  When you sign in with Apple or Google, we receive your name and email address through
                  our authentication provider (Rork Auth). Your profile includes age, sex, height, weight,
                  training experience, equipment access, and fitness goals — all stored on your device.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Physique Scan Photos</h3>
                <p className="text-sm text-slate-600">
                  Photos you capture during a physique scan (front, side, and back) are stored
                  <strong> only on your device</strong> in the app's Documents directory, excluded from
                  iCloud backups. They are never uploaded to our servers. Temporary copies are sent to
                  our AI analysis provider (Anthropic) for analysis and deleted from their systems after
                  processing. If you enable iCloud Backup (opt-in), only your encrypted scan
                  <strong> metadata</strong> (scores, dates, plans) is backed up — never the photos themselves.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">iCloud Backup (Opt-in)</h3>
                <p className="text-sm text-slate-600">
                  PhyziqAi offers an optional iCloud backup for your scan analysis metadata. When enabled,
                  your physique scores, dates, and training plans are encrypted with a device-generated key
                  stored in your Keychain and synced to your iCloud account. Physique photos are never
                  included in cloud backup — they remain on-device only. You can disable iCloud backup,
                  delete the cloud backup, or restore from backup at any time in Profile → Privacy & data.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Goal Reference Photos</h3>
                <p className="text-sm text-slate-600">
                  Photos of your target physique that you upload are stored on your device and sent to
                  the AI for gap analysis. They are not retained on our servers.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Food Log & Nutrition Data</h3>
                <p className="text-sm text-slate-600">
                  Food entries you log manually or via food photo/barcode scanning are stored on your
                  device. Food photos are sent to the AI for ingredient and macro estimation, then
                  discarded. If connected, nutrition data (calories, macros) is written to Apple Health.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Workout & Training Data</h3>
                <p className="text-sm text-slate-600">
                  Your training plan, logged sets, reps, weights, workout sessions, and calendar history
                  are stored on your device. If Apple Health is connected, workout data may sync to the
                  Health app.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Apple Health Data</h3>
                <p className="text-sm text-slate-600">
                  With your permission, PhyziqAi reads body weight, workouts, steps, and active energy
                  from Apple Health, and writes logged nutrition data (calories and macros) to Apple Health.
                  This data stays on your device and in your Health app — it is not uploaded to our servers.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Camera Access</h3>
                <p className="text-sm text-slate-600">
                  PhyziqAi uses the camera to capture physique scan photos and food photos. Camera access
                  is requested at the point of use and can be revoked at any time in Settings → PhyziqAi → Camera.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Subscription Data</h3>
                <p className="text-sm text-slate-600">
                  If you subscribe to PhyziqAi Pro or the Nutrition add-on, purchase and subscription
                  status are managed by Apple's StoreKit framework. We do not store your payment information.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">AI Processing</h2>
            <p>
              PhyziqAi uses Anthropic's Claude AI to analyze your physique photos, generate training plans,
              identify food from photos, and create nutrition plans. When you use these features, the
              relevant photos and context are sent to Anthropic's servers for processing. Anthropic processes
              this data according to their own privacy policy and retention terms. We instruct the AI not to
              store or train on your images after analysis.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Third-Party Services</h2>
            <ul className="space-y-2 text-sm">
              <li><strong>Anthropic</strong> — AI analysis of physique photos, food photos, and plan generation</li>
              <li><strong>Apple Sign In / Google Sign In</strong> (via Rork Auth) — authentication only; no tracking</li>
              <li><strong>Apple HealthKit</strong> — reads and writes health data with your permission</li>
              <li><strong>Apple StoreKit</strong> — subscription management</li>
              <li><strong>Open Food Facts API</strong> — barcode lookup for packaged foods</li>
            </ul>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Data Sharing & Selling</h2>
            <p>
              We do not sell your data. We do not share your data with third parties for advertising or
              tracking. The only data shared is with Anthropic (for AI processing), Apple (for authentication
              and subscriptions), and the Open Food Facts API (for barcode lookups) — each strictly for the
              purpose of providing the feature you invoked.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Data Retention & Deletion</h2>
            <p>
              All physique photos, food photos, workout logs, and profile data are stored locally on your
              device. Deleting the app immediately removes all local data. Data sent to Anthropic for AI
              processing is not retained beyond the processing period. To request deletion of any server-side
              account data, email us or visit our
              <Link to="/privacy-choices" className="text-[#00B2E0] font-semibold"> Privacy Choices</Link> page.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Your Rights</h2>
            <ul className="space-y-2 text-sm">
              <li><strong>Access:</strong> Request a copy of your account data</li>
              <li><strong>Correction:</strong> Update your profile information in the app at any time</li>
              <li><strong>Deletion:</strong> Delete your account and all associated data</li>
              <li><strong>Export:</strong> Request an export of your data</li>
              <li><strong>Opt-out:</strong> Revoke camera, Health, and AI processing permissions at any time</li>
            </ul>
            <p className="mt-3 text-sm">
              See our <Link to="/privacy-choices" className="text-[#00B2E0] font-semibold">Privacy Choices</Link> page
              for instructions.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Children's Privacy</h2>
            <p>
              PhyziqAi is designed for adults aged 18 and older. The app includes a hard age gate during
              onboarding. We do not knowingly collect data from anyone under 18. If you believe a minor has
              used the app, please contact us so we can remove any associated data.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">International Data Transfer</h2>
            <p>
              Since AI processing uses Anthropic's cloud infrastructure, your photos and related data may be
              processed in the United States or other regions where Anthropic operates. By using PhyziqAi's
              AI features, you consent to this transfer.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Changes to This Policy</h2>
            <p>
              We may update this Privacy Policy from time to time. The effective date above reflects the
              most recent revision. Continued use of the app after changes constitutes acceptance of the
              updated policy.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold text-[#1a1a1a]">Contact</h2>
            <p>
              For any privacy questions or data requests, email
              <a href="mailto:support@phyziqai.app" className="text-[#00B2E0] font-semibold"> support@phyziqai.app</a>.
            </p>
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

export default Privacy;
