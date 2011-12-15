package com.coverity.ps.sac.io;

/**
 * Contain for an input specification
 * @author rhollines
 */
public class InputConfiguration {
	private String parserClassName;
	private String fileElemName;
	private String checkerElemName;
	private String checkerAttribName;
	private String eventElemName;
	private String eventAttribName;
	private String lineElemName;
	private String lineAttribName;
	private String functionElemName;
	private String functionAttribName;
	private String descriptionElemName;
	private String descriptionAttribName;
	private String defectElemName;
	private String fileAttribName;
	
	public InputConfiguration(String parserClassName, String defectElemName, 
			String fileElemName, String fileAttribName,
			String checkerElemName,	String checkerAttribName, 
			String eventElemName, String eventAttribName, 
			String lineElemName, String lineAttribName,
			String functionElemName, String functionAttribName,
			String descriptionElemName, String descriptionAttribName) {
		this.parserClassName = parserClassName;
		this.defectElemName = defectElemName;
		this.fileElemName = fileElemName;
		this.fileAttribName = fileAttribName;
		this.checkerElemName = checkerElemName;
		this.checkerAttribName = checkerAttribName;
		this.eventElemName = eventElemName;
		this.eventAttribName = eventAttribName;
		this.lineElemName = lineElemName;
		this.lineAttribName = lineAttribName;
		this.functionElemName = functionElemName;
		this.functionAttribName = functionAttribName;
		this.descriptionElemName = descriptionElemName;
		this.descriptionAttribName = descriptionAttribName;
	}

	public String getParserClassName() {
		return parserClassName;
	}
	
	public String getDefectElemName() {
		return defectElemName;
	}

	public String getFileElemName() {
		return fileElemName;
	}
	
	public String getFileAttribName() {
		return fileAttribName;
	}

	public String getCheckerElemName() {
		return checkerElemName;
	}

	public String getCheckerAttribName() {
		return checkerAttribName;
	}

	public String getEventElemName() {
		return eventElemName;
	}

	public String getEventAttribName() {
		return eventAttribName;
	}

	public String getLineElemName() {
		return lineElemName;
	}

	public String getLineAttribName() {
		return lineAttribName;
	}

	public String getFunctionElemName() {
		return functionElemName;
	}

	public String getFunctionAttribName() {
		return functionAttribName;
	}

	public String getDescriptionElemName() {
		return descriptionElemName;
	}

	public String getDescriptionAttribName() {
		return descriptionAttribName;
	}
}
