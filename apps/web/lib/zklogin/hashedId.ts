export async function hashedIdFromJwtSub(sub: string, salt: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(`${sub}|${salt}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return new Uint8Array(digest);
}
