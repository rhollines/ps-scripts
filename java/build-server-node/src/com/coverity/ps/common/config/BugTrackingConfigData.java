package com.coverity.ps.common.config;

import java.util.Map;

public class BugTrackingConfigData {
	private String forClass;
	private String address;
	private String user;
	private String password;
	private Map<String, String> properties;
	private String project;

	public BugTrackingConfigData(String project, String forClass, String address, String user,
			String password, Map<String, String> properties) {
		this.project = project;
		this.forClass = forClass;
		this.address = address;
		this.user = user;
		this.password = password;
		this.properties = properties;
	}

	public String getForClass() {
		return this.forClass;
	}
	
	public String getProject() {
		return this.project;
	}

	public String getAddress() {
		return this.address;
	}

	public String getUser() {
		return this.user;
	}

	public String getPassword() {
		return this.password;
	}

	public Map<String, String> getProperties() {
		return this.properties;
	}
}
