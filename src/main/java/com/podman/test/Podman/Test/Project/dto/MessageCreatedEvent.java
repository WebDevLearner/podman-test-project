package com.podman.test.Podman.Test.Project.dto;

import java.time.Instant;

public record MessageCreatedEvent(Long id, String requestedName, String responseMessage, Instant createdAt) {
}
