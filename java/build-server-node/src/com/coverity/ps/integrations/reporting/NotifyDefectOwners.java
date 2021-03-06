package com.coverity.ps.integrations.reporting;

import java.util.List;
import java.util.Map;

import com.coverity.ps.common.CimProxy;
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ps.integrations.Integration;
import com.coverity.ws.v4.MergedDefectDataObj;

/**
 * Creates an e-mail report of defects that have been detected in the 
 * last N number of days. Sends an unique e-mail to each defect owner.
 */
public class NotifyDefectOwners extends UserDefectReport implements Integration {
	/**
	 * Constructor
	 * 
	 * @param project project name
	 * @param days defects detected in the past N number of days
	 * @param isDryRun
	 */
	public NotifyDefectOwners(String project, int days, boolean isDryRun) {
		super(project, days, isDryRun);
	}

	public boolean execute() throws Exception {
		ConfigurationManager configurationManager = ConfigurationManager
				.getInstance();
		Map<String, List<MergedDefectDataObj>> defectsByUser = getProjectDefectsByOwner();
		System.out.println(defectsByUser.size() + " user(s) with new defects");
		for (Map.Entry<String, List<MergedDefectDataObj>> userDefectValues : defectsByUser.entrySet()) {
			List<MergedDefectDataObj> userDefects = userDefectValues.getValue();
			if (userDefects.size() > 0 && userDefectValues.getKey() != UNASSIGNED_OWNER_NAME) {
				StringBuilder html = new StringBuilder();
				html.append("<html><body><p>The following ");
				if (userDefects.size() == 1) {
					html.append("defect was");
				} else {
					html.append(userDefects.size() + " defects were");
				}
				html.append(" assigned to you in project ");
				html.append(this.projectName);
				html.append(" within the past ");
				if (days == 1) {
					html.append("24 hours.</p>");
				} else {
					html.append(days + " days.</p>");
				}

				html.append("<br/><table border=\"1\"><tr><th>CID</th><th>Checker</th><th>File</th></tr>");
				for (MergedDefectDataObj defect : userDefects) {
					StringBuilder defectUrl = new StringBuilder("http://");
					defectUrl.append(configurationManager.getAddress());
					defectUrl.append(':');
					defectUrl.append(configurationManager.getPort());
					defectUrl.append("/sourcebrowser.htm?projectId=");
					defectUrl.append(this.projectId);
					defectUrl.append("#mergedDefectId=");
					defectUrl.append(defect.getCid());
					html.append("<tr><td><a href=\"");
					html.append(defectUrl);
					html.append("\"/a>");
					html.append(defect.getCid());
					html.append("</td><td>");
					html.append(defect.getCheckerName());
					html.append("</td><td>");
					html.append(defect.getFilePathname());
					html.append("</td></tr>");
					// System.out.println("user=" + userDefectValues.getKey() + ", defect=" + defect.getCid());
				}
				html.append("</table></body></html>");
				
				if(this.isDryRun) {
					System.out.println(html);
				}
				else {
					final String subject = "New defects assigned to you in Coverity";
					String recipient = CimProxy.getInstance().notify(userDefectValues.getKey(), subject, html.toString());
					if(recipient.length() > 0) {
						System.out.println("e-mail sucessfully sent to " + recipient);
					}
					else {
						System.out.println("*** Unable to e-mail " + recipient + " ***");
					}
				}
			}
		}
		
		return true;
	}

	/*
	 * Main command line driver. Please see class constructor for required arguments.
	 */
	public static void main(String[] args) {
		try {
			if (args.length == 3) {
				NotifyDefectOwners notifyOwners = new NotifyDefectOwners(
						args[0], Integer.parseInt(args[1]),
						args[2].equalsIgnoreCase("true"));
				if (notifyOwners.execute()) {
					System.out.println("\nSuccessful!");
				} else {
					System.out.println("\n*** Unsuccessful ***");
				}
			} else {
				System.err.println("This program notifies defect owners of new defects that have been detected in the last N number of days.");
				System.err.println("usage: java " + UserDefectReport.class.getName() + " <project-name> <num-days> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
