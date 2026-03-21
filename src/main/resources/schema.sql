CREATE TABLE IF NOT EXISTS seeded_message (
    id BIGINT NOT NULL AUTO_INCREMENT,
    source_name VARCHAR(100) NOT NULL,
    message_text VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_seeded_message PRIMARY KEY (id),
    CONSTRAINT uk_seeded_message_source_text UNIQUE (source_name, message_text)
);
