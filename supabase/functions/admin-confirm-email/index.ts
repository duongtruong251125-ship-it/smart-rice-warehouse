import { withSupabase } from "npm:@supabase/server@1";
import { isActiveAdmin, isStaffProfile, isUuid } from "./policy.ts";

const handler = withSupabase({ auth: "user" }, async (request, context) => {
  if (request.method !== "POST") {
    return Response.json({ error: "method_not_allowed" }, { status: 405 });
  }

  const actorId = context.userClaims?.sub;
  if (typeof actorId !== "string") {
    return Response.json({ error: "unauthenticated" }, { status: 401 });
  }

  const { data: actorProfile, error: profileError } = await context.supabase
    .from("profiles")
    .select("role,is_active")
    .eq("id", actorId)
    .maybeSingle();
  if (profileError) {
    console.error("admin_confirm_email_profile_check_failed", {
      actorId,
      code: profileError.code,
    });
    return Response.json({ error: "authorization_check_failed" }, {
      status: 500,
    });
  }
  if (!isActiveAdmin(actorProfile)) {
    return Response.json({ error: "admin_required" }, { status: 403 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }
  const targetUserId =
    typeof body === "object" && body !== null && "userId" in body
      ? body.userId
      : null;
  if (!isUuid(targetUserId)) {
    return Response.json({ error: "invalid_user_id" }, { status: 400 });
  }
  if (targetUserId === actorId) {
    return Response.json({ error: "cannot_confirm_self" }, { status: 409 });
  }

  const { data: targetProfile, error: targetProfileError } = await context
    .supabase
    .from("profiles")
    .select("role")
    .eq("id", targetUserId)
    .maybeSingle();
  if (targetProfileError) {
    console.error("admin_confirm_email_target_profile_check_failed", {
      actorId,
      targetUserId,
      code: targetProfileError.code,
    });
    return Response.json({ error: "target_profile_check_failed" }, {
      status: 500,
    });
  }
  if (!targetProfile) {
    return Response.json({ error: "target_user_not_found" }, { status: 404 });
  }
  if (!isStaffProfile(targetProfile)) {
    return Response.json({ error: "only_staff_email_can_be_confirmed" }, {
      status: 400,
    });
  }

  const { data: targetResult, error: targetError } = await context.supabaseAdmin
    .auth.admin.getUserById(targetUserId);
  if (targetError || !targetResult.user) {
    console.warn("admin_confirm_email_target_lookup_failed", {
      actorId,
      targetUserId,
    });
    return Response.json({ error: "target_user_not_found" }, { status: 404 });
  }
  if (!targetResult.user.email) {
    return Response.json({ error: "target_email_missing" }, { status: 400 });
  }
  if (targetResult.user.email_confirmed_at) {
    console.info("admin_confirm_email_already_confirmed", {
      actorId,
      targetUserId,
    });
    return Response.json({ alreadyConfirmed: true });
  }

  const { data: updatedResult, error: updateError } = await context.supabaseAdmin
    .auth.admin.updateUserById(targetUserId, { email_confirm: true });
  if (updateError || !updatedResult.user) {
    console.error("admin_confirm_email_update_failed", {
      actorId,
      targetUserId,
      message: updateError?.message,
    });
    return Response.json({ error: "email_confirmation_failed" }, {
      status: 502,
    });
  }

  console.info("admin_confirm_email_succeeded", { actorId, targetUserId });
  return Response.json({ alreadyConfirmed: false });
});

Deno.serve(handler);
