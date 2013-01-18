package com.coverity.ps.integrations.reporting;

import java.text.SimpleDateFormat;
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
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ps.integrations.Integration;
import com.coverity.ws.v4.MergedDefectDataObj;

/**
 * Creates a summary e-mail report of defects that have been detected in the
 * last N number of days based upon component.
 */
public class NotifyComponentOwnersSummary extends ComponentDefectReport implements Integration {
	private String configFile;

	/**
	 * Constructor
	 * 
	 * @param project
	 *            project name
	 * @param days
	 *            defects detected in the past N number of days
	 * @param isDryRun
	 */
	public NotifyComponentOwnersSummary(String project, int days, String configFile, boolean isDryRun) {
		super(project, days, isDryRun);
		this.configFile = configFile;
	}

	public boolean execute() throws Exception {
		// fetch component to user mapping and defects 
		Map<String, List<String>> userComponents = getUserMapping();
		Map<String, List<MergedDefectDataObj>> defectsByComponent = getProjectDefectsByComponent();
		
		System.out.println("------------------");
		
		// System.out.println(defectsByComponent.size() + " component(s) with new defects");
		for (Map.Entry<String, List<MergedDefectDataObj>> componentDefectValues : defectsByComponent.entrySet()) {
			List<MergedDefectDataObj> componentDefects = componentDefectValues.getValue();
			final String componentName = (String) componentDefectValues.getKey();
			
			int componentNew = 0;
			int componentTriaged = 0;
			int componentResolved = 0;
			
			for (MergedDefectDataObj componentDefect : componentDefects) {
				// new
				if (componentDefect.getStatus().equals("New")) {
					componentNew++;
				}
				// outstanding
				else if (componentDefect.getStatus().equals("Triaged")) {
					componentTriaged++;
				}
				// resolved: note assume dismissed and fixed
				else if (componentDefect.getStatus().equals("Dismissed")
						|| componentDefect.getStatus().equals("Fixed")) {
					componentResolved++;
				}
			}
			
			final int componentOutstanding = componentNew + componentTriaged;
			final String asOfDate = new SimpleDateFormat("MM/dd/yy HH:mm:ss").format(this.lastDetected.toGregorianCalendar().getTime());
			
			System.out.println("component=" + componentName + ", as-of-date=" + asOfDate + ", outstanding=" + componentOutstanding);
			
			StringBuilder html = new StringBuilder();
			html.append("<html><p>As of ");
			html.append(asOfDate); // set as-of-date
			if(componentOutstanding == 1) {
				html.append(". There is ");
			}
			else {
				html.append(". There are ");
			}
			html.append(componentOutstanding);
			
			if(componentOutstanding == 1) {
				html.append(" Coverity defect in the \"");
			}
			else {
				html.append(" Coverity defects in the \"");
			}
			html.append(componentName);
			
			StringBuilder projectUrl = new StringBuilder("http://");
			projectUrl.append(ConfigurationManager.getInstance().getAddress());
			projectUrl.append(':');
			projectUrl.append(ConfigurationManager.getInstance().getPort());
			projectUrl.append("/sourcebrowser.htm?projectId=");
			projectUrl.append(this.projectId);
			
			html.append("\" component.</p><p>Please check the CIM for the ");
			html.append("<a href='");
			html.append(projectUrl);
			html.append("'>entire</a>");
			html.append(" defect list.</p></html>");
			
			System.out.println("Raw HTML=" + html);
			
			// e-mail to component owners
			if(userComponents.containsKey(componentName)) {
				final List<String> users = (List<String>)userComponents.get(componentName);
				if(this.isDryRun) {
					System.out.println("Recipients that would have received e-mail(s): " + users);
				}
				else {
					final String subject = "New Coverity defects";
					List<String> recipients = CimProxy.getInstance().notify(users, subject, html.toString());
					for(String recipient : recipients) {
						System.out.println("e-mail sucessfully sent to " + recipient);
					}
				}
			}
			
			System.out.println("------------------");
		}
		
		return true;
	}

	private Map<String, List<String>> getUserMapping() throws Exception {
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(this.configFile);

		// get component mapping
		Map<String, List<String>> userMapping = new HashMap<String, List<String>>();
		NodeList componentNode = document.getDocumentElement().getElementsByTagName("component");
		for (int i = 0; i < componentNode.getLength(); i++) {
			Element compElem = (Element) componentNode.item(i);
			final String componentName = compElem.getAttribute("name");
			// build list of users
			List<String> users = new ArrayList<String>();
			NodeList userNodes = compElem.getElementsByTagName("user");
			for (int j = 0; j < userNodes.getLength(); j++) {
				Element userNode = (Element) userNodes.item(j);
				users.add(userNode.getTextContent());
			}
			// add entry
			userMapping.put(componentName, users);
		}

		return userMapping;
	}

	/*
	 * Main command line driver. Please see class constructor for required
	 * arguments.
	 */
	public static void main(String[] args) {
		try {
			if (args.length == 4) {
				NotifyComponentOwnersSummary notifyOwners = new NotifyComponentOwnersSummary(
						args[0], Integer.parseInt(args[1]), args[2],
						args[3].equalsIgnoreCase("true"));
				if (notifyOwners.execute()) {
					System.out.println("\nSuccessful!");
				} else {
					System.out.println("\n*** Unsuccessful ***");
				}
			} else {
				System.err.println("This program notifies component owners of new defects that have been detected in the last N number of days.");
				System.err.println("usage: java "
								+ NotifyComponentOwnersSummary.class.getName()
								+ " <project-name> <num-days> <comp-config-file> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
