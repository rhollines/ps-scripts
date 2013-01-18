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
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.MergedDefectDataObj;
import com.coverity.ws.v4.MergedDefectFilterSpecDataObj;
import com.coverity.ws.v4.ProjectDataObj;

/**
 * Creates a summary e-mail report of defects that have been detected in the
 * last N number of days based upon component.
 */
public class NotifyComponentManagers {
	private String projectName;
	private int days;
	private List<String> users = new ArrayList<String>();
	private boolean isDryRun;
	
	/**
	 * Constructor
	 * 
	 * @param project
	 *            project name
	 * @param days
	 *            defects detected in the past N number of days
	 * @param isDryRun
	 */
	public NotifyComponentManagers(String projectName, int days, String managerList, boolean isDryRun) {
		this.projectName = projectName;
		this.days = days;
		this. isDryRun = isDryRun;
		
		// get list of user to e-mail
		String[] managers = managerList.split(",");
		for(String manager : managers) {
			this.users.add(manager);
		}
	}

	private List<MergedDefectDataObj> getProjectDefects() throws CovRemoteServiceException_Exception, DatatypeConfigurationException {
		// get project id
		ProjectDataObj projectData = CimProxy.getInstance().getProject(
				projectName);
		if (projectData != null) {
			// calculate as-of date
			final long oneDay = 1000 * 60 * 60 * 24;
			GregorianCalendar calendar = new GregorianCalendar();
			calendar.setTimeInMillis(System.currentTimeMillis() - this.days
					* oneDay);
			XMLGregorianCalendar lastDetected = DatatypeFactory.newInstance()
					.newXMLGregorianCalendar(calendar);

			System.out.println("as-of-date=" + lastDetected);

			// get defects
			MergedDefectFilterSpecDataObj projectFilter = new MergedDefectFilterSpecDataObj();
			projectFilter.setFirstDetectedStartDate(lastDetected);

			return CimProxy.getInstance().getMergedDefectsForProject(
					this.projectName, projectFilter);
		}

		return null;
	}

	public boolean execute() throws Exception {
		List<MergedDefectDataObj> componentDefects = getProjectDefects();
		if (componentDefects != null) {
			StringBuilder html = new StringBuilder();
			html.append("<html><body><p>The following defects have been detected in the ");
			html.append(this.projectName);
			html.append(" project within the past ");
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
			html.append("<br/><table border=\"1\" cellpadding=\"3\"><tr> <th>Checker</th> <th>New</th> <th>Outstanding</th> <th>Resolved</th> <th>Total</th></tr>");

			// column totals
			int totalNew = 0;
			int totalOutstanding = 0;
			int totalResolved = 0;
			int totalTotal = 0;

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

				/*
				 * System.out.println("\tchecker=" + checkerName + ", new=" +
				 * checkerNew + ", outstanding=" + checkerOutstanding +
				 * ", resolved=" + checkerResolved);
				 */

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
				html.append("</td>");
				html.append(td);
				html.append(checkerDefects.size());
				html.append("</td></tr>");
				
				// update
				totalNew += checkerNew;
				totalOutstanding += checkerOutstanding;
				totalResolved += checkerResolved;
				totalTotal += checkerDefects.size();
				
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
			html.append("</td>");
			html.append(td);
			html.append(totalTotal);
			html.append("</td></tr>");
			html.append("</table></body></html>");

			System.out.println("Raw HTML=" + html);
			
			// e-mail to component owners
			if(this.isDryRun) {
				System.out.println("Recipients that would have received e-mail(s): " + this.users);
			}
			else {
				final String subject = "New Coverity defects";
				List<String> recipients = CimProxy.getInstance().notify(this.users, subject, html.toString());
				for(String recipient : recipients) {
					System.out.println("e-mail sucessfully sent to " + recipient);
				}
			}

		}

		return true;
	}

	/*
	 * Main command line driver. Please see class constructor for required
	 * arguments.
	 */
	public static void main(String[] args) {
		try {
			if (args.length == 4) {
				NotifyComponentManagers notifyOwners = new NotifyComponentManagers(
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
								+ NotifyComponentManagers.class.getName()
								+ " <project-name> <num-days> <users-to-email> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
