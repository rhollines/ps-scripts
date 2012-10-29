// (c) 2011 Coverity, Inc. All rights reserved worldwide.

package com.coverity.ps.common;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import javax.xml.namespace.QName;
import javax.xml.ws.BindingProvider;
import javax.xml.ws.WebServiceException;
import javax.xml.ws.handler.Handler;
import javax.xml.ws.soap.SOAPFaultException;

import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ws.v4.ConfigurationService;
import com.coverity.ws.v4.ConfigurationServiceService;
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.DefectService;
import com.coverity.ws.v4.DefectServiceService;
import com.coverity.ws.v4.DefectStateSpecDataObj;
import com.coverity.ws.v4.MergedDefectDataObj;
import com.coverity.ws.v4.MergedDefectFilterSpecDataObj;
import com.coverity.ws.v4.MergedDefectsPageDataObj;
import com.coverity.ws.v4.PageSpecDataObj;
import com.coverity.ws.v4.ProjectDataObj;
import com.coverity.ws.v4.ProjectFilterSpecDataObj;
import com.coverity.ws.v4.ProjectIdDataObj;
import com.coverity.ws.v4.ProjectSpecDataObj;
import com.coverity.ws.v4.RoleAssignmentDataObj;
import com.coverity.ws.v4.SnapshotFilterSpecDataObj;
import com.coverity.ws.v4.SnapshotIdDataObj;
import com.coverity.ws.v4.StreamDataObj;
import com.coverity.ws.v4.StreamDefectDataObj;
import com.coverity.ws.v4.StreamDefectFilterSpecDataObj;
import com.coverity.ws.v4.StreamDefectIdDataObj;
import com.coverity.ws.v4.StreamFilterSpecDataObj;
import com.coverity.ws.v4.StreamIdDataObj;
import com.coverity.ws.v4.StreamSpecDataObj;
import com.coverity.ws.v4.UserDataObj;
import com.coverity.ws.v4.UserFilterSpecDataObj;
import com.coverity.ws.v4.UserSpecDataObj;
import com.coverity.ws.v4.UsersPageDataObj;

/**
 * Java wrapper around the CIM SOAP APIs
 */
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
		boolean empty = false;
		do {
			pageSpec.setStartIndex(offset);
			page = this.defectService.getMergedDefectsForStreams(streamIds,
					filterSpec, pageSpec);
			results.addAll(page.getMergedDefects());
			
			empty = page.getMergedDefects().size() == 0;
			if(!empty) {
				count += page.getMergedDefects().size();
				offset += pageSize;
			}
		} while (count < page.getTotalNumberOfRecords() && !empty);

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
		boolean empty = false;
		do {
			pageSpec.setStartIndex(offset);
			page = this.defectService.getMergedDefectsForProject(projectId,
					filterSpec, pageSpec);
			results.addAll(page.getMergedDefects());

			empty = page.getMergedDefects().size() == 0;
			if(!empty) {
				count += page.getMergedDefects().size();
				offset += pageSize;
			}
		} while (count < page.getTotalNumberOfRecords() && !empty);

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
		boolean empty = false;
		do {
			pageSpec.setStartIndex(offset);
			page = this.configurationService.getUsers(userFilterSpecDO,
					pageSpec);
			results.addAll(page.getUsers());

			empty = page.getUsers().size() == 0;
			if(!empty) {
				count += page.getUsers().size();
				offset += pageSize;
			}
		} while (count < page.getTotalNumberOfRecords() && !empty);

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
	
	public void createProject(String projectName, List<String> streamNames) throws CovRemoteServiceException_Exception {
		ProjectSpecDataObj specData = new ProjectSpecDataObj();
		specData.setName(projectName);
		List<StreamIdDataObj> streams = specData.getStreams();
		for(String streamName : streamNames) {
			StreamIdDataObj streamId = new StreamIdDataObj();
			streamId.setName(streamName);
			streams.add(streamId);
		}
		createProject(specData);
	}
	
	public void createProject(ProjectSpecDataObj specData) throws CovRemoteServiceException_Exception {
		this.configurationService.createProject(specData);
	}
	
	public void createStream(StreamSpecDataObj specData) throws CovRemoteServiceException_Exception {
		this.configurationService.createStream(specData);
	}
	
	public void deleteSnapshot(Long id) throws CovRemoteServiceException_Exception {
		SnapshotIdDataObj snapshotIdDataObj = new SnapshotIdDataObj();
		snapshotIdDataObj.setId(id);
		this.configurationService.deleteSnapshot(snapshotIdDataObj);
	}
	
	public List<SnapshotIdDataObj> getSnapshotsForStream(String name, SnapshotFilterSpecDataObj filterSpec) throws CovRemoteServiceException_Exception {
		StreamIdDataObj streamId = new StreamIdDataObj();
		streamId.setName(name);
		return this.configurationService.getSnapshotsForStream(streamId, filterSpec);
	}
	
	public static void main(String[] args) {
		try {
			CimProxy cimProxy = CimProxy.getInstance();
			List<UserDataObj> users = cimProxy.getAllUsers();
			for(UserDataObj user : users) {
				System.out.println("user=" + user.getUsername());
			}
			System.out.println("done.");
		} catch (CovRemoteServiceException_Exception e) {
			e.printStackTrace();
		}
	}
}
