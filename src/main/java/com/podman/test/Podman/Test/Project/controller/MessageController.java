package com.podman.test.Podman.Test.Project.controller;

import com.podman.test.Podman.Test.Project.dto.MessageRequest;
import com.podman.test.Podman.Test.Project.dto.MessageResponse;
import com.podman.test.Podman.Test.Project.service.MessageService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/messages")
public class MessageController {

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    @GetMapping
    public List<MessageResponse> findAll() {
        return messageService.findAll();
    }

    @GetMapping("/{id}")
    public MessageResponse findById(@PathVariable Long id) {
        return messageService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse create(@RequestBody MessageRequest request) {
        return messageService.create(request);
    }

    @PutMapping("/{id}")
    public MessageResponse update(@PathVariable Long id, @RequestBody MessageRequest request) {
        return messageService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        messageService.delete(id);
    }
}
