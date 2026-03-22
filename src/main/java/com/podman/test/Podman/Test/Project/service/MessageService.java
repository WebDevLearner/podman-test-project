package com.podman.test.Podman.Test.Project.service;

import com.podman.test.Podman.Test.Project.dto.MessageRequest;
import com.podman.test.Podman.Test.Project.dto.MessageResponse;
import com.podman.test.Podman.Test.Project.dto.MessageSavedEvent;
import com.podman.test.Podman.Test.Project.exception.MessageNotFoundException;
import com.podman.test.Podman.Test.Project.model.Message;
import com.podman.test.Podman.Test.Project.repository.MessageRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MessageService {

    private final MessageRepository messageRepository;
    private final MessagePublisher messagePublisher;

    public MessageService(MessageRepository messageRepository, MessagePublisher messagePublisher) {
        this.messageRepository = messageRepository;
        this.messagePublisher = messagePublisher;
    }

    public List<MessageResponse> findAll() {
        return messageRepository.findAllByOrderByIdAsc().stream()
                .map(this::toResponse)
                .toList();
    }

    public MessageResponse findById(Long id) {
        return toResponse(getMessage(id));
    }

    public MessageResponse create(MessageRequest request) {
        validate(request);
        Message savedMessage = messageRepository.save(new Message(request.author(), request.content()));
        publishSaved(savedMessage);
        return toResponse(savedMessage);
    }

    public MessageResponse update(Long id, MessageRequest request) {
        validate(request);
        Message message = getMessage(id);
        message.update(request.author(), request.content());
        Message savedMessage = messageRepository.save(message);
        publishSaved(savedMessage);
        return toResponse(savedMessage);
    }

    public void delete(Long id) {
        messageRepository.delete(getMessage(id));
    }

    private Message getMessage(Long id) {
        return messageRepository.findById(id)
                .orElseThrow(() -> new MessageNotFoundException(id));
    }

    private void validate(MessageRequest request) {
        if (request.author() == null || request.author().isBlank()) {
            throw new IllegalArgumentException("author must not be blank");
        }
        if (request.content() == null || request.content().isBlank()) {
            throw new IllegalArgumentException("content must not be blank");
        }
    }

    private MessageResponse toResponse(Message message) {
        return new MessageResponse(
                message.getId(),
                message.getAuthor(),
                message.getContent(),
                message.getCreatedAt());
    }

    private void publishSaved(Message message) {
        messagePublisher.publishSaved(new MessageSavedEvent(
                message.getId(),
                message.getAuthor(),
                message.getContent(),
                message.getCreatedAt()));
    }
}
