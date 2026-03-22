package com.podman.test.Podman.Test.Project.controller;

import com.podman.test.Podman.Test.Project.model.Message;
import com.podman.test.Podman.Test.Project.repository.MessageRepository;
import com.podman.test.Podman.Test.Project.service.MessagePublisher;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class MessageControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private MessageRepository messageRepository;

    @MockitoSpyBean
    private MessagePublisher messagePublisher;

    @Test
    void shouldListSeededMessages() throws Exception {
        messageRepository.save(new Message("system", "Welcome to the Podman test project"));

        mockMvc.perform(get("/api/messages"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].author").value("system"))
                .andExpect(jsonPath("$[0].content").value("Welcome to the Podman test project"));
    }

    @Test
    void shouldGetMessageById() throws Exception {
        Message message = messageRepository.save(new Message("system", "Welcome to the Podman test project"));

        mockMvc.perform(get("/api/messages/" + message.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.author").value("system"))
                .andExpect(jsonPath("$.content").value("Welcome to the Podman test project"));
    }

    @Test
    void shouldCreateMessageAndPublishEvent() throws Exception {
        mockMvc.perform(post("/api/messages")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "author": "alex",
                                  "content": "stored from controller"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.author").value("alex"))
                .andExpect(jsonPath("$.content").value("stored from controller"));

        verify(messagePublisher, times(1)).publishSaved(any());
    }

    @Test
    void shouldUpdateMessageAndPublishEvent() throws Exception {
        Message message = messageRepository.save(new Message("admin", "old text"));

        mockMvc.perform(put("/api/messages/" + message.getId())
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "author": "admin",
                                  "content": "updated text"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(message.getId()))
                .andExpect(jsonPath("$.author").value("admin"))
                .andExpect(jsonPath("$.content").value("updated text"));

        verify(messagePublisher, times(1)).publishSaved(any());
    }

    @Test
    void shouldDeleteMessage() throws Exception {
        Message message = messageRepository.save(new Message("admin", "to delete"));

        mockMvc.perform(delete("/api/messages/" + message.getId()))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/messages/" + message.getId()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("message %s was not found".formatted(message.getId())));
    }

    @Test
    void shouldRejectBlankText() throws Exception {
        mockMvc.perform(post("/api/messages")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "author": "alex",
                                  "content": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("content must not be blank"));
    }
}
