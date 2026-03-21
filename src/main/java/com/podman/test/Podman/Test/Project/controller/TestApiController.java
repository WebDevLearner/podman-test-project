package com.podman.test.Podman.Test.Project.controller;

import com.podman.test.Podman.Test.Project.dto.ApiMessageResponse;
import com.podman.test.Podman.Test.Project.dto.CreateMessageRequest;
import com.podman.test.Podman.Test.Project.dto.MessageHistoryResponse;
import com.podman.test.Podman.Test.Project.service.TestApiService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.ResponseStatus;

import java.util.List;

@RestController
@RequestMapping("/api/v1/test")
public class TestApiController {

    private final TestApiService testApiService;

    public TestApiController(TestApiService testApiService) {
        this.testApiService = testApiService;
    }

    @GetMapping
    public ApiMessageResponse getTestMessage() {
        return testApiService.getDefaultMessage();
    }

    @GetMapping("/{name}")
    public ApiMessageResponse getPersonalizedTestMessage(@PathVariable String name) {
        return testApiService.getPersonalizedMessage(name);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MessageHistoryResponse createMessage(@RequestBody CreateMessageRequest request) {
        return testApiService.createMessage(request.requestedName(), request.message());
    }

    @GetMapping("/history")
    public List<MessageHistoryResponse> getMessageHistory() {
        return testApiService.getMessageHistory();
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiMessageResponse handleIllegalArgument(IllegalArgumentException exception) {
        return new ApiMessageResponse(exception.getMessage(), "ERROR");
    }
}
