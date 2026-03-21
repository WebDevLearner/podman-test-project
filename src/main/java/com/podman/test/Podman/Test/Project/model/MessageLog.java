package com.podman.test.Podman.Test.Project.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "message_log")
public class MessageLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "requested_name")
    private String requestedName;

    @Column(name = "response_message", nullable = false)
    private String responseMessage;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected MessageLog() {
    }

    public MessageLog(String requestedName, String responseMessage) {
        this.requestedName = requestedName;
        this.responseMessage = responseMessage;
    }

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getRequestedName() {
        return requestedName;
    }

    public String getResponseMessage() {
        return responseMessage;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
