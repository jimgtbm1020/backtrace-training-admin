import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function validRole(role: string) {
  return ["admin", "coordinator", "trainer", "viewer"].includes(role);
}

function generateTemporaryPassword() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = crypto.getRandomValues(new Uint8Array(18));
  return Array.from(bytes, (b) => chars[b % chars.length]).join("");
}


function escapeHtml(value:string){return value.replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]!));}

async function sendAccountCredentials(settings:{api_key:string;from_email:string;from_name:string},userId:string,email:string,fullName:string,password:string){
  const signInUrl="https://backtrace-training-admin.vercel.app/";
  const text=`Hello ${fullName},

Your Backtrace Training Administration account is ready.

Sign-in email: ${email}
Temporary password: ${password}
Sign in: ${signInUrl}

1. Sign in using your email and temporary password.
2. Enter the temporary password again on the Account Setup screen.
3. Enter and confirm your new password, then select Save password.

You must replace the temporary password before accessing the dashboard.
If you were not expecting this account, contact your administrator.`;
  const html=`<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Your Backtrace Training account</title></head><body style="margin:0;background:#edf3fa;font-family:Arial,sans-serif;color:#20334e"><div style="display:none;max-height:0;overflow:hidden">Your new account is ready. Sign in and choose your own password.</div><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td style="padding:24px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:auto;background:#fff;border:1px solid #dce4ed;border-radius:10px"><tr><td style="padding:28px"><h1 style="font-size:24px;line-height:1.3;margin:0 0 20px">Your Backtrace Training account</h1><p style="font-size:16px;line-height:1.5">Hello ${escapeHtml(fullName)},</p><p style="font-size:16px;line-height:1.5">Your Training Administration account is ready.</p><div style="padding:16px;background:#edf3fa;border-left:3px solid #c7a34b"><p style="margin:0 0 12px;font-size:16px"><strong>Sign-in email:</strong> ${escapeHtml(email)}</p><p style="margin:0;font-size:16px"><strong>Temporary password:</strong><br><span style="font-family:monospace;font-size:20px;overflow-wrap:anywhere">${escapeHtml(password)}</span></p></div><p style="margin:24px 0"><a href="${signInUrl}" style="display:inline-block;box-sizing:border-box;background:#254d7e;color:#fff;text-decoration:none;padding:14px 20px;border-radius:6px;font-size:16px;font-weight:bold">Sign in to Backtrace</a></p><ol style="font-size:16px;line-height:1.6;padding-left:22px"><li>Sign in with your email and temporary password.</li><li>Enter the temporary password again on Account Setup.</li><li>Enter and confirm your new password, then select <strong>Save password</strong>.</li></ol><p style="font-size:16px;line-height:1.5"><strong>You must replace the temporary password before accessing the dashboard.</strong></p><p style="font-size:14px;line-height:1.5">If you were not expecting this account, contact your administrator.</p><p style="font-size:14px;line-height:1.5">Sign-in address: <a href="${signInUrl}">${signInUrl}</a></p></td></tr></table></td></tr></table></body></html>`;
  const from=settings.from_name?`${settings.from_name} <${settings.from_email}>`:settings.from_email;
  for(let attempt=0;attempt<2;attempt++){
    try{
      const response=await fetch("https://api.resend.com/emails",{method:"POST",headers:{"Authorization":`Bearer ${settings.api_key}`,"Content-Type":"application/json","Idempotency-Key":`training-account/${userId}`},body:JSON.stringify({from,to:[email],subject:"Your Backtrace Training account and temporary password",html,text}),signal:AbortSignal.timeout(10000)});
      const result=await response.json().catch(()=>({}));
      if(response.ok&&typeof result.id==="string")return result.id;
      if(response.status<500&&response.status!==429)return null;
    }catch{}
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return json({ error: "Authentication required" }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await admin.auth.getUser(token);
    const actor = userData?.user;
    if (userError || !actor) return json({ error: "Invalid session" }, 401);

    const { data: actorProfile, error: profileError } = await admin
      .from("profiles")
      .select("id,email,role,active")
      .eq("id", actor.id)
      .single();

    const body = await req.json();
    const action = String(body?.action || "");

    if (action === "change_own_password") {
      if (profileError || !actorProfile?.active || !validRole(actorProfile.role)) return json({ error: "An active staff account is required" }, 403);
      const nextPassword = typeof body.new_password === "string" ? body.new_password : "";
      const currentPassword = typeof body.current_password === "string" ? body.current_password : "";
      if (nextPassword.length < 8 || nextPassword.length > 128) return json({ error: "Use between 8 and 128 characters for your new password." }, 400);
      const recovery = body.recovery === true;
      let recoverySession: string | undefined;
      if (recovery) {
        const { data: claimsData, error: claimsError } = await admin.auth.getClaims(token);
        const methods = claimsData?.claims?.amr as {method:string;timestamp:number}[] | undefined;
        recoverySession = claimsData?.claims?.session_id as string | undefined;
        const now = Math.floor(Date.now()/1000);
        if (claimsError || !recoverySession || actor.app_metadata?.password_recovery_completed_session === recoverySession || !methods?.some(m => (m.method === "otp" || m.method === "recovery") && Number.isFinite(m.timestamp) && m.timestamp <= now && now-m.timestamp <= 3600)) return json({ error: "Open a fresh password reset link from your email." }, 403);
      } else {
        if (!currentPassword || !actor.email) return json({ error: "Enter your current or temporary password." }, 400);
        if (nextPassword === currentPassword) return json({ error: "Choose a new password different from your temporary or current password." }, 400);
        const verification = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
        const { data: verified, error: verifyError } = await verification.auth.signInWithPassword({ email: actor.email, password: currentPassword });
        if (verifyError || verified.user?.id !== actor.id) return json({ error: "The current or temporary password is incorrect." }, 400);
        await verification.auth.signOut({ scope: "local" });
      }
      const { error: passwordError } = await admin.auth.admin.updateUserById(actor.id, {
        password: nextPassword,
        app_metadata: { ...actor.app_metadata, password_change_required: false, ...(recoverySession ? { password_recovery_completed_session: recoverySession } : {}) },
      });
      if (passwordError) return json({ error: passwordError.message }, 400);
      return json({ success: true });
    }

    if (actor.app_metadata?.password_change_required === true) return json({ error: "Replace your temporary password before managing users." }, 403);

    if (profileError || !actorProfile?.active || actorProfile.role !== "admin") {
      return json({ error: "Administrator access required" }, 403);
    }



    if (action === "create") {
      const email = String(body?.email || "").trim().toLowerCase();
      const fullName = String(body?.full_name || "").trim();
      const role = String(body?.role || "trainer");
      const suppliedPassword = String(body?.temporary_password || "");
      const temporaryPassword = suppliedPassword || generateTemporaryPassword();

      if (!email || !email.includes("@")) return json({ error: "A valid email address is required" }, 400);
      if (!fullName) return json({ error: "Full name is required" }, 400);
      if (!validRole(role)) return json({ error: "Invalid role" }, 400);
      if (temporaryPassword.length < 10) return json({ error: "Temporary password must be at least 10 characters" }, 400);

      const { data: emailSettings, error: emailSettingsError } = await admin.from("training_email_provider_settings").select("provider,enabled,api_key,from_email,from_name").eq("id",1).single();
      if(emailSettingsError||!emailSettings?.enabled||emailSettings.provider!=="resend"||!emailSettings.api_key||!emailSettings.from_email)return json({error:"Account email delivery is not configured or enabled. Configure Email Settings before creating users."},503);

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password: temporaryPassword,
        email_confirm: true,
        user_metadata: { full_name: fullName },
        app_metadata: { password_change_required: true },
      });
      if (createError || !created.user) return json({ error: createError?.message || "Unable to create user" }, 400);

      const newUserId = created.user.id;
      const { data: updatedProfile, error: updateProfileError } = await admin
        .from("profiles")
        .update({ full_name: fullName, role, active: true, updated_at: new Date().toISOString() })
        .eq("id", newUserId)
        .select("id")
        .maybeSingle();

      if (updateProfileError || !updatedProfile) {
        const { error: cleanupError } = await admin.auth.admin.deleteUser(newUserId);
        if (cleanupError) console.error("create user cleanup failed", cleanupError);
        return json({
          error: cleanupError
            ? "User setup failed and automatic cleanup was unsuccessful. Review the Auth user list before retrying."
            : (updateProfileError?.message || "User profile setup failed; the partial account was removed."),
        }, 500);
      }

      const { error: auditError } = await admin.from("user_management_activity").insert({
        actor_id: actor.id,
        target_user_id: newUserId,
        action: "user_created",
        details: {
          snapshot: { email, full_name: fullName, role, active: true },
          password: "[temporary password created; value not logged]",
        },
      });

      if (auditError) {
        console.error("create user audit failed", auditError);
        const { error: cleanupError } = await admin.auth.admin.deleteUser(newUserId);
        if (cleanupError) console.error("create user audit cleanup failed", cleanupError);
        return json({
          error: cleanupError
            ? "User creation could not be fully audited and automatic cleanup was unsuccessful. Review the Auth user list before retrying."
            : "User creation could not be fully audited, so the new account was removed. Please retry.",
        }, 500);
      }

      const emailId=await sendAccountCredentials(emailSettings,newUserId,email,fullName,temporaryPassword);
      const {error:emailAuditError}=await admin.from("user_management_activity").insert({actor_id:actor.id,target_user_id:newUserId,action:emailId?"user_credentials_emailed":"user_credentials_email_failed",details:{recipient:email,provider:"resend",provider_message_id:emailId}});
      if(emailAuditError)console.error("account_email_audit_failed");
      return json({
        success: true,
        user: { id: newUserId, email, full_name: fullName, role, active: true },
        temporary_password: temporaryPassword,
        email_sent: !!emailId,
        ...(emailId?{}:{warning:"User account was created, but the account email could not be confirmed. Do not create the user again. Provide the displayed temporary password directly to the user."}),
      });
    }

    if (action === "update") {
      const targetUserId = String(body?.target_user_id || "");
      const fullName = String(body?.full_name || "").trim();
      const role = String(body?.role || "trainer");
      const active = Boolean(body?.active);

      if (!targetUserId) return json({ error: "Target user is required" }, 400);
      if (!fullName) return json({ error: "Full name is required" }, 400);
      if (!validRole(role)) return json({ error: "Invalid role" }, 400);
      if (targetUserId === actor.id && (!active || role !== "admin")) {
        return json({ error: "You cannot deactivate or remove your own administrator access" }, 400);
      }

      const { data: oldProfile, error: oldError } = await admin
        .from("profiles")
        .select("email,full_name,role,active")
        .eq("id", targetUserId)
        .single();
      if (oldError || !oldProfile) return json({ error: "User not found" }, 404);

      const { error: authUpdateError } = await admin.auth.admin.updateUserById(targetUserId, {
        user_metadata: { full_name: fullName },
      });
      if (authUpdateError) return json({ error: authUpdateError.message }, 400);

      const { error: updateError } = await admin
        .from("profiles")
        .update({ full_name: fullName, role, active, updated_at: new Date().toISOString() })
        .eq("id", targetUserId);

      if (updateError) {
        const { error: rollbackAuthError } = await admin.auth.admin.updateUserById(targetUserId, {
          user_metadata: { full_name: oldProfile.full_name || "" },
        });
        if (rollbackAuthError) console.error("update auth rollback failed", rollbackAuthError);
        return json({
          error: rollbackAuthError
            ? "User profile update failed and Auth metadata rollback was unsuccessful. Review this user before retrying."
            : updateError.message,
        }, 500);
      }

      const changes: Record<string, unknown> = {};
      if (oldProfile.full_name !== fullName) changes.full_name = { from: oldProfile.full_name, to: fullName };
      if (oldProfile.role !== role) changes.role = { from: oldProfile.role, to: role };
      if (oldProfile.active !== active) changes.active = { from: oldProfile.active, to: active };

      if (Object.keys(changes).length) {
        const { error: auditError } = await admin.from("user_management_activity").insert({
          actor_id: actor.id,
          target_user_id: targetUserId,
          action: "user_updated",
          details: { changes },
        });

        if (auditError) {
          console.error("update user audit failed", auditError);
          const { error: profileRollbackError } = await admin
            .from("profiles")
            .update({
              full_name: oldProfile.full_name,
              role: oldProfile.role,
              active: oldProfile.active,
              updated_at: new Date().toISOString(),
            })
            .eq("id", targetUserId);
          const { error: authRollbackError } = await admin.auth.admin.updateUserById(targetUserId, {
            user_metadata: { full_name: oldProfile.full_name || "" },
          });
          if (profileRollbackError) console.error("update profile audit rollback failed", profileRollbackError);
          if (authRollbackError) console.error("update auth audit rollback failed", authRollbackError);
          return json({
            error: profileRollbackError || authRollbackError
              ? "User update could not be audited and automatic rollback was incomplete. Review this user before retrying."
              : "User update could not be audited, so the changes were rolled back. Please retry.",
          }, 500);
        }
      }

      return json({ success: true });
    }

    if (action === "reset_password") {
      const targetUserId = String(body?.target_user_id || "");
      const suppliedPassword = String(body?.temporary_password || "");
      const temporaryPassword = suppliedPassword || generateTemporaryPassword();
      if (!targetUserId) return json({ error: "Target user is required" }, 400);
      if (temporaryPassword.length < 10) return json({ error: "Temporary password must be at least 10 characters" }, 400);

      const { data: targetAuth, error: targetError } = await admin.auth.admin.getUserById(targetUserId);
      if (targetError || !targetAuth.user) return json({ error: "User not found" }, 404);
      const { error: resetError } = await admin.auth.admin.updateUserById(targetUserId, { password: temporaryPassword, app_metadata: { ...targetAuth.user.app_metadata, password_change_required: true } });
      if (resetError) return json({ error: resetError.message }, 400);

      const { error: auditError } = await admin.from("user_management_activity").insert({
        actor_id: actor.id,
        target_user_id: targetUserId,
        action: "password_reset",
        details: {
          changes: {
            password: { from: "[protected]", to: "[reset]" },
          },
        },
      });
      if (auditError) {
        console.error("password reset audit failed", auditError);
        return json({ success: true, temporary_password: temporaryPassword, warning: "Password was reset, but the audit event could not be recorded." });
      }

      return json({ success: true, temporary_password: temporaryPassword });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (error) {
    console.error("training_user_management_failed");
    return json({ error: "Unable to complete the account request. Please retry." }, 500);
  }
});
