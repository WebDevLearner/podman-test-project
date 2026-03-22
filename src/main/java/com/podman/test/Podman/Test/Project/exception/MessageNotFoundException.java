package com.podman.test.Podman.Test.Project.exception;

public class MessageNotFoundException extends RuntimeException {

    public MessageNotFoundException(Long id) {
        super("message %d was not found".formatted(id));
    }
}
