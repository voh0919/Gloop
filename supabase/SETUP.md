# Connecting Gloop to its server (Supabase)

Until these steps are done, Gloop keeps accounts on the phone only. Each step
happens in a website, signed in as you. Supabase's free tier is enough.

## 1. Create the project

1. Sign up at https://supabase.com and click **New project**.
2. Name it `gloop`, set a database password (save it in your password manager),
   pick the region closest to you, and create it. It takes a minute or two.

## 2. Set up the database

1. In the project, open **SQL Editor** → **New query**.
2. Paste all of `supabase/setup.sql` and press **Run**.
   It creates profiles (name and invite code), makes one for every new
   account automatically, and adds the function behind **Delete account**.

## 3. Connect the app

1. Open **Project Settings** → **API**.
2. Copy **Project URL** and the **anon / publishable** key into
   `Services/SupabaseConfig.swift` (`url` and `anonKey`).
   Never use the `service_role` / secret key in the app.
3. Open **Authentication** → **URL Configuration** → **Redirect URLs**, and add
   `gloop://auth-callback` (Google sign-in returns there).

## 4. Email codes (sign-up confirmation and password reset)

Gloop asks for a 6-digit code instead of a link, so emails must include the code:

1. Open **Authentication** → **Email Templates**.
2. In **Confirm signup** and in **Reset password**, add a line such as
   `Your Gloop code is {{ .Token }}` and save.

For quick testing you can instead turn off **Confirm email** under
**Authentication** → **Sign In / Providers** → **Email**. New accounts are then
signed in right away. Turn it back on before real people use Gloop.

Supabase's built-in email sender only sends a few emails an hour. Before launch,
add your own email service under **Authentication** → **Emails** → **SMTP**.

## 5. Google

1. Go to https://console.cloud.google.com, create a project (e.g. `Gloop`).
2. **APIs & Services** → **OAuth consent screen**: set it up as External, with
   the app name Gloop and your support email.
3. **Credentials** → **Create credentials** → **OAuth client ID** →
   type **Web application**. Under **Authorized redirect URIs** add
   `https://<your-project-ref>.supabase.co/auth/v1/callback`
   (the exact address is shown in Supabase under **Authentication** →
   **Sign In / Providers** → **Google**).
4. Copy the **Client ID** and **Client secret** into that Google page in
   Supabase, turn Google on, and save.

## 6. Apple (once you have the Apple Developer Program)

Sign in with Apple needs a paid Apple Developer account, and the app needs the
**Sign in with Apple** capability. App Playgrounds (`.swiftpm`) can't add that
capability, so this step goes with moving Gloop to a regular Xcode app project,
which a real Screen Time app needs anyway.

1. In the Apple Developer site, turn on **Sign in with Apple** for the app's
   identifier (currently `app.lockbuddy.prototype`).
2. In Xcode, add the **Sign in with Apple** capability to the app target.
3. In Supabase, **Authentication** → **Sign In / Providers** → **Apple**:
   turn it on and add the bundle identifier as a **Client ID**.

Until then, the Apple button says Sign in with Apple isn't set up for this build.

## Check it works

Run the app, create an account with your own email, and confirm it with the
code. The account then appears in Supabase under **Authentication** → **Users**,
and its name and invite code under **Table Editor** → **profiles**.
