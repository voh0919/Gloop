import Foundation
import Supabase

/// Where Gloop's server lives.
///
/// Fill in these two values from your Supabase project
/// (Project Settings → API). The anon key is meant to ship inside apps;
/// row-level security in `supabase/setup.sql` is what keeps data private.
/// Never put the `service_role` key here.
///
/// While they're empty, Gloop keeps working with accounts stored only on
/// this phone, so the app still runs in the Simulator before setup.
enum SupabaseConfig {
    static let url = "https://qcqqxdnapwiavnlujdsc.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjcXF4ZG5hcHdpYXZubHVqZHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUxMzMzNTQsImV4cCI6MjExMDcwOTM1NH0.vI_XYoiXEgFkGFLS_mjdUuC0EVgFZxaod6VVLQAOUm4"

    /// Where Google sign-in returns to. Add this exact URL in Supabase under
    /// Authentication → URL Configuration → Redirect URLs.
    static let redirectURL = URL(string: "gloop://auth-callback")!

    /// Whether Supabase's emails carry the 6-digit codes Gloop asks for.
    /// That needs your own email service (SMTP) and edited templates, so it's
    /// off for now: "Confirm email" is turned off in Supabase and "Forgot
    /// password?" is hidden. See supabase/SETUP.md, step 4.
    static let emailCodes = false

    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }

    static let client: SupabaseClient? = {
        guard isConfigured, let projectURL = URL(string: url) else { return nil }
        return SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: anonKey,
            options: .init(auth: .init(redirectToURL: redirectURL,
                                       emitLocalSessionAsInitialSession: true))
        )
    }()
}
