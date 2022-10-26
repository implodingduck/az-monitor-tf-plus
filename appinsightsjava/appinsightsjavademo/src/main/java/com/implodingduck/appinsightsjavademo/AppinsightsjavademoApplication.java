package com.implodingduck.appinsightsjavademo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import com.microsoft.applicationinsights.attach.ApplicationInsights;

@SpringBootApplication
public class AppinsightsjavademoApplication {

	public static void main(String[] args) {
		ApplicationInsights.attach();
		SpringApplication.run(AppinsightsjavademoApplication.class, args);
	}

}
