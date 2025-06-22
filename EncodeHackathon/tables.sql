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

CREATE TABLE events (
event_id SERIAL PRIMARY KEY,
child_id INTEGER NOT NULL REFERENCES children(child_id),
event_name VARCHAR(255)  NOT NULL,
expires_at DATE NOT NULL,
created_at TIMESTAMP DEFAULT NOW(),
event_message TEXT,
videos_enabled BOOLEAN DEFAULT FALSE,
photo_address VARCHAR(500)
);

CREATE TABLE children (
child_id SERIAL PRIMARY KEY,
DOB DATE NOT NULL,
parent_id INTEGER NOT NULL REFERENCES parents(parent_id),
email VARCHAR(255)  NOT NULL, 
isa_expiry DATE NOT NULL,
created_at TIMESTAMP DEFAULT NOW(),
child_name VARCHAR(255) NOT NULL
);

CREATE TABLE parents (
parent_id SERIAL PRIMARY KEY, 
parent_email VARCHAR(255)  NOT NULL,
auth0_id VARCHAR(255)  NOT NULL UNIQUE,
stripe_customer_id VARCHAR(255),
created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payment_accounts (
    account_id SERIAL PRIMARY KEY,
    parent_id INTEGER NOT NULL REFERENCES parents(parent_id),
    stripe_connect_account_id VARCHAR(255) NOT NULL,
    onboarding_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);
