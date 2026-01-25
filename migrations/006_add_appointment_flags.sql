ALTER TABLE leads ADD COLUMN IF NOT EXISTS appointment_today BOOLEAN DEFAULT FALSE;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS appointment_time TIME;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS appointment_confirmed BOOLEAN DEFAULT FALSE;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS distance_km DECIMAL(8, 2);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS is_owner BOOLEAN DEFAULT FALSE;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS missed_calls INTEGER DEFAULT 0;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS interested BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_leads_appointment_today ON leads(appointment_today);
CREATE INDEX IF NOT EXISTS idx_leads_appointment_time ON leads(appointment_time);
CREATE INDEX IF NOT EXISTS idx_leads_distance ON leads(distance_km);

COMMENT ON COLUMN leads.appointment_today IS 'Flag for appointments scheduled today';
COMMENT ON COLUMN leads.appointment_time IS 'Time of appointment if scheduled';
COMMENT ON COLUMN leads.appointment_confirmed IS 'Whether appointment is confirmed with customer';
COMMENT ON COLUMN leads.distance_km IS 'Distance from installer base in km';
COMMENT ON COLUMN leads.is_owner IS 'Whether customer owns the property (vs. renter)';
COMMENT ON COLUMN leads.missed_calls IS 'Count of missed call attempts';
COMMENT ON COLUMN leads.interested IS 'Whether customer expressed interest in follow-up';
