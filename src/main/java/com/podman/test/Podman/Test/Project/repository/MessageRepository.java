package com.podman.test.Podman.Test.Project.repository;

import com.podman.test.Podman.Test.Project.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {

    List<Message> findAllByOrderByIdAsc();
}
