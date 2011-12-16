package com.coverity.ps.integrations.bugtracking;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import com.coverity.cim.ws.DefectStateSpecDataObj;
import com.coverity.cim.ws.MergedDefectDataObj;
import com.coverity.ps.common.CimProxy;
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ps.common.plugins.bugtracking.BugTracking;
import com.coverity.ps.common.plugins.bugtracking.Bugzilla;
import com.coverity.ps.common.plugins.scm.ScmPlugin;

public class ExportDefect {
	private String inputFile;
	private boolean isDryRun;
	private String project;
	private long cid;
	
	public ExportDefect(String inputFile, boolean isDryRun) throws Exception {
		this.inputFile = inputFile;
		this.isDryRun = isDryRun;
		parseInputFile();
	}
	
	private void parseInputFile() throws Exception {
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(inputFile);

		// get mergedDefect tag
		NodeList projectDefectNode = document.getDocumentElement()
				.getElementsByTagName("project");
		if (projectDefectNode.getLength() != 1) {
			System.err
					.println("Invalid or missing projectDefect configuration tag!");
		}
		Element projectDefectElem = (Element) projectDefectNode.item(0);
		this.project = projectDefectElem.getTextContent();

		NodeList mergedDefectNode = document.getDocumentElement()
				.getElementsByTagName("cxp:mergedDefect");
		if (mergedDefectNode.getLength() != 1) {
			System.err.println("Invalid or missing mergedDefect configuration tag!");
		}
		Element mergedDefectElem = (Element) mergedDefectNode.item(0);

		NodeList cidNode = mergedDefectElem.getElementsByTagName("cid");
		if (cidNode.getLength() != 1) {
			System.err.println("Invalid or missing cid configuration tag!");
		}
		Element cidElem = (Element) cidNode.item(0);
		this.cid = Integer.parseInt(cidElem.getTextContent());
	}
	
	public void createBug() throws Exception {
		ConfigurationManager configurationManager = ConfigurationManager.getInstance();

		// load plug-in
		Class<BugTracking> bugTrackingClass = (Class<BugTracking>) Class.forName(configurationManager.getBugTrackingClass());
		if(bugTrackingClass == null) {
			System.err.println("Unable load SCM plugin: " + configurationManager.getScmClass() + "!");
			return;
		}
		
		// fetch defect
		CimProxy cimProxy = CimProxy.getInstance();
		MergedDefectDataObj defect = cimProxy.getMergedDefectForProject(this.project, this.cid);
		if(defect != null) {
			BugTracking bugTracking = (BugTracking)bugTrackingClass.newInstance();
			String result = bugTracking.createBug(this.project, defect, this.isDryRun);
			if(result != null && result.length() > 0) {
				DefectStateSpecDataObj defectStateSpec = new DefectStateSpecDataObj();
				defectStateSpec.setExternalReference(result);
				cimProxy.updateDefect(this.cid, this.project + "/*", defectStateSpec);
			}
		}
	}
	
	public static void main(String[] args) {
		try {
			if(args.length == 2) {
				ExportDefect exportDefect = new ExportDefect(args[0], args[1].equalsIgnoreCase("true"));
				exportDefect.createBug();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
