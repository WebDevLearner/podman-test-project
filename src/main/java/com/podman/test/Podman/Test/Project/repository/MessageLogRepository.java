package com.podman.test.Podman.Test.Project.repository;

import com.podman.test.Podman.Test.Project.model.MessageLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MessageLogRepository extends JpaRepository<MessageLog, Long> {
}
