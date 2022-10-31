package com.implodingduck.logappenderdemo.controllers;

import java.util.Date;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;


@RestController
public class HelloController {

	private static final Logger logger = LogManager.getLogger(HelloController.class);

    private static final String template = "Hello, %s! The time is: %s!";

    @GetMapping("/")
	public String hello(@RequestParam(value = "name", defaultValue = "World") String name ) {
		logger.info("Calling hello...");
		logger.debug("Calling debug...");
		logger.warn("Calling warn...");
		logger.error("Calling error...");
		String msg = String.format(template, name, new Date().toString());
		logger.info(msg);
		return msg;
	}
}

