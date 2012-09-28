package com.coverity.ps.integrations;

import com.coverity.ps.common.CimProxy;
import com.coverity.ws.v4.ProjectDataObj;

public class Test {
	public static void main(String[] args) {
		try {
			ProjectDataObj project = CimProxy.getInstance().getProject("objeck-lang");
			System.out.println("id=" + project.getId().getName());
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
