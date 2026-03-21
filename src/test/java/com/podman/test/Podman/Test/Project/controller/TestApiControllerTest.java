package com.podman.test.Podman.Test.Project.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class TestApiControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldReturnDefaultMessage() throws Exception {
        mockMvc.perform(get("/api/v1/test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Podman test API is running"))
                .andExpect(jsonPath("$.status").value("OK"));
    }

    @Test
    void shouldReturnPersonalizedMessage() throws Exception {
        mockMvc.perform(get("/api/v1/test/Alex"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Hello, Alex. Podman test API is running"))
                .andExpect(jsonPath("$.status").value("OK"));
    }

    @Test
    void shouldReturnMessageHistory() throws Exception {
        mockMvc.perform(get("/api/v1/test"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/test/history"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].responseMessage").value("Podman test API is running"))
                .andExpect(jsonPath("$[0].requestedName").isEmpty());
    }

    @Test
    void shouldCreateMessage() throws Exception {
        mockMvc.perform(post("/api/v1/test")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedName": "Alex",
                                  "message": "Stored from controller"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.requestedName").value("Alex"))
                .andExpect(jsonPath("$.responseMessage").value("Stored from controller"));
    }

    @Test
    void shouldRejectBlankMessage() throws Exception {
        mockMvc.perform(post("/api/v1/test")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedName": "Alex",
                                  "message": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("message must not be blank"))
                .andExpect(jsonPath("$.status").value("ERROR"));
    }
}
