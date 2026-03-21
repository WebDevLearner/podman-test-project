package com.podman.test.Podman.Test.Project.service;

import com.podman.test.Podman.Test.Project.dto.ApiMessageResponse;
import com.podman.test.Podman.Test.Project.dto.MessageCreatedEvent;
import com.podman.test.Podman.Test.Project.dto.MessageHistoryResponse;
import com.podman.test.Podman.Test.Project.model.MessageLog;
import com.podman.test.Podman.Test.Project.repository.MessageLogRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class TestApiService {

    private final MessageLogRepository messageLogRepository;
    private final MessageEventPublisher messageEventPublisher;

    public TestApiService(
            MessageLogRepository messageLogRepository,
            MessageEventPublisher messageEventPublisher) {
        this.messageLogRepository = messageLogRepository;
        this.messageEventPublisher = messageEventPublisher;
    }

    public ApiMessageResponse getDefaultMessage() {
        return buildAndPersistResponse(null, "Podman test API is running");
    }

    public ApiMessageResponse getPersonalizedMessage(String name) {
        return buildAndPersistResponse(name, "Hello, %s. Podman test API is running".formatted(name));
    }

    public List<MessageHistoryResponse> getMessageHistory() {
        return messageLogRepository.findAll().stream()
                .map(messageLog -> new MessageHistoryResponse(
                        messageLog.getId(),
                        messageLog.getRequestedName(),
                        messageLog.getResponseMessage(),
                        messageLog.getCreatedAt()))
                .toList();
    }

    public MessageHistoryResponse createMessage(String requestedName, String message) {
        if (message == null || message.isBlank()) {
            throw new IllegalArgumentException("message must not be blank");
        }

        MessageLog messageLog = messageLogRepository.save(new MessageLog(requestedName, message));
        MessageHistoryResponse response = new MessageHistoryResponse(
                messageLog.getId(),
                messageLog.getRequestedName(),
                messageLog.getResponseMessage(),
                messageLog.getCreatedAt());
        publishCreatedEvent(response);
        return response;
    }

    private ApiMessageResponse buildAndPersistResponse(String requestedName, String message) {
        MessageLog messageLog = messageLogRepository.save(new MessageLog(requestedName, message));
        publishCreatedEvent(new MessageHistoryResponse(
                messageLog.getId(),
                messageLog.getRequestedName(),
                messageLog.getResponseMessage(),
                messageLog.getCreatedAt()));
        return new ApiMessageResponse(message, "OK");
    }

    private void publishCreatedEvent(MessageHistoryResponse response) {
        messageEventPublisher.publish(new MessageCreatedEvent(
                response.id(),
                response.requestedName(),
                response.responseMessage(),
                response.createdAt()));
    }
}
