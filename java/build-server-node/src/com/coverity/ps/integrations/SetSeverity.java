package com.coverity.ps.integrations;


public class SetSeverity implements Integration {
	private boolean isDryRun;

	public SetSeverity(boolean isDryRun) {
		this.isDryRun = isDryRun;
	}
	
	public boolean execute() throws Exception {
		return true;
	}
	
	public static void main(String[] args) {
		
	}
}
