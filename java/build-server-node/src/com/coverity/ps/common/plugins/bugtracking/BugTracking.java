package com.coverity.ps.common.plugins.bugtracking;

import com.coverity.ws.v4.MergedDefectDataObj;

public interface BugTracking {
	public String createBug(String project, MergedDefectDataObj defect, boolean isDryRun) throws Exception;
}
