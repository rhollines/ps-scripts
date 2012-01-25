package com.coverity.ps.common.plugins.scm;

public interface ScmPlugin {
	public String getFileOwner(String stream, String file) throws Exception;
}
