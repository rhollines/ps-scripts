package com.coverity.ps.integrations.reporting;

import java.util.ArrayList;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.datatype.DatatypeConfigurationException;
import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.XMLGregorianCalendar;

import com.coverity.ps.common.CimProxy;
import com.coverity.ps.integrations.Integration;
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.MergedDefectDataObj;
import com.coverity.ws.v4.MergedDefectFilterSpecDataObj;
import com.coverity.ws.v4.ProjectDataObj;


/*
 * Base class for defect reporting
 */
public abstract class ComponentDefectReport implements Integration {
	protected boolean isDryRun;
	protected String projectName;
	protected int days;
	protected long projectId;
	protected XMLGregorianCalendar lastDetected;
	
	protected ComponentDefectReport(String project, int days, boolean isDryRun) {
		this.projectName = project;
		this.days = days;
		this.isDryRun = isDryRun;
	}
	
	protected Map<String, List<MergedDefectDataObj>> getProjectDefectsByComponent() throws CovRemoteServiceException_Exception, DatatypeConfigurationException {
		Map<String, List<MergedDefectDataObj>> defectsByChecker = new HashMap<String, List<MergedDefectDataObj>>();
		CimProxy cimProxy = CimProxy.getInstance();
		
		// get project id
		ProjectDataObj projectData = cimProxy.getProject(projectName);
		if(projectData != null) {
			this.projectId = projectData.getProjectKey();
			
			// calculate as-of date
			final long oneDay = 1000 * 60 * 60 * 24;
			GregorianCalendar calendar = new GregorianCalendar();
			calendar.setTimeInMillis(System.currentTimeMillis() - this.days * oneDay);
			this.lastDetected = DatatypeFactory.newInstance().newXMLGregorianCalendar(calendar);
			
			System.out.println("as-of-date=" + this.lastDetected);
			
			// get defects
			MergedDefectFilterSpecDataObj projectFilter = new MergedDefectFilterSpecDataObj();
			projectFilter.setFirstDetectedStartDate(this.lastDetected);
			List<MergedDefectDataObj> defects = cimProxy.getMergedDefectsForProject(this.projectName, projectFilter);
			for(MergedDefectDataObj defect : defects) {
				// TODO: error checking...
				final String componentName = defect.getComponentName().substring(defect.getComponentName().lastIndexOf('.') + 1);
				List<MergedDefectDataObj> componentDefects = (List<MergedDefectDataObj>)defectsByChecker.get(componentName);
				if(componentDefects == null) {
					componentDefects = new ArrayList<MergedDefectDataObj>();
					defectsByChecker.put(componentName, componentDefects);
				}
				componentDefects.add(defect);
			}
		}
		else {
			System.err.println("Unable to find project '" + projectName + "'");
		}
		
		return defectsByChecker;
	}
	
	abstract public boolean execute() throws Exception;
}
