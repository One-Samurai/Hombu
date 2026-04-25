const SALT_URL = process.env.NEXT_PUBLIC_SALT_URL;

export async function fetchSalt(jwt: string): Promise<string> {
  if (!SALT_URL) throw new Error("NEXT_PUBLIC_SALT_URL not set");
  const attempt = async () => {
    const r = await fetch(SALT_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: jwt }),
    }).catch((e) => { throw new Error(`salt fetch failed (${SALT_URL}): ${e.message}`); });
    if (!r.ok) throw new Error(`salt ${r.status} from ${SALT_URL}: ${await r.text().catch(() => "")}`);
    const { salt } = (await r.json()) as { salt: string };
    return salt;
  };
  try { return await attempt(); }
  catch (e) { console.warn("[salt] retry after", e); return await attempt(); }
}
