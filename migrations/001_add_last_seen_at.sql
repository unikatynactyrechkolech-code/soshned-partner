-- Migration: Add last_seen_at column to partners table
-- Purpose: Track when partner was last seen online for activity monitoring
-- Executes: In Supabase SQL Editor (https://ysyvbjzpoxpttoofjwfc.supabase.co)

ALTER TABLE partners 
ADD COLUMN last_seen_at TIMESTAMPTZ DEFAULT now();

-- Add index for faster queries on last_seen_at
CREATE INDEX idx_partners_last_seen_at ON partners(last_seen_at DESC);

-- Add index for partner location queries (lat + lng together)
CREATE INDEX idx_partners_location ON partners(lat, lng) 
WHERE lat IS NOT NULL AND lng IS NOT NULL;

-- Comment for documentation
COMMENT ON COLUMN partners.last_seen_at IS 'Timestamp of last location update or online toggle';
