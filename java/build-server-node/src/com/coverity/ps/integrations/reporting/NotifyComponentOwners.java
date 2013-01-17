package com.coverity.ps.integrations.reporting;

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
import com.coverity.ps.integrations.Integration;
import com.coverity.ws.v4.MergedDefectDataObj;

/**
 * Creates a summary e-mail report of defects that have been detected in the
 * last N number of days based upon component.
 */
public class NotifyComponentOwners extends ComponentDefectReport implements
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
	public NotifyComponentOwners(String project, int days, String configFile,
			boolean isDryRun) {
		super(project, days, isDryRun);
		this.configFile = configFile;
	}

	public boolean execute() throws Exception {
		Map<String, List<MergedDefectDataObj>> defectsByComponent = getProjectDefectsByComponent();
		// System.out.println(defectsByComponent.size() + " component(s) with new defects");
		for (Map.Entry<String, List<MergedDefectDataObj>> componentDefectValues : defectsByComponent
				.entrySet()) {
			List<MergedDefectDataObj> componentDefects = componentDefectValues
					.getValue();
			final String componentName = (String) componentDefectValues
					.getKey();

			// TODO:
			Map<String, List<String>> componentUsers = getUserMapping();
			// System.out.println("Component=" + componentDefectValues.getKey());
			if (componentDefects.size() > 0) {
				StringBuilder html = new StringBuilder();
				html.append("<html><body><p>The following defects have been detected in the ");
				html.append(componentName);
				html.append(" component within the past ");
				if (days == 1) {
					html.append("24 hours.</p>");
				} else {
					html.append(days + " days.</p>");
				}

				Map<String, List<MergedDefectDataObj>> defectsByChecker = new HashMap<String, List<MergedDefectDataObj>>();
				for (MergedDefectDataObj componentDefect : componentDefects) {
					// System.out.println("cid=" + componentDefect.getCid() +
					// ", component=" + componentName);
					List<MergedDefectDataObj> checkerDefects = (List<MergedDefectDataObj>) defectsByChecker
							.get(componentDefect.getCheckerName());
					if (checkerDefects == null) {
						checkerDefects = new ArrayList<MergedDefectDataObj>();
						defectsByChecker.put(componentDefect.getCheckerName(),
								checkerDefects);
					}
					checkerDefects.add(componentDefect);
				}

				// process checker information for current component
				html.append("<style type='text/css'>");
				html.append("td.datacellone {");
				html.append("	background-color: #F2F2F2; color: black;");
				html.append("}");
				html.append("td.datacelltwo {");
				html.append("	background-color: #FFFFFF; color: black;");
				html.append("}");
				html.append("td.datacellthree {");
				html.append("	background-color: #BDBDBD; color: black;");
				html.append("}");
				html.append("</style>");
				html.append("<br/><table border=\"1\" cellpadding=\"3\"><tr> <th>Checker</th> <th>New</th> <th>Outstanding</th> <th>Resolved</th></tr>");

				// column totals
				int totalNew = 0;
				int totalOutstanding = 0;
				int totalResolved = 0;

				int i = 0;
				for (Map.Entry<String, List<MergedDefectDataObj>> checkerDefectEntries : defectsByChecker
						.entrySet()) {
					List<MergedDefectDataObj> checkerDefects = checkerDefectEntries
							.getValue();
					final String checkerName = (String) checkerDefectEntries
							.getKey();
					int checkerNew = 0;
					int checkerOutstanding = 0;
					int checkerResolved = 0;
					for (MergedDefectDataObj checkerDefect : checkerDefects) {
						// new
						if (checkerDefect.getStatus().equals("New")) {
							checkerNew++;
						}
						// outstanding
						else if (checkerDefect.getStatus().equals("Triaged")) {
							checkerOutstanding++;
						}
						// resolved: note assume dismissed and fixed
						else if (checkerDefect.getStatus().equals("Dismissed")
								|| checkerDefect.getStatus().equals("Fixed")) {
							checkerResolved++;
						}
					}

					/*System.out.println("\tchecker=" + checkerName + ", new="
							+ checkerNew + ", outstanding="
							+ checkerOutstanding + ", resolved="
							+ checkerResolved);*/

					String td;
					if (i % 2 == 0) {
						td = "<td class='datacellone'>";
					} else {
						td = "<td class='datacelltwo'>";
					}

					html.append("<tr>");
					html.append(td);
					html.append(checkerName);
					html.append("</td>");
					html.append(td);
					html.append(checkerNew);
					html.append("</td>");
					html.append(td);
					html.append(checkerOutstanding);
					html.append("</td>");
					html.append(td);
					html.append(checkerResolved);
					html.append("</td></tr>");

					// update
					totalNew += checkerNew;
					totalOutstanding += checkerOutstanding;
					totalResolved += checkerResolved;
					i++;
				}

				// totals
				String td = "<td class='datacellthree'>";
				html.append("<tr>");
				html.append(td);
				html.append("Total</td>");
				html.append(td);
				html.append(totalNew);
				html.append("</td>");
				html.append(td);
				html.append(totalOutstanding);
				html.append("</td>");
				html.append(td);
				html.append(totalResolved);
				html.append("</td></tr>");
				html.append("</table></body></html>");

				// System.out.println("Raw HTML=" + html);
					
				// e-mail to component owners
				if (componentUsers.containsKey(componentName)) {
					List<String> notifyUsers = (List<String>) componentUsers
							.get(componentName);
					for (String notifyUser : notifyUsers) {
						if (this.isDryRun) {
							System.out.println("DRY-RUN recipient="
									+ notifyUser + ", html=" + html);
						} else {
							final String subject = "New defects assigned to you in Coverity";
							String recipient = CimProxy.getInstance().notify(notifyUser, subject, html.toString());
							if (recipient.length() > 0) {
								System.out.println("e-mail sucessfully sent to " + recipient);
							}
							else {
								System.out.println("*** Unable to e-mail " + recipient + " ***");
							}
						}
					}
				} else {
					System.out.println("*** Unable to find users assigned to component \"" + componentName + "\" ***");
				}
			} else {
				System.out.println("\tNo new defects");
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
				NotifyComponentOwners notifyOwners = new NotifyComponentOwners(
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
								+ NotifyComponentOwners.class.getName()
								+ " <project-name> <num-days> <comp-config-file> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
