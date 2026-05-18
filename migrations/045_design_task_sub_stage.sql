-- Add sub_stage column to design_tasks for tracking substages within In Progress and In Review
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS sub_stage text;

-- Migrate existing granular status values into sub_stage, collapsing into the 4 main stages
UPDATE design_tasks SET sub_stage = 'revisions',        status = 'in_progress' WHERE status = 'revisions';
UPDATE design_tasks SET sub_stage = 'factory_handover', status = 'in_progress' WHERE status = 'factory_handover';
UPDATE design_tasks SET sub_stage = 'awaiting_approval',status = 'in_review'   WHERE status = 'awaiting_approval';

-- Set defaults for records that don't yet have a sub_stage
UPDATE design_tasks SET sub_stage = 'in_design'       WHERE status = 'in_progress' AND sub_stage IS NULL;
UPDATE design_tasks SET sub_stage = 'internal_review'  WHERE status = 'in_review'   AND sub_stage IS NULL;

-- Collapse delivered into completed (delivered is no longer a separate main stage)
UPDATE design_tasks SET status = 'completed' WHERE status = 'delivered';
