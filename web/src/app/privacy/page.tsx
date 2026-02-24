import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy — Outlive Engine",
  description: "How Outlive Engine collects, uses, and protects your health data.",
};

export default function PrivacyPolicyPage() {
  const lastUpdated = "February 24, 2026";

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="max-w-3xl mx-auto px-6 py-16">
        <Link
          href="/dashboard"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; Back to Dashboard
        </Link>

        <h1 className="text-3xl font-bold mt-8 mb-2">Privacy Policy</h1>
        <p className="text-sm text-muted mb-10">Last updated: {lastUpdated}</p>

        <div className="prose prose-invert max-w-none space-y-8 text-sm leading-relaxed">
          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">1. Introduction</h2>
            <p className="text-muted">
              Outlive Engine ("we," "us," or "our") is a personal longevity-tracking platform
              that helps you monitor and optimize your health data. This Privacy Policy explains
              how we collect, use, store, and protect your information when you use our
              application and services.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">2. Information We Collect</h2>
            <p className="text-muted mb-3">We collect the following categories of information:</p>

            <h3 className="text-sm font-semibold text-foreground mb-1">Account Information</h3>
            <p className="text-muted mb-3">
              Email address, display name, and authentication credentials necessary to create
              and secure your account.
            </p>

            <h3 className="text-sm font-semibold text-foreground mb-1">Health &amp; Biometric Data</h3>
            <p className="text-muted mb-3">
              Bloodwork panel results, body composition measurements, genomic risk profiles,
              genetic variant data (e.g. from 23andMe), wearable device metrics (heart rate,
              HRV, sleep scores, recovery scores, strain), and daily protocol logs. This data
              is provided directly by you or synced from connected third-party services with
              your explicit authorization.
            </p>

            <h3 className="text-sm font-semibold text-foreground mb-1">Wearable Device Data</h3>
            <p className="text-muted mb-3">
              If you connect a wearable device (Oura Ring, Whoop, or Apple Watch), we receive
              OAuth access tokens to retrieve your daily health metrics. We store these tokens
              securely to enable automatic data syncing. You may disconnect a wearable at any
              time from Settings, which immediately revokes our access.
            </p>

            <h3 className="text-sm font-semibold text-foreground mb-1">Chat &amp; AI Interaction Data</h3>
            <p className="text-muted mb-3">
              Messages you send to the built-in health advisor chatbot and the AI-generated
              responses. These are stored to maintain conversation history and improve your
              experience.
            </p>

            <h3 className="text-sm font-semibold text-foreground mb-1">Usage &amp; Audit Data</h3>
            <p className="text-muted">
              API request logs (method, path, status code, duration) for security monitoring
              and debugging. IP addresses may be recorded for rate limiting and abuse prevention.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">3. How We Use Your Information</h2>
            <ul className="list-disc list-inside text-muted space-y-1">
              <li>Generate personalized daily health protocols (training, nutrition, supplements, sleep)</li>
              <li>Provide AI-powered health insights and chat-based advisory</li>
              <li>Analyze trends across your bloodwork, genomics, and wearable data</li>
              <li>Sync data between your connected wearable devices and the platform</li>
              <li>Maintain and secure your account</li>
              <li>Improve the accuracy and relevance of our AI recommendations</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">4. Data Encryption &amp; Security</h2>
            <p className="text-muted mb-3">
              We treat your health data with the highest level of care:
            </p>
            <ul className="list-disc list-inside text-muted space-y-1">
              <li>
                <strong className="text-foreground">Encryption at rest:</strong> All sensitive
                fields (bloodwork markers, genomic data, wearable metrics, chat messages,
                protocol details) are encrypted using AES-256-GCM before storage.
              </li>
              <li>
                <strong className="text-foreground">Encryption in transit:</strong> All
                communications between your browser, our servers, and third-party APIs use
                TLS/HTTPS.
              </li>
              <li>
                <strong className="text-foreground">Token security:</strong> OAuth tokens for
                wearable integrations are stored in the database and never exposed to the
                client. JWT tokens use short expiration windows with rotation on refresh.
              </li>
              <li>
                <strong className="text-foreground">Audit logging:</strong> All API access is
                logged for security monitoring with automatic cleanup of expired records.
              </li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">5. AI &amp; Local Model Processing</h2>
            <p className="text-muted">
              Our AI features use a locally-hosted language model by default. Your health data
              is sent to this local model for processing and is not transmitted to third-party
              AI providers unless you explicitly configure a cloud model. AI-generated protocols
              and chat responses are stored encrypted alongside your other health data.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">6. Third-Party Services</h2>
            <p className="text-muted mb-3">
              We integrate with the following third-party services only when you explicitly
              connect them:
            </p>
            <ul className="list-disc list-inside text-muted space-y-1">
              <li><strong className="text-foreground">Oura:</strong> Sleep, readiness, and heart rate data via Oura API v2</li>
              <li><strong className="text-foreground">Whoop:</strong> Recovery, strain, sleep, and cycle data via Whoop Developer API</li>
              <li><strong className="text-foreground">23andMe:</strong> Genetic variant data uploaded directly by you (file upload, not API)</li>
            </ul>
            <p className="text-muted mt-3">
              We do not sell, rent, or share your health data with any third party. Data
              retrieved from wearable APIs is used solely to power your personalized protocols.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">7. Data Retention &amp; Deletion</h2>
            <p className="text-muted">
              Your data is retained for as long as your account is active. You may request
              deletion of your account and all associated data at any time by contacting us.
              Upon account deletion, all personal data, health records, chat history, and
              wearable tokens are permanently removed. Audit logs are retained for up to 90
              days after deletion for security purposes and then purged.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">8. Your Rights</h2>
            <p className="text-muted mb-3">You have the right to:</p>
            <ul className="list-disc list-inside text-muted space-y-1">
              <li>Access all personal and health data we store about you</li>
              <li>Correct inaccurate data</li>
              <li>Delete your account and all associated data</li>
              <li>Disconnect any wearable integration at any time</li>
              <li>Export your data in a portable format</li>
              <li>Withdraw consent for data processing</li>
            </ul>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">9. Children's Privacy</h2>
            <p className="text-muted">
              Outlive Engine is not intended for use by individuals under the age of 18. We do
              not knowingly collect personal information from children.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">10. Changes to This Policy</h2>
            <p className="text-muted">
              We may update this Privacy Policy from time to time. Changes will be reflected on
              this page with an updated "Last updated" date. Continued use of the platform
              after changes constitutes acceptance of the revised policy.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-semibold text-foreground mb-2">11. Contact</h2>
            <p className="text-muted">
              If you have questions about this Privacy Policy or wish to exercise your data
              rights, please open an issue on the project repository or contact the maintainer
              directly.
            </p>
          </section>
        </div>

        <div className="border-t border-[var(--surface-elevated)] mt-12 pt-6 text-xs text-muted">
          &copy; {new Date().getFullYear()} Outlive Engine. All rights reserved.
        </div>
      </div>
    </div>
  );
}
