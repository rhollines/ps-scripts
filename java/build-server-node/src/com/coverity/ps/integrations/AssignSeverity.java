package com.coverity.ps.integrations;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import com.coverity.ps.common.CimProxy;
import com.coverity.ws.v4.DefectStateSpecDataObj;
import com.coverity.ws.v4.MergedDefectDataObj;
import com.coverity.ws.v4.ProjectDataObj;
import com.coverity.ws.v4.StreamDataObj;

/**
 * Sets the severity for defects in a project or stream
 */
public class AssignSeverity implements Integration {
	private boolean isDryRun;
	private String streamName;
	private String projectName;
	private String configFile;
	
	/**
	 * Sets the severity for defects in a project or stream
	 * 
	 * @param name stream or project name
	 * @param isProject true if project name, stream otherwise
	 * @param configFile path to the XML mapping file
	 * @param isDryRun
	 */
	public AssignSeverity(String name, boolean isProject, String configFile, boolean isDryRun) {
		this.isDryRun = isDryRun;
		this.configFile = configFile;
		if(isProject) {
			this.projectName = name;
			this.streamName = "";
		}
		else {
			this.projectName = "";
			this.streamName = name;
		}
	}
	
	public boolean execute() throws Exception {
		CimProxy cimProxy = CimProxy.getInstance();
		Map<String, String> defectMapping = getDefectMapping();
		
		// get streams
		List<String> streams = new ArrayList<String>();
		if(projectName != null && projectName.length() > 0) {
			ProjectDataObj project = cimProxy.getProject(this.projectName);
			for(StreamDataObj stream : project.getStreamLinks()) {
				streams.add(stream.getId().getName());
			}
		}
		else {
			streams.add(this.streamName);
		}
		
		// update defects
		List<MergedDefectDataObj> defects = cimProxy.getAllMergedDefectsForStreams(streams);
		for(MergedDefectDataObj defect : defects) {
			String severity = defect.getSeverity();
			final String checkerName = defect.getCheckerName();
			if(severity.equals("Unspecified") && defectMapping.containsKey(checkerName)) {
				severity = defectMapping.get(checkerName);
				if(!this.isDryRun) {
					DefectStateSpecDataObj defectStateSpec = new DefectStateSpecDataObj();
					defectStateSpec.setSeverity(severity);
					if(this.projectName != null && this.projectName.length() > 0) {
						cimProxy.updateDefect(defect.getCid(), this.projectName + "/*", defectStateSpec);
					}
					else {
						cimProxy.updateDefect(defect.getCid(), "*/" + this.streamName, defectStateSpec);
					}
					System.out.println("set: defect=" + defect.getCid() + ", severity=" + severity);
				}
				else {
					System.out.println("DRY_RUN - set: defect=" + defect.getCid() + ", severity=" + severity);
				}
			}
		}
		
		return true;
	}
	
	private Map<String, String> getDefectMapping() throws Exception {
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory
				.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(this.configFile);
		
		// get checker mapping
		Map<String, String> defectMapping = new HashMap<String, String>();
		NodeList checkerNode = document.getDocumentElement().getElementsByTagName("checker");
		for(int i = 0; i < checkerNode.getLength(); i++) {
			Element checkerElem = (Element) checkerNode.item(i);
			String checker = checkerElem.getAttribute("name");
			String severity = checkerElem.getAttribute("severity");
			defectMapping.put(checker, severity);	
		}
		
		return defectMapping;
	}

	/*
	 * Main command line driver. Please see class constructor for required arguments.
	 */
	public static void main(String[] args) {
		try {
			if(args.length == 4) {
				AssignSeverity assignSeverity = new AssignSeverity(
						args[0], 
						args[1].equalsIgnoreCase("true"),
						args[2],
						args[3].equalsIgnoreCase("true"));
				assignSeverity.execute();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
