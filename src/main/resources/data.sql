INSERT INTO seeded_message (source_name, message_text)
SELECT 'system', 'Welcome to the Podman test project database'
WHERE NOT EXISTS (
    SELECT 1 FROM seeded_message
    WHERE source_name = 'system' AND message_text = 'Welcome to the Podman test project database'
);

INSERT INTO seeded_message (source_name, message_text)
SELECT 'system', 'MySQL connectivity is enabled'
WHERE NOT EXISTS (
    SELECT 1 FROM seeded_message
    WHERE source_name = 'system' AND message_text = 'MySQL connectivity is enabled'
);

INSERT INTO seeded_message (source_name, message_text)
SELECT 'admin', 'This row was seeded during application startup'
WHERE NOT EXISTS (
    SELECT 1 FROM seeded_message
    WHERE source_name = 'admin' AND message_text = 'This row was seeded during application startup'
);

INSERT INTO seeded_message (source_name, message_text)
SELECT 'admin', 'Use POST /api/v1/test to create message_log rows'
WHERE NOT EXISTS (
    SELECT 1 FROM seeded_message
    WHERE source_name = 'admin' AND message_text = 'Use POST /api/v1/test to create message_log rows'
);

INSERT INTO seeded_message (source_name, message_text)
SELECT 'demo', 'Five default rows are now available in seeded_message'
WHERE NOT EXISTS (
    SELECT 1 FROM seeded_message
    WHERE source_name = 'demo' AND message_text = 'Five default rows are now available in seeded_message'
);
