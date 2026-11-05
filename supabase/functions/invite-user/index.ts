import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  let anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  let serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  try {
    const publishableKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
    if (publishableKeys.default) anonKey = publishableKeys.default;
  } catch (_) {}

  try {
    const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
    if (secretKeys.default) serviceRoleKey = secretKeys.default;
  } catch (_) {}

  const siteUrl = Deno.env.get('SITE_URL') ?? 'https://moonwiraja.github.io/KPI/';

  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed.' });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, { error: 'Invitation service is not configured.' });
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return jsonResponse(401, { error: 'Sign in is required.' });
  }

  let payload: { email?: unknown; display_name?: unknown; role?: unknown; staff_id?: unknown };
  try {
    payload = await request.json();
  } catch {
    return jsonResponse(400, { error: 'Invalid request body.' });
  }

  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
  const displayName = typeof payload.display_name === 'string' ? payload.display_name.trim() : '';
  const role = payload.role;
  const staffId = typeof payload.staff_id === 'string' ? payload.staff_id : null;

  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(400, { error: 'Enter a valid email address.' });
  }
  if (displayName.length < 1 || displayName.length > 160) {
    return jsonResponse(400, { error: 'Name must contain 1–160 characters.' });
  }
  if (role !== 'ceo' && role !== 'admin') {
    return jsonResponse(400, { error: 'Choose an allowed role.' });
  }

  const caller = createClient(supabaseUrl, anonKey || serviceRoleKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: 'Your session is invalid. Sign in again.' });
  }

  const { data: canInvite, error: permissionError } = await caller.rpc('has_permission', {
    permission_key: 'users.invite',
  });
  if (permissionError || canInvite !== true) {
    return jsonResponse(403, { error: 'You do not have permission to invite users.' });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: siteUrl,
    data: { display_name: displayName },
  });
  if (inviteError || !invited.user) {
    return jsonResponse(400, { error: inviteError?.message ?? 'Invitation could not be sent. Check SMTP configuration.' });
  }

  const { error: profileError } = await admin.from('profiles').insert({
    user_id: invited.user.id,
    email,
    display_name: displayName,
    role,
    staff_id: null,
    is_active: true,
    must_set_password: false,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    if (profileError.code === '23505') return jsonResponse(409, { error: 'That email or role is already in use.' });
    return jsonResponse(500, { error: 'Invitation setup failed. No active account was created.' });
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
    return jsonResponse(500, { error: 'Invitation could not be recorded. The invite was cancelled.' });
  }

  return jsonResponse(201, { invited: true });
});
