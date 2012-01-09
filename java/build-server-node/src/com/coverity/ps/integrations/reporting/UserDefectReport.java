package com.coverity.ps.integrations.reporting;

import java.util.ArrayList;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.datatype.DatatypeConfigurationException;
import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.XMLGregorianCalendar;

import com.coverity.cim.ws.CovRemoteServiceException_Exception;
import com.coverity.cim.ws.MergedDefectDataObj;
import com.coverity.cim.ws.MergedDefectFilterSpecDataObj;
import com.coverity.cim.ws.ProjectDataObj;
import com.coverity.cim.ws.UserDataObj;
import com.coverity.ps.common.CimProxy;
import com.coverity.ps.integrations.Integration;


/*
 * Base class for defect reporting
 */
public abstract class UserDefectReport implements Integration {
	final static String UNASSIGNED_OWNER_NAME = "Unassigned";
	protected boolean isDryRun;
	protected String projectName;
	protected int days;
	protected long projectId;
	
	protected UserDefectReport(String project, int days, boolean isDryRun) {
		this.projectName = project;
		this.days = days;
		this.isDryRun = isDryRun;
	}
	
	protected Map<String, List<MergedDefectDataObj>> getStreamDefectsByOwner() throws CovRemoteServiceException_Exception, DatatypeConfigurationException {
		Map<String, List<MergedDefectDataObj>> defectsByUser = new HashMap<String, List<MergedDefectDataObj>>();
		CimProxy cimProxy = CimProxy.getInstance();
		
		// get project id
		ProjectDataObj projectData = cimProxy.getProject(projectName);
		if(projectData != null) {
			this.projectId = projectData.getProjectKey();
			// get users
			Map<String, String> userMap = new HashMap<String, String>();
			List<UserDataObj> userList = cimProxy.getAllUsers();
			for(UserDataObj user : userList) {
				userMap.put(user.getUsername(), user.getEmail());
			}
			
			
			// calculate as-of date
			final long oneDay = 1000 * 60 * 60 * 24;
			GregorianCalendar calendar = new GregorianCalendar();
			calendar.setTimeInMillis(System.currentTimeMillis() - this.days * oneDay);
			XMLGregorianCalendar lastDetected = DatatypeFactory.newInstance().newXMLGregorianCalendar(calendar);
			
			System.out.println("as-of-date=" + lastDetected);
			
			// get defects
			MergedDefectFilterSpecDataObj projectFilter = new MergedDefectFilterSpecDataObj();
			projectFilter.setFirstDetectedStartDate(lastDetected);List<MergedDefectDataObj> defects = cimProxy.getMergedDefectsForProject(this.projectName, projectFilter);
			for(MergedDefectDataObj defect : defects) {
				if(userMap.containsKey(defect.getOwner())) {
					List<MergedDefectDataObj> userDefects = (List<MergedDefectDataObj>)defectsByUser.get(defect.getOwner());
					if(userDefects == null) {
						userDefects = new ArrayList<MergedDefectDataObj>();
						defectsByUser.put(defect.getOwner(), userDefects);
					}
					// System.out.println("cid=" + defect.getCid() + ", owner=" + defect.getOwner());
					userDefects.add(defect);
				}
				else {
					List<MergedDefectDataObj> userDefects = (List<MergedDefectDataObj>)defectsByUser.get(UNASSIGNED_OWNER_NAME);
					if(userDefects == null) {
						userDefects = new ArrayList<MergedDefectDataObj>();
						defectsByUser.put(UNASSIGNED_OWNER_NAME, userDefects);
					}
					// System.out.println("cid=" + defect.getCid() + ", owner=" + defect.getOwner());
					userDefects.add(defect);
				}
			}
		}
		
		return defectsByUser;
	}
	
	abstract public boolean execute() throws Exception;
}
