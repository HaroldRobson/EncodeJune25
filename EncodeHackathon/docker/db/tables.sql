-- Birthday Donations Database Schema

CREATE TABLE parents (
    parent_id SERIAL PRIMARY KEY, 
    parent_email VARCHAR(255) NOT NULL,
    auth0_id VARCHAR(255) NOT NULL UNIQUE,
    stripe_customer_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE children (
    child_id SERIAL PRIMARY KEY,
    DOB DATE NOT NULL,
    parent_id INTEGER NOT NULL REFERENCES parents(parent_id),
    email VARCHAR(255) NOT NULL, 
    isa_expiry DATE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    child_name VARCHAR(255) NOT NULL
);

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    child_id INTEGER NOT NULL REFERENCES children(child_id),
    event_name VARCHAR(255) NOT NULL,
    expires_at DATE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    event_message TEXT,
    videos_enabled BOOLEAN DEFAULT FALSE,
    photo_address VARCHAR(500)
);

CREATE TABLE donations (
    id SERIAL PRIMARY KEY,
    message TEXT,
    donor_name VARCHAR(255) NOT NULL,
    amount_pence INTEGER NOT NULL,
    approved BOOLEAN DEFAULT FALSE,
    event_id INTEGER NOT NULL REFERENCES events(event_id),
    created_at TIMESTAMP DEFAULT NOW(),
    video_address VARCHAR(500)
);
CREATE TABLE payment_accounts (
    account_id SERIAL PRIMARY KEY,
    parent_id INTEGER NOT NULL REFERENCES parents(parent_id),
    stripe_connect_account_id VARCHAR(255) NOT NULL,
    onboarding_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);
-- Create indexes for better performance
CREATE INDEX idx_children_parent_id ON children(parent_id);
CREATE INDEX idx_events_child_id ON events(child_id);
CREATE INDEX idx_donations_event_id ON donations(event_id);
CREATE INDEX idx_donations_approved ON donations(approved);
CREATE INDEX idx_payment_accounts_parent_id ON payment_accounts(parent_id);
CREATE INDEX idx_payment_accounts_stripe_id ON payment_accounts(stripe_connect_account_id);

-- Insert some sample data for testing
INSERT INTO parents (parent_email, auth0_id, stripe_customer_id) VALUES
('parent@example.com', 'auth0|sample123', 'cus_sample123');

INSERT INTO children (DOB, parent_id, email, isa_expiry, child_name) VALUES
('2017-07-15', 1, 'emma@example.com', '2035-07-15', 'Emma');

INSERT INTO events (child_id, event_name, expires_at, event_message, videos_enabled, photo_address) VALUES
(1, 'Emma''s 8th Birthday', '2025-07-15', 'Help us make Emma''s birthday extra special this year!', true, 'https://example.com/emma-photo.jpg');
-- Sample payment account (for testing - normally created via API)
INSERT INTO payment_accounts (parent_id, stripe_connect_account_id, onboarding_complete) VALUES
(1, 'acct_sample123', true);-- Birthday Donations Database Schema
