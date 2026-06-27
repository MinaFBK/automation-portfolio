-- schema.sql — database structure for the AI invoice-extraction pipeline
-- Apply against the Postgres database n8n connects to, e.g.:
--   docker exec -i n8n-instance-postgres-1 psql -U n8n -d n8n < schema.sql
-- Both statements use IF NOT EXISTS, so re-running is safe (idempotent).

-- ---------------------------------------------------------------------------
-- invoices — the validated, trusted data (true branch of the IF node).
-- Only extractions that passed every validation check land here.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invoices (
    id             BIGSERIAL PRIMARY KEY,
    vendor_name    TEXT,
    invoice_number TEXT,
    invoice_date   DATE,
    due_date       DATE,
    currency       TEXT,                       -- 3-letter ISO code
    subtotal       NUMERIC(14,2),              -- money: fixed precision, never float
    tax            NUMERIC(14,2),
    total          NUMERIC(14,2),
    line_items     JSONB,                      -- the full array of line items
    source_file    TEXT,                       -- original uploaded filename
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- guards against double-entry of the same invoice
    CONSTRAINT uq_invoice UNIQUE (vendor_name, invoice_number)
);

-- ---------------------------------------------------------------------------
-- invoices_review — the human-review queue (false branch of the IF node).
-- Anything the validator rejected (bad JSON, missing field, totals that don't
-- reconcile) lands here with the reasons, so nothing is silently dropped.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invoices_review (
    id          BIGSERIAL PRIMARY KEY,
    data        JSONB,                          -- what the model extracted (may be null if JSON parsing failed)
    errors      JSONB,                          -- the validator's list of why it was rejected
    source_file TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
