package com.coverity.ps.common.config;

public class ScmStreamData {
	private String name;
	private String cimStripPath;
	private String localPrependPath;
	
	
	public ScmStreamData(String name, String cimStripPath, String localPrependPath) {
		this.name = name;
		this.cimStripPath = cimStripPath;
		this.localPrependPath = localPrependPath;
	}

	public String getName() {
		return name;
	}

	public String getCimStripPath() {
		return cimStripPath;
	}

	public String getLocalPrependPath() {
		return localPrependPath;
	}
}
