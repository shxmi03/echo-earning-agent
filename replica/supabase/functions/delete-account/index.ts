// POST /functions/v1/delete-account
// Deletes the signed-in user's auth record. Every table cascades from accounts, which
// cascades from auth.users, so this removes all of their data (App Review 5.1.1(v), GDPR).
// Apple doesn't allow a server-side cancel: the app tells the user to cancel any
// subscription in Settings.
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "not_signed_in" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Who is asking: verified by Supabase Auth, never taken from the body.
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) return json({ error: "not_signed_in" }, 401);

  const { error: delError } = await admin.auth.admin.deleteUser(data.user.id);
  if (delError) {
    console.error("delete-account failed", delError.message); // no user data in logs
    return json({ error: "delete_failed" }, 500);
  }
  return new Response(null, { status: 204 });
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
