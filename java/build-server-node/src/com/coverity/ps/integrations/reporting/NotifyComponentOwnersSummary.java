package com.coverity.ps.integrations.reporting;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import com.coverity.ps.common.CimProxy;
import com.coverity.ps.integrations.Integration;
import com.coverity.ws.v4.ComponentMetricsDataObj;
import com.coverity.ws.v4.MergedDefectDataObj;

/**
 * Creates a summary e-mail report of defects that have been detected in the
 * last N number of days based upon component.
 */
public class NotifyComponentOwnersSummary extends ComponentDefectReport implements
		Integration {
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
		// component to user mapping
		Map<String, List<String>> userComponents = getUserMapping();
		
		List<String> components = new ArrayList<String>();
		for (Entry<String, List<String>> userComponent : userComponents.entrySet()) {
			final String componentName = this.projectName + '.' + userComponent.getKey();
			components.add(componentName);
		}
		
		List<ComponentMetricsDataObj> componentMerics = CimProxy.getInstance().getComponentMetricsForProject(this.projectName, components);
		for(ComponentMetricsDataObj componentMeric : componentMerics) {
			final String componentName = componentMeric.getComponentId().getName().substring(componentMeric.getComponentId().getName().lastIndexOf('.') + 1);
			
			String numDays;
			if (days == 1) {
				numDays = "1 day";
			} else {
				numDays = days + " days";
			}
			System.out.println("component=" + componentName + ", day(s)=" + numDays + ", total=" + componentMeric.getTotalCount());
			
			// TODO: send e-mail
			List<String> componentUsers = userComponents.get(componentName);
			for(String componentUser : componentUsers) {
				System.out.println("\te-mail=" + componentUser);
			}
		}
		
		return true;
	}

	private Map<String, List<String>> getUserMapping() throws Exception {
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory
				.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(this.configFile);

		// get checker mapping
		Map<String, List<String>> userMapping = new HashMap<String, List<String>>();
		NodeList checkerNode = document.getDocumentElement()
				.getElementsByTagName("component");
		for (int i = 0; i < checkerNode.getLength(); i++) {
			Element compElem = (Element) checkerNode.item(i);
			final String checkerName = compElem.getAttribute("name");
			// build list of users
			List<String> users = new ArrayList<String>();
			NodeList userNodes = compElem.getElementsByTagName("user");
			for (int j = 0; j < userNodes.getLength(); j++) {
				Element userNode = (Element) userNodes.item(j);
				users.add(userNode.getTextContent());
			}

			// add entry
			userMapping.put(checkerName, users);
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
				System.err
						.println("This program notifies component owners of new defects that have been detected in the last N number of days.");
				System.err
						.println("usage: java "
								+ NotifyComponentOwnersSummary.class.getName()
								+ " <project-name> <num-days> <comp-config-file> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
