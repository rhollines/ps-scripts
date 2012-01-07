// (c) 2011 Coverity, Inc. All rights reserved worldwide.

package com.coverity.ps.common;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;

import javax.xml.namespace.QName;
import javax.xml.ws.BindingProvider;
import javax.xml.ws.WebServiceException;
import javax.xml.ws.handler.Handler;
import javax.xml.ws.soap.SOAPFaultException;

import com.coverity.cim.ws.ConfigurationService;
import com.coverity.cim.ws.ConfigurationServiceService;
import com.coverity.cim.ws.CovRemoteServiceException_Exception;
import com.coverity.cim.ws.DefectService;
import com.coverity.cim.ws.DefectServiceService;
import com.coverity.cim.ws.DefectStateSpecDataObj;
import com.coverity.cim.ws.MergedDefectDataObj;
import com.coverity.cim.ws.MergedDefectFilterSpecDataObj;
import com.coverity.cim.ws.MergedDefectsPageDataObj;
import com.coverity.cim.ws.PageSpecDataObj;
import com.coverity.cim.ws.ProjectDataObj;
import com.coverity.cim.ws.ProjectFilterSpecDataObj;
import com.coverity.cim.ws.ProjectIdDataObj;
import com.coverity.cim.ws.ProjectSpecDataObj;
import com.coverity.cim.ws.StreamDataObj;
import com.coverity.cim.ws.StreamDefectDataObj;
import com.coverity.cim.ws.StreamDefectFilterSpecDataObj;
import com.coverity.cim.ws.StreamDefectIdDataObj;
import com.coverity.cim.ws.StreamFilterSpecDataObj;
import com.coverity.cim.ws.StreamIdDataObj;
import com.coverity.cim.ws.UserDataObj;
import com.coverity.cim.ws.UserFilterSpecDataObj;
import com.coverity.cim.ws.UserSpecDataObj;
import com.coverity.cim.ws.UsersPageDataObj;
import com.coverity.ps.common.config.ConfigurationManager;

public class CimProxy {
	private static CimProxy instance;
	private String user;
	private String password;
	private String address;
	private int port;
	private ConfigurationService configurationService;
	private DefectService defectService;

	private CimProxy() {
		this.user = ConfigurationManager.getInstance().getUser();
		this.password = ConfigurationManager.getInstance().getPassword();
		this.address = ConfigurationManager.getInstance().getAddress();
		this.port = ConfigurationManager.getInstance().getPort();

		try {
			// build URL
			StringBuilder commonUrl = new StringBuilder("http://");
			commonUrl.append(this.address);
			if (this.port > 0) {
				commonUrl.append(":" + this.port);
			}
			commonUrl.append("/ws/v4");

			// create configuration service instance
			this.configurationService = new ConfigurationServiceService(
					new URL(commonUrl.toString() + "/configurationservice?wsdl"),
					new QName("http://ws.coverity.com/v4",
							"ConfigurationServiceService"))
					.getConfigurationServicePort();
			BindingProvider bindingProvider = (BindingProvider) configurationService;
			bindingProvider.getBinding().setHandlerChain(
					new ArrayList<Handler>(Arrays
							.asList(new ClientAuthenticationHandlerWSS(
									this.user, this.password))));

			// create defect service instance
			this.defectService = new DefectServiceService(new URL(
					commonUrl.toString() + "/defectservice?wsdl"), new QName(
					"http://ws.coverity.com/v4", "DefectServiceService"))
					.getDefectServicePort();
			bindingProvider = (BindingProvider) defectService;
			bindingProvider.getBinding().setHandlerChain(
					new ArrayList<Handler>(Arrays
							.asList(new ClientAuthenticationHandlerWSS(
									this.user, this.password))));

		} catch (SOAPFaultException e) {
			System.err.println(e);
		} catch (WebServiceException e) {
			System.err.println(e);
		} catch (MalformedURLException e) {
			System.err.println(e);
		}
	}

	public static CimProxy getInstance() {
		if (instance == null) {
			instance = new CimProxy();
		}

		return instance;
	}

	public List<StreamDefectDataObj> getAllStreamDefects(List<Long> cids,
			String scope) throws CovRemoteServiceException_Exception {
		StreamDefectFilterSpecDataObj filterSpec = new StreamDefectFilterSpecDataObj();
		filterSpec.setScopePattern(scope);
		filterSpec.setIncludeHistory(true);
		filterSpec.setIncludeDefectInstances(true);
		return getStreamDefects(cids, filterSpec);
	}

	public List<StreamDefectDataObj> getStreamDefects(List<Long> cids,
			StreamDefectFilterSpecDataObj filterSpec)
			throws CovRemoteServiceException_Exception {
		if (configurationService == null || defectService == null) {
			throw new CovRemoteServiceException_Exception(
					"Services are uninitialized", null);
		}

		return this.defectService.getStreamDefects(cids, filterSpec);
	}

	public List<MergedDefectDataObj> getAllMergedDefectsForStreams(
			List<String> names) throws CovRemoteServiceException_Exception {
		return getMergedDefectsForStreams(names,
				new MergedDefectFilterSpecDataObj());
	}

	public List<MergedDefectDataObj> getMergedDefectsForStreams(
			List<String> names, MergedDefectFilterSpecDataObj filterSpec)
			throws CovRemoteServiceException_Exception {
		if (configurationService == null || defectService == null) {
			throw new CovRemoteServiceException_Exception(
					"Services are uninitialized", null);
		}

		List<StreamIdDataObj> streamIds = new ArrayList<StreamIdDataObj>();
		for (String name : names) {
			StreamIdDataObj streamId = new StreamIdDataObj();
			streamId.setName(name);
			streamIds.add(streamId);
		}

		PageSpecDataObj pageSpec = new PageSpecDataObj();
		final int pageSize = 2500;
		pageSpec.setPageSize(pageSize);

		int count = 0;
		int offset = 0;
		MergedDefectsPageDataObj page = null;
		List<MergedDefectDataObj> results = new ArrayList<MergedDefectDataObj>();
		do {
			pageSpec.setStartIndex(offset);
			page = this.defectService.getMergedDefectsForStreams(streamIds,
					filterSpec, pageSpec);
			results.addAll(page.getMergedDefects());

			count += page.getMergedDefects().size();
			offset += pageSize;
		} while (count < page.getTotalNumberOfRecords());

		return results;
	}

	public List<MergedDefectDataObj> getAllMergedDefectsForProject(
			String project) throws CovRemoteServiceException_Exception {
		return getMergedDefectsForProject(project,
				new MergedDefectFilterSpecDataObj());
	}

	public List<MergedDefectDataObj> getMergedDefectsForProject(String project,
			MergedDefectFilterSpecDataObj filterSpec)
			throws CovRemoteServiceException_Exception {
		if (configurationService == null || defectService == null) {
			throw new CovRemoteServiceException_Exception(
					"Services are uninitialized", null);
		}

		ProjectIdDataObj projectId = new ProjectIdDataObj();
		projectId.setName(project);

		PageSpecDataObj pageSpec = new PageSpecDataObj();
		final int pageSize = 2500;
		pageSpec.setPageSize(pageSize);

		int count = 0;
		int offset = 0;
		MergedDefectsPageDataObj page = null;
		List<MergedDefectDataObj> results = new ArrayList<MergedDefectDataObj>();
		do {
			pageSpec.setStartIndex(offset);
			page = this.defectService.getMergedDefectsForProject(projectId,
					filterSpec, pageSpec);
			results.addAll(page.getMergedDefects());

			count += page.getMergedDefects().size();
			offset += pageSize;
		} while (count < page.getTotalNumberOfRecords());

		return results;
	}
	
	public MergedDefectDataObj getMergedDefectForProject(String project, Long cid) throws CovRemoteServiceException_Exception {
		MergedDefectFilterSpecDataObj filterSpec = new MergedDefectFilterSpecDataObj();
		filterSpec.setMinCid(new Long(cid));
		filterSpec.setMaxCid(new Long(cid));
		
		List<MergedDefectDataObj> defects = this.getMergedDefectsForProject(project, filterSpec);
		if(defects.size() == 1) {
			return defects.get(0);
		}
		
		return null;
	}

	public List<UserDataObj> getAllUsers()
			throws CovRemoteServiceException_Exception {
		return this.getUsers(new UserFilterSpecDataObj());
	}

	public List<UserDataObj> getUsers(UserFilterSpecDataObj userFilterSpecDO)
			throws CovRemoteServiceException_Exception {
		if (configurationService == null || defectService == null) {
			throw new CovRemoteServiceException_Exception(
					"Services are uninitialized", null);
		}

		PageSpecDataObj pageSpec = new PageSpecDataObj();
		final int pageSize = 256;
		pageSpec.setPageSize(pageSize);

		int count = 0;
		int offset = 0;
		UsersPageDataObj page = null;
		List<UserDataObj> results = new ArrayList<UserDataObj>();
		do {
			pageSpec.setStartIndex(offset);
			page = this.configurationService.getUsers(userFilterSpecDO,
					pageSpec);
			results.addAll(page.getUsers());

			count += page.getUsers().size();
			offset += pageSize;
		} while (count < page.getTotalNumberOfRecords());

		return results;
	}

	public void updateDefect(Long cid, String pattern,
			DefectStateSpecDataObj defectStateSpec)
			throws CovRemoteServiceException_Exception {
		List<Long> cids = new ArrayList<Long>();
		cids.add(cid);

		StreamDefectFilterSpecDataObj filterSpec = new StreamDefectFilterSpecDataObj();
		filterSpec.setScopePattern(pattern);

		List<StreamDefectDataObj> defects = this.getStreamDefects(cids,
				filterSpec);
		List<Long> iids = new ArrayList<Long>();
		for (StreamDefectDataObj defect : defects) {
			iids.add(defect.getId().getId());
		}

		updateDefectsHelper(iids, pattern, defectStateSpec);
	}

	private void updateDefectsHelper(List<Long> iids, String pattern,
			DefectStateSpecDataObj defectStateSpec)
			throws CovRemoteServiceException_Exception {
		List<StreamDefectIdDataObj> streamDefectIds = new ArrayList<StreamDefectIdDataObj>();
		for (Long iid : iids) {
			StreamDefectIdDataObj streamDefectId = new StreamDefectIdDataObj();
			streamDefectId.setId(iid);
			streamDefectId.setVerNum(551);
			streamDefectIds.add(streamDefectId);
		}

		this.defectService.updateStreamDefects(streamDefectIds, pattern,
				defectStateSpec);
	}

	public List<StreamDataObj> getAllStreams()
			throws CovRemoteServiceException_Exception {
		return getStreams(new StreamFilterSpecDataObj());
	}

	public List<StreamDataObj> getStreams(StreamFilterSpecDataObj specData)
			throws CovRemoteServiceException_Exception {
		return this.configurationService.getStreams(specData);
	}
	
	public ProjectDataObj getProject(String name) throws CovRemoteServiceException_Exception {
		ProjectFilterSpecDataObj specData = new ProjectFilterSpecDataObj();
		specData.setNamePattern(name);
		
		List<ProjectDataObj> projects = this.configurationService.getProjects(specData);
		if(projects.size() == 1) {
			return projects.get(0);
		}
		
		return null;
	}
	
	public List<ProjectDataObj> getProjects(ProjectFilterSpecDataObj specData) throws CovRemoteServiceException_Exception {
		return this.configurationService.getProjects(specData);
	}
	
	public void updateProject(String name, ProjectSpecDataObj specData) throws CovRemoteServiceException_Exception {
		ProjectIdDataObj projectIdDataObj = new ProjectIdDataObj();
		projectIdDataObj.setName(name);
		this.configurationService.updateProject(projectIdDataObj, specData);
	}
	
	public List<String> notify(List<String> userNames, String subject, String message) throws CovRemoteServiceException_Exception {
		return this.configurationService.notify(userNames, subject, message);
	}
	
	public String notify(String userName, String subject, String message) throws CovRemoteServiceException_Exception {
		List<String> userNames = new ArrayList<String>();
		userNames.add(userName);
		List<String> recipients = this.configurationService.notify(userNames, subject, message);
		if(recipients.size() == 1) {
			return recipients.get(0);
		}
		
		return "";
	}
	
	public void createUser(UserSpecDataObj specData) throws CovRemoteServiceException_Exception {
		this.configurationService.createUser(specData);
	}
	
	public void createProject(ProjectSpecDataObj specData) throws CovRemoteServiceException_Exception {
		this.configurationService.createProject(specData);
	}
	
	public static void main(String[] args) {
		try {
			CimProxy cimProxy = CimProxy.getInstance();
			List<String> streams = new ArrayList<String>();
			streams.add("Glenlivet_C");
			System.out.println("Starting...");
			long startTime = System.currentTimeMillis();
			List<MergedDefectDataObj> results = cimProxy
					.getAllMergedDefectsForStreams(streams);
			long millis = System.currentTimeMillis() - startTime;
			
			String time = String.format("%d min, %d sec", 
			    TimeUnit.MILLISECONDS.toMinutes(millis),
			    TimeUnit.MILLISECONDS.toSeconds(millis) - 
			    TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(millis))
			);
			System.out.println("time=" + time);
			System.out.println("count=" + results.size());
			/*
			 * DefectStateSpecDataObj defectStateSpec = new
			 * DefectStateSpecDataObj(); defectStateSpec.setSeverity("Major");
			 * cimProxy.updateDefect(10024L, "*\/*", defectStateSpec);
			 */
		} catch (CovRemoteServiceException_Exception e) {
			e.printStackTrace();
		}
	}
}
