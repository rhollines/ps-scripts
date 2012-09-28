package com.coverity.ps.common.config;

import java.util.Map;
import java.util.HashMap;


public class ScmConfigData {
    private final HashMap<String, String> map;
	
	public ScmConfigData(Map<String, String> data) {
	    this.map = new HashMap<String, String>(data.size());
		this.map.putAll(data);
    }
	 
	public ScmConfigData(String name, String cimStripPath, String localPrependPath) {
	    this.map = new HashMap<String, String>();
		this.map.put("name", name);
		this.map.put("cimStripPath", cimStripPath);
		this.map.put("localPrependPath", localPrependPath);
	}

	public String getName() {
		return this.map.get("name");
	}

	public String getCimStripPath() {
		return this.map.get("cimStripPath");
	}

	public String getLocalPrependPath() {
		return this.map.get("localPrependPath");
	}
	
	public String get(String key) {
	    return this.map.get(key);
	}
}
