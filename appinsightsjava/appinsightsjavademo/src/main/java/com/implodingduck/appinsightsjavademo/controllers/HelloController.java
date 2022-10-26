package com.implodingduck.appinsightsjavademo.controllers;

import java.util.Date;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
    private static final String template = "Hello, %s! The time is: %s!";

    @GetMapping("/")
	public String hello(@RequestParam(value = "name", defaultValue = "World") String name ) {
		return String.format(template, name, new Date().toString());
	}
}

