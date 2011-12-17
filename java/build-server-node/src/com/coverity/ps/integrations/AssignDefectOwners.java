package com.coverity.ps.integrations;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.coverity.cim.ws.DefectStateSpecDataObj;
import com.coverity.cim.ws.MergedDefectDataObj;
import com.coverity.cim.ws.StreamDataObj;
import com.coverity.cim.ws.StreamFilterSpecDataObj;
import com.coverity.cim.ws.UserDataObj;
import com.coverity.ps.common.CimProxy;
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ps.common.config.ScmStreamData;
import com.coverity.ps.common.plugins.scm.ScmPlugin;

public class AssignDefectOwners implements Integration {
	private boolean isDryRun;

	public AssignDefectOwners(boolean isDryRun) {
		this.isDryRun = isDryRun;
	}
	
	public boolean execute() throws Exception {
		ConfigurationManager configurationManager = ConfigurationManager.getInstance();
		CimProxy cimProxy = CimProxy.getInstance();
		
		List<ScmStreamData> scmStreams = configurationManager.getScmStreamData();
		for(ScmStreamData scmStreamData : scmStreams) {
			// check streams
			StreamFilterSpecDataObj streamFilter = new StreamFilterSpecDataObj();
			streamFilter.setNamePattern(scmStreamData.getName());
			List<StreamDataObj> stream = cimProxy.getStreams(streamFilter);
			if(stream.size() != 1) {
				System.err.println("Unable to find or uniquely identify stream: " + scmStreamData.getName() + "!");
				return false;
			}
			
			// get users
			Map<String, Boolean> userMap = new HashMap<String, Boolean>();
			List<UserDataObj> userList = cimProxy.getAllUsers();
			for(UserDataObj user : userList) {
				userMap.put(user.getUsername(), user.isDisabled());
			}
			
			// get defects
			List<String> streams = new ArrayList<String>();
			streams.add(scmStreamData.getName());
			List<MergedDefectDataObj> defects = cimProxy.getAllMergedDefectsForStreams(streams);
			
			// load plug-in
			Class<ScmPlugin> scmClass = (Class<ScmPlugin>) Class.forName(configurationManager.getScmClass());
			if(scmClass == null) {
				System.err.println("Unable load SCM plugin: " + configurationManager.getScmClass() + "!");
				return false;
			}
			
			// process defects
			if(this.isDryRun) {
				System.out.println("DRY-RUN - stream: " + scmStreamData.getName()
						+ "; processing " + defects.size() + " defect(s)");
			}
			ScmPlugin scm = (ScmPlugin)scmClass.newInstance();
			for(MergedDefectDataObj defect : defects) {
				if(defect.getStatus().equals("New") && defect.getOwner().equals("Unassigned")) {
					final String coverityPath = defect.getFilePathname();
					final String stripPath = scmStreamData.getCimStripPath();
					final String prependPath = scmStreamData.getLocalPrependPath();
					
					StringBuffer localfilePath = new StringBuffer();
					if(coverityPath.startsWith(stripPath)) {
						localfilePath.append(coverityPath.substring(stripPath.length()));
						localfilePath.insert(0, prependPath);
					}
					else {
						localfilePath.append(coverityPath);
					}
					
					String owner = scm.getFileOwner(localfilePath.toString());
					if(owner != null && owner.length() > 0) {
						Boolean isDisabled = userMap.get(owner);
						if(isDisabled != null && !isDisabled.booleanValue()) {
							System.out.println("\tassigning defect " + defect.getCid() + " to " + owner + "; file=" + localfilePath);
							// update defect owner
							if(!this.isDryRun) {
								DefectStateSpecDataObj defectStateSpec = new DefectStateSpecDataObj();
								defectStateSpec.setOwner(owner);
								cimProxy.updateDefect(defect.getCid(), "*/"+ scmStreamData.getName(), defectStateSpec);
							}
						}
						else {
							System.out.println("\t*** unable to assign defects to " + owner + ", this user is not in the CIM or might be disabled ***");
						}
					}
					else {
						System.out.println("\t*** unable to owner for file=" + localfilePath + " ***");
					}
				}
			}
		}
		
		return true;
	}
	
	public static void main(String[] args) {
		try {
			if(args.length == 1) {
				AssignDefectOwners assignDefectOwners = new AssignDefectOwners(args[0].equalsIgnoreCase("true"));
				if(assignDefectOwners.execute()) {
					System.out.println("\nSuccessful!");
				}
				else {
					System.out.println("\n*** Unsuccessful ***");
				}
			}
			else {
				System.err.println("This program assigns defects to the people who last modified a given file.");
				System.err.println("usage: java " + AssignDefectOwners.class.getName() + " <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
