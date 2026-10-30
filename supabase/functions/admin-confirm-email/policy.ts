export function isActiveAdmin(profile: {
  role?: unknown;
  is_active?: unknown;
} | null): boolean {
  return profile?.role === "admin" && profile.is_active === true;
}

export function isStaffProfile(profile: { role?: unknown } | null): boolean {
  return profile?.role === "staff";
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}
