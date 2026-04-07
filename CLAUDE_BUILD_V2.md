# CLAUDE_BUILD_V2.md — ROKOR Order Hub Build Specification

## Overview

The **ROKOR Order Hub** is a customer-facing approval tool linked from the existing Sales Job Record in TeamwearOS. It allows a customer (club manager) to review and approve design deliverables at 3 stages before production begins.

**No kit personalisation. No quoting. No payment.** Payment is handled separately via Shopify.

---

## Confirmed Scope

### What it does
1. Admin generates a unique hub link from a Sales Job Record
2. Approved design files from the DTR automatically feed into the hub when stages are approved
3. Customer visits the link and approves (or declines with feedback) each file at each stage
4. Admin sees approval status in real time from the Job Record

### What it does NOT do
- No player name/number/size collection
- No payment or quoting
- No Shopify integration in this flow

---

## Flow

### Admin Flow (inside `index.html` → Job Record)

1. Admin opens a Sales Job Record that has a linked design task
2. **Order Hub panel** is visible at the bottom of the Job Record
3. Admin clicks **"Generate Hub Link"**
   - Creates a `kit_orders` row with a unique UUID token
   - Sets `hub_url` to `https://<domain>/orders/hub.html?token=<token>`
   - **Backfills** any already-approved DTR stages (copies approved `stage_uploads` files into `kit_stage_files`)
   - Displays the link with a copy-to-clipboard button
4. **Stage 1 auto-unlocks** when admin approves DTR Stage 1 (Concepts) via `approveStage()`
   - Hook fires → copies approved `stage_uploads` files into `kit_stage_files` (stage_number=1)
   - Sets `kit_orders.stage_1_unlocked = true`
5. **Stage 2 auto-unlocks** when admin approves DTR Stage 2 (Full Range) — same mechanism
6. **Stage 3 (Pre-Production):** Admin manually uploads files via the hub panel
   - Files go into `design-uploads` Supabase Storage bucket
   - Records created in `kit_stage_files` (stage_number=3, source='manual')
   - Sets `kit_orders.stage_3_unlocked = true`

### Customer Flow (`orders/hub.html?token=<token>`)

1. Page loads → reads `token` from URL query param
2. Fetches `kit_orders` by token → gets order + stage unlock flags
3. Shows only unlocked stages
4. Each stage shows file cards with image previews
5. Customer can:
   - **Approve** a file (green tick) → writes `kit_file_reviews` row with `decision='approved'`
   - **Decline** a file (red cross + feedback modal) → writes row with `decision='declined'` + `feedback` text
   - Change their decision (re-clicking overwrites previous review)
6. When all files in a stage are approved → stage shows as complete (green banner)
7. No authentication required — URL token is the access control

---

## Directory Structure

```
TeamwearOS/
├── index.html                  # Main app (Job Record hub panel + DTR hook added here)
├── orders/
│   └── hub.html                # Customer-facing Order Hub
├── migrations/
│   └── 035_kit_order_hub.sql   # New migration for 3 tables
├── CLAUDE.md
└── CLAUDE_BUILD_V2.md
```

---

## Supabase Schema

### Migration: `migrations/035_kit_order_hub.sql`

```sql
-- ============================================================
-- kit_orders: one per job, holds the unique token + stage flags
-- ============================================================
CREATE TABLE IF NOT EXISTS kit_orders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id      uuid REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
  brand_id    uuid REFERENCES brands(id) ON DELETE SET NULL,
  club_id     uuid REFERENCES clubs(id) ON DELETE SET NULL,
  token       text UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
  status      text NOT NULL DEFAULT 'active',  -- active | completed
  hub_url     text,
  stage_1_unlocked  bool NOT NULL DEFAULT false,
  stage_2_unlocked  bool NOT NULL DEFAULT false,
  stage_3_unlocked  bool NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

-- ============================================================
-- kit_stage_files: all files per stage per order
-- ============================================================
CREATE TABLE IF NOT EXISTS kit_stage_files (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id          uuid REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
  stage_number      int NOT NULL CHECK (stage_number IN (1, 2, 3)),
  file_url          text NOT NULL,
  file_name         text,
  file_type         text,
  source            text NOT NULL DEFAULT 'manual',  -- 'design_task' | 'manual'
  source_upload_id  uuid,  -- nullable FK to stage_uploads (stages 1 & 2 only)
  uploaded_at       timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- kit_file_reviews: customer approval decisions per file
-- ============================================================
CREATE TABLE IF NOT EXISTS kit_file_reviews (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id       uuid REFERENCES kit_stage_files(id) ON DELETE CASCADE NOT NULL,
  order_id      uuid REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
  stage_number  int NOT NULL,
  decision      text NOT NULL CHECK (decision IN ('approved', 'declined')),
  feedback      text,
  reviewed_at   timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RLS Policies
-- ============================================================

-- kit_orders: authenticated users can read/write (admin use only via index.html)
ALTER TABLE kit_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kit_orders_auth_all" ON kit_orders
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
-- Public read by token (for hub.html — no auth)
CREATE POLICY "kit_orders_public_read_by_token" ON kit_orders
  FOR SELECT TO anon USING (true);

-- kit_stage_files: public read (hub needs to load files without auth)
ALTER TABLE kit_stage_files ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kit_stage_files_auth_all" ON kit_stage_files
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "kit_stage_files_public_read" ON kit_stage_files
  FOR SELECT TO anon USING (true);

-- kit_file_reviews: public insert + read (customer submits without auth)
ALTER TABLE kit_file_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kit_file_reviews_auth_all" ON kit_file_reviews
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "kit_file_reviews_public_read" ON kit_file_reviews
  FOR SELECT TO anon USING (true);
CREATE POLICY "kit_file_reviews_public_insert" ON kit_file_reviews
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "kit_file_reviews_public_update" ON kit_file_reviews
  FOR UPDATE TO anon USING (true) WITH CHECK (true);
```

---

## Storage

Reuse the existing **`design-uploads`** bucket for Stage 3 (Pre-Production) uploads.

**Upload path:** `{brandId}/kit-hub/{orderId}/preprod-{timestamp}-{filename}`

---

## DTR Integration — `approveStage()` Hook

The existing `approveStage(stageId, stageNum)` function in `index.html` is extended.  
Find the function and add a call to `maybeUnlockHubStage()` **after** the stage status update succeeds:

```js
// Add this function near the other kit hub functions:
async function maybeUnlockHubStage(taskId, stageNum) {
  // Only handles stages 1 and 2 (stage 3 is manual)
  if (stageNum > 2) return;

  // 1. Get the job_id from the design task
  const { data: task, error: taskErr } = await supabase
    .from('design_tasks').select('job_id').eq('id', taskId).single();
  if (taskErr || !task?.job_id) return;

  // 2. Check if a hub record exists for this job
  const { data: kitOrder } = await supabase
    .from('kit_orders').select('id')
    .eq('job_id', task.job_id).maybeSingle();
  if (!kitOrder) return;  // No hub generated yet — skip silently

  // 3. Get the design_stages IDs for this stage number and task
  const { data: stages } = await supabase
    .from('design_stages').select('id')
    .eq('task_id', taskId).eq('stage_number', stageNum);
  if (!stages?.length) return;
  const stageIds = stages.map(s => s.id);

  // 4. Get approved stage_uploads for those stages
  const { data: uploads } = await supabase
    .from('stage_uploads').select('id, file_url, file_name, file_type')
    .in('stage_id', stageIds).eq('status', 'approved');
  if (!uploads?.length) return;

  // 5. Insert into kit_stage_files (skip any already inserted)
  const { data: existing } = await supabase
    .from('kit_stage_files').select('source_upload_id')
    .eq('order_id', kitOrder.id).eq('stage_number', stageNum);
  const existingIds = new Set((existing || []).map(e => e.source_upload_id));

  const newRows = uploads
    .filter(u => !existingIds.has(u.id))
    .map(u => ({
      order_id: kitOrder.id,
      stage_number: stageNum,
      file_url: u.file_url,
      file_name: u.file_name,
      file_type: u.file_type,
      source: 'design_task',
      source_upload_id: u.id
    }));

  if (newRows.length) {
    await supabase.from('kit_stage_files').insert(newRows);
  }

  // 6. Mark stage as unlocked on the kit_order
  await supabase.from('kit_orders')
    .update({ [`stage_${stageNum}_unlocked`]: true })
    .eq('id', kitOrder.id);
}

// Inside approveStage(), after the stage status update succeeds, add:
// await maybeUnlockHubStage(stage.task_id, stageNum);
```

---

## Admin Hub Panel (in `index.html` → Job Record)

The hub panel renders inside the existing Job Record view. Add it as a new collapsible section.

### Generate Hub Link

```js
async function generateHubLink(jobId) {
  const token = crypto.randomUUID();
  const hubUrl = `${window.location.origin}/orders/hub.html?token=${token}`;

  const { data: kitOrder, error } = await supabase.from('kit_orders').insert({
    job_id: jobId,
    brand_id: currentBrand?.id,
    club_id: currentJob?.club_id,
    token,
    hub_url: hubUrl,
    created_by: currentUser?.id
  }).select().single();

  if (error) { showToast('Failed to generate hub link'); return; }

  // Backfill any already-approved DTR stages
  await backfillHubStages(jobId, kitOrder.id);

  // Display link + copy button
  renderHubPanel(kitOrder);
  showToast('Hub link generated');
}

async function backfillHubStages(jobId, kitOrderId) {
  // Find the most recent linked design task
  const { data: task } = await supabase
    .from('design_tasks').select('id')
    .eq('job_id', jobId).order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (!task) return;

  // Check and backfill stages 1 and 2
  for (const stageNum of [1, 2]) {
    const { data: stages } = await supabase
      .from('design_stages').select('id, status')
      .eq('task_id', task.id).eq('stage_number', stageNum);
    if (!stages?.length) continue;

    // Only backfill if stage is approved
    const approvedStage = stages.find(s => s.status === 'approved');
    if (!approvedStage) continue;

    await maybeUnlockHubStage(task.id, stageNum);
  }
}
```

### Stage 3 Upload (Pre-Production)

```js
async function uploadPreprodFile(kitOrderId, file) {
  const timestamp = Date.now();
  const ext = file.name.split('.').pop();
  const path = `${currentBrand.id}/kit-hub/${kitOrderId}/preprod-${timestamp}.${ext}`;

  const { data: uploadData, error: uploadErr } = await supabase.storage
    .from('design-uploads').upload(path, file);
  if (uploadErr) { showToast('Upload failed'); return; }

  const { data: urlData } = supabase.storage.from('design-uploads').getPublicUrl(uploadData.path);

  await supabase.from('kit_stage_files').insert({
    order_id: kitOrderId,
    stage_number: 3,
    file_url: urlData.publicUrl,
    file_name: file.name,
    file_type: file.type,
    source: 'manual'
  });

  // Mark stage 3 as unlocked
  await supabase.from('kit_orders')
    .update({ stage_3_unlocked: true }).eq('id', kitOrderId);

  showToast('Pre-production file uploaded');
  await refreshHubPanel(kitOrderId);
}
```

### Hub Panel HTML (in Job Record)

```html
<!-- Order Hub Panel — add inside Job Record section -->
<div id="orderHubPanel" class="border border-gray-200 rounded-lg p-4 mt-4">
  <h3 class="text-sm font-semibold text-gray-700 mb-3">Order Hub</h3>

  <!-- No hub yet -->
  <div id="hubNoLink">
    <p class="text-xs text-gray-500 mb-2">Generate a unique link for the customer to review and approve designs.</p>
    <button onclick="generateHubLink(currentJobId)"
      class="btn-primary text-xs px-3 py-1.5">Generate Hub Link</button>
  </div>

  <!-- Hub exists -->
  <div id="hubLinkSection" class="hidden">
    <div class="flex items-center gap-2 mb-3">
      <input id="hubLinkInput" type="text" readonly
        class="text-xs border border-gray-200 rounded px-2 py-1 flex-1 bg-gray-50" />
      <button onclick="copyHubLink()" class="btn-secondary text-xs px-2 py-1">Copy</button>
    </div>

    <!-- Stage status summary -->
    <div class="grid grid-cols-3 gap-2 text-xs">
      <div id="hubStage1Status" class="rounded p-2 bg-gray-50 text-center">
        <div class="font-medium text-gray-600">Concepts</div>
        <div class="text-gray-400 mt-0.5" id="hubStage1Badge">—</div>
      </div>
      <div id="hubStage2Status" class="rounded p-2 bg-gray-50 text-center">
        <div class="font-medium text-gray-600">Full Range</div>
        <div class="text-gray-400 mt-0.5" id="hubStage2Badge">—</div>
      </div>
      <div id="hubStage3Status" class="rounded p-2 bg-gray-50 text-center">
        <div class="font-medium text-gray-600">Pre-Production</div>
        <div class="text-gray-400 mt-0.5" id="hubStage3Badge">—</div>
      </div>
    </div>

    <!-- Stage 3 upload -->
    <div class="mt-3">
      <label class="text-xs font-medium text-gray-600">Upload Pre-Production Samples</label>
      <input type="file" id="preprodFileInput" accept="image/*,.pdf" multiple
        class="mt-1 text-xs" onchange="handlePreprodUpload(event)" />
    </div>
  </div>
</div>
```

---

## `orders/hub.html` — Full Specification

### Load Sequence

```
1. Read token from URL: new URLSearchParams(location.search).get('token')
2. If no token → show "Invalid link" screen
3. Fetch kit_orders by token (anon Supabase client)
4. If no order found → show "Link not found" screen
5. Fetch kit_stage_files for order_id (all stages)
6. Fetch kit_file_reviews for order_id (all existing decisions)
7. Render hub: show only unlocked stages
8. For each file: show image + current decision state
```

### Supabase Client Setup (hub.html — no auth required)

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script type="module">
  const SUPABASE_URL = 'https://<your-project>.supabase.co';
  const SUPABASE_ANON_KEY = '<your-anon-key>';
  const { createClient } = supabase;
  const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Load order
  const token = new URLSearchParams(location.search).get('token');
  const { data: order } = await db.from('kit_orders')
    .select('*').eq('token', token).single();

  // Load files and reviews in parallel
  const [{ data: files }, { data: reviews }] = await Promise.all([
    db.from('kit_stage_files').select('*').eq('order_id', order.id),
    db.from('kit_file_reviews').select('*').eq('order_id', order.id)
  ]);
</script>
```

### Supabase Calls — Customer Actions

**Approve a file:**
```js
async function approveFile(fileId, stageNum) {
  // Check if review already exists
  const existing = reviews.find(r => r.file_id === fileId);
  if (existing) {
    await db.from('kit_file_reviews')
      .update({ decision: 'approved', feedback: null, reviewed_at: new Date().toISOString() })
      .eq('id', existing.id);
  } else {
    await db.from('kit_file_reviews').insert({
      file_id: fileId,
      order_id: order.id,
      stage_number: stageNum,
      decision: 'approved'
    });
  }
  await reloadReviews();
  checkStageCompletion(stageNum);
}
```

**Decline a file:**
```js
async function declineFile(fileId, stageNum, feedbackText) {
  const existing = reviews.find(r => r.file_id === fileId);
  if (existing) {
    await db.from('kit_file_reviews')
      .update({ decision: 'declined', feedback: feedbackText, reviewed_at: new Date().toISOString() })
      .eq('id', existing.id);
  } else {
    await db.from('kit_file_reviews').insert({
      file_id: fileId,
      order_id: order.id,
      stage_number: stageNum,
      decision: 'declined',
      feedback: feedbackText
    });
  }
  await reloadReviews();
}
```

**Stage completion check:**
```js
function checkStageCompletion(stageNum) {
  const stageFiles = files.filter(f => f.stage_number === stageNum);
  const stageReviews = reviews.filter(r => r.stage_number === stageNum);
  const allApproved = stageFiles.every(f =>
    stageReviews.find(r => r.file_id === f.id && r.decision === 'approved')
  );
  if (allApproved) renderStageComplete(stageNum);
}
```

### hub.html UI Layout

```
┌──────────────────────────────────────────┐
│  [Brand Logo]  Order Hub                 │
│  Club: [Club Name]   Job: [Job Number]   │
├──────────────────────────────────────────┤
│  Stage 1 — Concept Designs      ● Active │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ image 1 │ │ image 2 │ │ image 3 │   │
│  │ ✓ Appr  │ │ ✗ Decl  │ │ pending │   │
│  └─────────┘ └─────────┘ └─────────┘   │
├──────────────────────────────────────────┤
│  Stage 2 — Full Range           ● Active │
│  ...                                     │
├──────────────────────────────────────────┤
│  Stage 3 — Pre-Production       🔒 Locked│
│  Awaiting pre-production samples...      │
└──────────────────────────────────────────┘
```

Each file card:
- Shows image preview (or PDF icon for PDFs)
- Shows current decision state (no decision / approved / declined)
- **Approve button** (green tick)
- **Decline button** (red X) → opens inline feedback textarea → confirm
- Declined files show the feedback text in red
- Once approved, the card gets a green border + "Approved" badge

---

## Build Order (5 Sessions)

### Session 1 — DB Migrations
- Write `migrations/035_kit_order_hub.sql` (schema above)
- Apply in Supabase SQL editor
- Verify tables exist

### Session 2 — Admin Hub Panel in `index.html`
- Add Order Hub panel HTML to Job Record view
- Implement `generateHubLink()` + `backfillHubStages()`
- Implement Stage 3 upload (`uploadPreprodFile()`)
- Implement hub panel render + status badges
- Test: generate a link, verify `kit_orders` row created

### Session 3 — DTR Hook
- Add `maybeUnlockHubStage()` function to `index.html`
- Extend `approveStage()` to call it after success
- Test: approve DTR stage 1 → verify `kit_stage_files` populated and `stage_1_unlocked = true`

### Session 4 — `orders/hub.html` Core
- Create `orders/hub.html` with Supabase client
- Implement token load sequence + error screens
- Render unlocked stages with file cards
- Show existing review states on load

### Session 5 — Approve/Decline Flow + Polish
- Implement `approveFile()` + `declineFile()` + feedback modal
- Implement `checkStageCompletion()` → show stage complete banner
- End-to-end test: generate link → approve DTR stages → customer views hub → approves files
- Admin sees approval status badges update in Job Record panel

---

## Notes

- **Token security:** The hub URL token is the only access control. Treat it as a secret link. No PIN needed for MVP.
- **Backfill on generate:** When admin generates the hub link after DTR stages are already approved, `backfillHubStages()` ensures those files are immediately available.
- **Re-approval:** If a file is declined and admin uploads a revised version (in DTR), the admin re-approves the new upload in DTR, which fires `maybeUnlockHubStage()` again — the new file is added to `kit_stage_files`. The old file's review remains; the customer sees both files and must approve the new one.
- **RLS:** `kit_file_reviews` allows anon INSERT and UPDATE so the customer hub can write decisions without authentication. This is intentional — the token URL is the gate.
