# CLAUDE.md — TeamwearOS Session Context

## Project

**TeamwearOS** is a single-file web application (`index.html`, ~25,000 lines) backed by **Supabase** (PostgreSQL + RLS). No build step, no framework — pure vanilla HTML/CSS/JS.

Open `index.html` directly in a browser (or serve via any static HTTP server).

## Supabase Configuration

Located near the top of `index.html`:

```js
const SUPABASE_URL = 'https://<your-project>.supabase.co';
const SUPABASE_ANON_KEY = '<your-anon-key>';
const supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

## Key File Paths

| Path | Purpose |
|------|---------|
| `index.html` | Main application (all modules) |
| `orders/hub.html` | Customer-facing Order Hub (approval flow) |
| `migrations/` | 34 SQL migration files (001–034) |

## JS Conventions

- **Async/await** throughout — no raw `.then()` chains
- **Error handling:** `const { data, error } = await supabase.from(...)` — always check `if (error)`
- **Toast notifications:** `showToast(message)` — use for user-facing feedback
- **Modals:** use existing modal pattern from `index.html` (open/close by toggling CSS classes)
- **No ES modules** — all functions are global in `index.html`; `orders/hub.html` uses `<script type="module">`

## Key Existing Patterns

```js
// Standard Supabase query
const { data, error } = await supabase
  .from('table_name')
  .select('id, name')
  .eq('brand_id', currentBrand.id);
if (error) { showToast('Error loading data'); console.error(error); return; }

// Toast
showToast('Saved successfully');

// Storage upload (uses existing 'design-uploads' bucket)
const { data: uploadData } = await supabase.storage
  .from('design-uploads')
  .upload(`${brandId}/kit-hub/${orderId}/${filename}`, file);
const { data: urlData } = supabase.storage
  .from('design-uploads').getPublicUrl(uploadData.path);
```

## Key Tables

| Table | Purpose |
|-------|---------|
| `jobs` | Sales job records |
| `design_tasks` | DTR design task records (`job_id` FK→jobs) |
| `design_stages` | Stages within a design task (`task_id`, `stage_number`) |
| `stage_uploads` | Files uploaded per design stage (`stage_id`, `task_id`, `status`) |
| `kit_orders` | Order Hub record per job (`job_id`, `token`, `stage_N_unlocked`) |
| `kit_stage_files` | Files per hub stage (`order_id`, `stage_number`, `file_url`) |
| `kit_file_reviews` | Customer approval decisions (`file_id`, `decision`, `feedback`) |

## Current Active Work

**Building ROKOR Order Hub** — 3-stage customer approval flow (Concepts → Full Range → Pre-Production).

See `CLAUDE_BUILD_V2.md` for the full specification.
