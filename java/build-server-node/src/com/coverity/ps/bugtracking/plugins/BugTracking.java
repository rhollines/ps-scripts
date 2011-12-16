package com.coverity.ps.bugtracking.plugins;

import com.coverity.cim.ws.MergedDefectDataObj;

public interface BugTracking {
	public String createBug(String project, MergedDefectDataObj defect, boolean isDryRun) throws Exception;
}
