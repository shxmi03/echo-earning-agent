// App Store subscriptions (S05). One function, two routes:
//
//   POST /functions/v1/appstore/sync           from the app, signed in, right after a purchase
//        { signedTransaction }                  or restore: StoreKit 2's jwsRepresentation
//   POST /functions/v1/appstore/notifications  from Apple: App Store Server Notifications v2
//        { signedPayload }                      (set this URL in App Store Connect)
//
// Nothing is trusted until Apple's signature chain checks out against Apple's root
// certificates (SignedDataVerifier). Subscription state lives in `subscriptions`, written
// only here with the service role; the app reads it under RLS.
//
// Secrets (supabase secrets set): APPLE_BUNDLE_ID (default app.handspan.ios),
// APPLE_APP_ID (the numeric App Store id; needed for Production only).
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
} from "npm:@apple/app-store-server-library@1";

const BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID") ?? "app.handspan.ios";
const APP_ID = Number(Deno.env.get("APPLE_APP_ID") ?? "") || undefined;

const PLANS: Record<string, { plan: string; period: string; maxProfiles: number }> = {
  "app.handspan.solo.monthly": { plan: "individual", period: "month", maxProfiles: 1 },
  "app.handspan.solo.yearly": { plan: "individual", period: "year", maxProfiles: 1 },
  "app.handspan.household.monthly": { plan: "family", period: "month", maxProfiles: 5 },
  "app.handspan.household.yearly": { plan: "family", period: "year", maxProfiles: 5 },
};

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Apple's root certificates, fetched once per cold start from Apple.
let roots: Uint8Array[] | null = null;
async function appleRoots(): Promise<Uint8Array[]> {
  if (roots) return roots;
  const urls = [
    "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
  ];
  roots = await Promise.all(urls.map(async (u) => new Uint8Array(await (await fetch(u)).arrayBuffer())));
  return roots;
}

/** Reads a JWS payload without trusting it: only to pick the verifier's environment. */
function peek(jws: string): Record<string, unknown> {
  const part = jws.split(".")[1] ?? "";
  const json = atob(part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "="));
  return JSON.parse(json);
}

async function verifier(environment: unknown): Promise<SignedDataVerifier> {
  // Xcode's local StoreKit testing signs with a local key: never accepted here.
  if (environment === "Sandbox") {
    return new SignedDataVerifier(await appleRoots() as never, true, Environment.SANDBOX, BUNDLE_ID);
  }
  if (environment === "Production" && APP_ID) {
    return new SignedDataVerifier(await appleRoots() as never, true, Environment.PRODUCTION, BUNDLE_ID, APP_ID);
  }
  throw new HttpError(422, "unsupported_environment");
}

class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

type Status = "trial" | "active" | "grace" | "billing_retry" | "expired" | "revoked";

function statusOf(t: JWSTransactionDecodedPayload, override?: Status): Status {
  if (t.revocationDate) return "revoked";
  if (override) return override;
  if (t.expiresDate && t.expiresDate <= Date.now()) return "expired";
  if (t.offerType === 1) return "trial"; // introductory offer: the free week
  return "active";
}

async function upsert(t: JWSTransactionDecodedPayload, accountId: string, opts: { status?: Status; autoRenew?: boolean } = {}) {
  const plan = PLANS[t.productId ?? ""];
  if (!plan || !t.originalTransactionId) throw new HttpError(422, "unknown_product");
  const row: Record<string, unknown> = {
    account_id: accountId,
    original_transaction_id: t.originalTransactionId,
    product_id: t.productId,
    plan: plan.plan,
    period: plan.period,
    status: statusOf(t, opts.status),
    max_profiles: plan.maxProfiles,
    expires_at: t.expiresDate ? new Date(t.expiresDate).toISOString() : null,
  };
  if (opts.autoRenew !== undefined) row.auto_renew = opts.autoRenew;
  const { error } = await admin.from("subscriptions").upsert(row, { onConflict: "original_transaction_id" });
  if (error) throw new HttpError(500, "write_failed");
  return row;
}

async function sync(req: Request): Promise<Response> {
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = await admin.auth.getUser(jwt);
  const user = auth?.user;
  if (!user) throw new HttpError(401, "not_signed_in");

  const { signedTransaction } = await req.json().catch(() => ({}));
  if (typeof signedTransaction !== "string" || signedTransaction.length > 20_000) {
    throw new HttpError(400, "bad_request");
  }
  const t = await (await verifier(peek(signedTransaction).environment))
    .verifyAndDecodeTransaction(signedTransaction)
    .catch(() => { throw new HttpError(422, "invalid_signature"); });

  // The app sets appAccountToken to the account id at purchase. A receipt bought by one
  // account can't be claimed by another; one already on file stays with its account.
  if (t.appAccountToken && t.appAccountToken.toLowerCase() !== user.id) {
    throw new HttpError(403, "other_account");
  }
  const { data: existing } = await admin.from("subscriptions")
    .select("account_id").eq("original_transaction_id", t.originalTransactionId!).maybeSingle();
  if (existing && existing.account_id !== user.id) throw new HttpError(403, "other_account");

  const row = await upsert(t, user.id);
  return json({ plan: row.plan, status: row.status, expires_at: row.expires_at }, 200);
}

async function notification(req: Request): Promise<Response> {
  const { signedPayload } = await req.json().catch(() => ({}));
  if (typeof signedPayload !== "string") throw new HttpError(400, "bad_request");
  const env = (peek(signedPayload).data as Record<string, unknown> | undefined)?.environment;
  const v = await verifier(env);
  const n = await v.verifyAndDecodeNotification(signedPayload)
    .catch(() => { throw new HttpError(422, "invalid_signature"); });

  // Apple retries until it gets a 200: each notification is handled once.
  const { error: dup } = await admin.from("app_store_events").insert({
    notification_uuid: n.notificationUUID,
    notification_type: n.notificationType,
    subtype: n.subtype ?? null,
    signed_date: new Date(n.signedDate ?? Date.now()).toISOString(),
  });
  if (dup) return json({ ok: true, duplicate: true }, 200);

  const signedTx = n.data?.signedTransactionInfo;
  if (signedTx) {
    const t = await v.verifyAndDecodeTransaction(signedTx);
    const renewal = n.data?.signedRenewalInfo ? await v.verifyAndDecodeRenewalInfo(n.data.signedRenewalInfo) : null;
    await admin.from("app_store_events")
      .update({ original_transaction_id: t.originalTransactionId })
      .eq("notification_uuid", n.notificationUUID);

    // Which account: the one already on file, else the purchase's appAccountToken.
    const { data: existing } = await admin.from("subscriptions")
      .select("account_id").eq("original_transaction_id", t.originalTransactionId!).maybeSingle();
    const accountId = existing?.account_id ?? t.appAccountToken?.toLowerCase();
    if (accountId) {
      let status: Status | undefined;
      if (n.notificationType === "DID_FAIL_TO_RENEW") status = n.subtype === "GRACE_PERIOD" ? "grace" : "billing_retry";
      if (n.notificationType === "EXPIRED" || n.notificationType === "GRACE_PERIOD_EXPIRED") status = "expired";
      if (n.notificationType === "REFUND" || n.notificationType === "REVOKE") status = "revoked";
      const autoRenew = renewal ? renewal.autoRenewStatus === 1 : undefined;
      try {
        await upsert(t, accountId, { status, autoRenew });
      } catch (e) {
        // An account deleted since the purchase: nothing to update.
        if (!(e instanceof HttpError && e.status === 500)) throw e;
      }
    }
  }
  await admin.from("app_store_events").update({ processed_at: new Date().toISOString() })
    .eq("notification_uuid", n.notificationUUID);
  return json({ ok: true }, 200);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const path = new URL(req.url).pathname;
  try {
    if (path.endsWith("/sync")) return await sync(req);
    if (path.endsWith("/notifications")) return await notification(req);
    return json({ error: "not_found" }, 404);
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error("appstore failed", (e as Error).message); // no user data in logs
    return json({ error: "server_error" }, 500);
  }
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
