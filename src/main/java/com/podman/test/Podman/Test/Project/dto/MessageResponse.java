package com.podman.test.Podman.Test.Project.dto;

import java.time.Instant;

public record MessageResponse(Long id, String author, String content, Instant createdAt) {
}
