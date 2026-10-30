import { isActiveAdmin, isStaffProfile, isUuid } from "./policy.ts";

Deno.test("only an active admin profile passes the server guard", () => {
  if (!isActiveAdmin({ role: "admin", is_active: true })) {
    throw new Error("active admin was denied");
  }
  if (isActiveAdmin({ role: "admin", is_active: false })) {
    throw new Error("inactive admin was allowed");
  }
  if (isActiveAdmin({ role: "staff", is_active: true })) {
    throw new Error("staff was allowed");
  }
  if (isActiveAdmin(null)) throw new Error("missing profile was allowed");
});

Deno.test("email confirmation target must be a staff profile", () => {
  if (!isStaffProfile({ role: "staff" })) {
    throw new Error("staff profile was rejected");
  }
  if (isStaffProfile({ role: "admin" })) {
    throw new Error("admin profile was accepted as a target");
  }
  if (isStaffProfile(null)) throw new Error("missing profile was accepted");
});

Deno.test("target user ID must be a valid UUID", () => {
  if (!isUuid("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")) {
    throw new Error("valid UUID was rejected");
  }
  if (isUuid("not-a-uuid")) throw new Error("invalid UUID was accepted");
  if (isUuid(42)) throw new Error("non-string UUID was accepted");
});
