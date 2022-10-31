package com.implodingduck.logappenderdemo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

@SpringBootApplication
public class LogappenderdemoApplication {
	private static final Logger logger = LogManager.getLogger(LogappenderdemoApplication.class);

	public static void main(String[] args) {
		SpringApplication.run(LogappenderdemoApplication.class, args);
	}

}
