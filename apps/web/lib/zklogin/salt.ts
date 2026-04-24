const SALT_URL = process.env.NEXT_PUBLIC_SALT_URL!;

export async function fetchSalt(jwt: string): Promise<string> {
  const attempt = async () => {
    const r = await fetch(SALT_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: jwt }),
    });
    if (!r.ok) throw new Error(`salt ${r.status}`);
    const { salt } = (await r.json()) as { salt: string };
    return salt;
  };
  try { return await attempt(); }
  catch { return await attempt(); }  // one retry
}
