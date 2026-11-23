import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function readSupabaseKey(jsonEnvName: string, legacyEnvName: string): string {
  const raw = Deno.env.get(jsonEnvName);
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object') {
        const preferred = (parsed as Record<string, unknown>).default;
        if (typeof preferred === 'string' && preferred.length > 0) return preferred;
        const first = Object.values(parsed).find((value) => typeof value === 'string' && value.length > 0);
        if (typeof first === 'string') return first;
      }
    } catch {
      // Some self-hosted/older projects may expose a plain key string.
      if (raw.startsWith('sb_')) return raw;
    }
  }
  const legacy = Deno.env.get(legacyEnvName);
  if (legacy) return legacy;
  throw new Error(`Secret Supabase ${jsonEnvName} tidak ditemukan pada runtime Edge Function.`);
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = ''; for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
function pemToBytes(pem: string): Uint8Array {
  const content = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const raw = atob(content); return Uint8Array.from(raw, c => c.charCodeAt(0));
}
async function getFcmAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey('pkcs8', pemToBytes(serviceAccount.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) throw new Error('Gagal memperoleh access token FCM.');
  return data.access_token;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    if (!supabaseUrl) throw new Error('SUPABASE_URL tidak ditemukan pada runtime Edge Function.');
    const publishableKey = readSupabaseKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
    const secretKey = readSupabaseKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
    const caller = createClient(supabaseUrl, publishableKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userError } = await caller.auth.getUser();
    if (userError || !user) throw new Error('Sesi login tidak valid.');
    const admin = createClient(supabaseUrl, secretKey);
    const { data: profile } = await admin.from('profiles').select('role,is_active,full_name').eq('id', user.id).single();
    if (!profile || profile.role !== 'admin' || !profile.is_active) throw new Error('Akses admin diperlukan.');

    const body = await req.json();
    const title = String(body.title ?? '').trim();
    const message = String(body.body ?? '').trim();
    const target = String(body.target ?? 'all');
    if (!title || !message) throw new Error('Judul dan isi notifikasi wajib diisi.');
    if (target !== 'all' && !/^[0-9a-f-]{36}$/i.test(target)) throw new Error('Target penerima tidak valid.');

    const { data: notification, error: insertError } = await admin.from('notifications').insert({
      title, body: message, type: 'general', target: target === 'all' ? 'all' : 'user',
      target_user_id: target === 'all' ? null : target, created_by: user.id,
    }).select('id').single();
    if (insertError) throw insertError;

    let tokenQuery = admin.from('fcm_tokens').select('token');
    if (target !== 'all') tokenQuery = tokenQuery.eq('user_id', target);
    const { data: tokenRows, error: tokenError } = await tokenQuery;
    if (tokenError) throw tokenError;
    const tokens = [...new Set((tokenRows ?? []).map((r: any) => r.token).filter(Boolean))];
    if (!tokens.length) return new Response(JSON.stringify({ success: true, message: 'Notifikasi tersimpan, tetapi belum ada device penerima yang terdaftar.', sent: 0, failed: 0, notification_id: notification.id }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountRaw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON belum diatur pada Edge Function Secrets.');
    const serviceAccount = JSON.parse(serviceAccountRaw);
    const accessToken = await getFcmAccessToken(serviceAccount);
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? serviceAccount.project_id;
    let sent = 0, failed = 0;
    for (const token of tokens) {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
        body: JSON.stringify({ message: {
          token, notification: { title, body: message },
          android: { priority: 'high', notification: { channel_id: 'elora_notifications', sound: 'default' } },
          data: { title, body: message, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
        } }),
      });
      if (response.ok) sent++; else failed++;
    }
    return new Response(JSON.stringify({ success: true, message: `Notifikasi dikirim. Berhasil: ${sent}, gagal: ${failed}.`, sent, failed, notification_id: notification.id }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ success: false, message: error instanceof Error ? error.message : 'Gagal mengirim notifikasi.' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
