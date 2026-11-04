import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const publishableKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
const anonKey = publishableKeys.default ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceRoleKey = secretKeys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const siteUrl = Deno.env.get('SITE_URL') ?? '';
const allowedOrigins = new Set([
  'https://moonwiraja.github.io',
  'http://localhost:3000',
  'http://localhost:5000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5000',
  'http://127.0.0.1:8080',
  ...(Deno.env.get('CORS_ORIGINS') ?? siteUrl)
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
]);

function response(status: number, body: Record<string, unknown>, origin: string | null) {
  const isAllowed = origin && (allowedOrigins.has(origin) || origin.endsWith('.github.io') || origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1'));
  const corsOrigin = isAllowed ? origin : '*';
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': corsOrigin,
      'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
    },
  });
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get('origin');
  if (request.method === 'OPTIONS') {
    return response(204, {}, origin);
  }
  if (request.method !== 'POST') return response(405, { error: 'Method not allowed.' }, origin);
  if (!origin || !allowedOrigins.has(origin)) return response(403, { error: 'Origin is not allowed.' }, origin);

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !siteUrl) {
    return response(500, { error: 'Invitation service is not configured.' }, origin);
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return response(401, { error: 'Sign in is required.' }, origin);

  let payload: { email?: unknown; display_name?: unknown; role?: unknown; staff_id?: unknown };
  try {
    payload = await request.json();
  } catch {
    return response(400, { error: 'Invalid request body.' }, origin);
  }

  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
  const displayName = typeof payload.display_name === 'string' ? payload.display_name.trim() : '';
  const role = payload.role;
  const staffId = typeof payload.staff_id === 'string' ? payload.staff_id : null;
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return response(400, { error: 'Enter a valid email address.' }, origin);
  }
  if (displayName.length < 1 || displayName.length > 160) {
    return response(400, { error: 'Name must contain 1–160 characters.' }, origin);
  }
  if (role !== 'ceo' && role !== 'staff') return response(400, { error: 'Choose an allowed role.' }, origin);
  if ((role === 'staff' && !staffId) || (role === 'ceo' && staffId)) {
    return response(400, { error: 'A staff account must link to one staff record; CEO accounts cannot.' }, origin);
  }
  if (staffId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(staffId)) {
    return response(400, { error: 'Invalid staff record.' }, origin);
  }

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) return response(401, { error: 'Your session is invalid. Sign in again.' }, origin);

  const { data: canInvite, error: permissionError } = await caller.rpc('has_permission', {
    permission_key: 'users.invite',
  });
  if (permissionError || canInvite !== true) return response(403, { error: 'You do not have permission to invite users.' }, origin);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (staffId) {
    const { data: linkedProfile, error: linkError } = await admin
      .from('profiles')
      .select('user_id')
      .eq('staff_id', staffId)
      .maybeSingle();
    if (linkError) return response(500, { error: 'Could not verify the staff account link.' }, origin);
    if (linkedProfile) return response(409, { error: 'This staff record already has a login.' }, origin);
    const { data: staffRecord, error: staffError } = await admin
      .from('staff')
      .select('id')
      .eq('id', staffId)
      .eq('is_archived', false)
      .maybeSingle();
    if (staffError || !staffRecord) return response(404, { error: 'Active staff record was not found.' }, origin);
  }

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: siteUrl,
    data: { display_name: displayName },
  });
  if (inviteError || !invited.user) {
    return response(400, { error: 'Invitation could not be sent. Check the email and SMTP configuration.' }, origin);
  }

  const { error: profileError } = await admin.from('profiles').insert({
    user_id: invited.user.id,
    email,
    display_name: displayName,
    role,
    staff_id: staffId,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    if (profileError.code === '23505') return response(409, { error: 'That email, role or staff link is already in use.' }, origin);
    return response(500, { error: 'Invitation setup failed. No active account was created.' }, origin);
  }

  const { error: auditError } = await admin.from('audit_events').insert({
    actor_id: userData.user.id,
    action: 'user.invite',
    target_type: 'profile',
    target_id: invited.user.id,
    metadata: { role },
  });
  if (auditError) {
    console.error('Invite audit write failed', auditError.code);
    await admin.from('profiles').delete().eq('user_id', invited.user.id);
    await admin.auth.admin.deleteUser(invited.user.id);
    return response(500, { error: 'Invitation could not be recorded. The invite was cancelled.' }, origin);
  }

  return response(201, { invited: true }, origin);
});
