package com.podman.test.Podman.Test.Project.service;

import com.podman.test.Podman.Test.Project.dto.MessageCreatedEvent;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class MessageEventPublisher {

    private final RabbitTemplate rabbitTemplate;
    private final boolean messagingEnabled;
    private final String queueName;

    public MessageEventPublisher(
            RabbitTemplate rabbitTemplate,
            @Value("${app.messaging.enabled}") boolean messagingEnabled,
            @Value("${app.messaging.queue}") String queueName) {
        this.rabbitTemplate = rabbitTemplate;
        this.messagingEnabled = messagingEnabled;
        this.queueName = queueName;
    }

    public void publish(MessageCreatedEvent event) {
        if (!messagingEnabled) {
            return;
        }

        rabbitTemplate.convertAndSend(queueName, event);
    }
}
