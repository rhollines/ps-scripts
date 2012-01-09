package com.coverity.ps.integrations.reporting;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.coverity.cim.ws.MergedDefectDataObj;
import com.coverity.ps.common.CimProxy;
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ps.integrations.Integration;

public class NotifyDefectManagers extends UserDefectReport implements Integration {
	private List<String> users = new ArrayList<String>();

	public NotifyDefectManagers(String project, int days, String managerList, boolean isDryRun) {
		super(project, days, isDryRun);
		String[] managers = managerList.split(",");
		for(String manager : managers) {
			this.users.add(manager);
		}
	}

	public boolean execute() throws Exception {
		ConfigurationManager configurationManager = ConfigurationManager.getInstance();
		Map<String, List<MergedDefectDataObj>> defectsByUser = getStreamDefectsByOwner();
		System.out.println(defectsByUser.size() + " user(s) with new defects");
		
		StringBuilder html = new StringBuilder();
		html.append("<html><body><p>The following defects were detected in project ");
		html.append(this.projectName);
		html.append(" within the past ");
		if (days == 1) {
			html.append("24 hours.</p>");
		} else {
			html.append(days + " days.</p>");
		}
		
		for (Map.Entry<String, List<MergedDefectDataObj>> userDefectValues : defectsByUser.entrySet()) {
			List<MergedDefectDataObj> userDefects = userDefectValues.getValue();
			if (userDefects.size() > 0 && userDefectValues.getKey() != UNASSIGNED_OWNER_NAME) {
				html.append("<p><b>Defect(s) for ");
				html.append(userDefectValues.getKey());
				html.append("</b>");
				html.append("<table border=\"1\"><tr><th>CID</th><th>Checker</th><th>File</th></tr>");
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
				html.append("</table></p>");
			}
		}
		
		// unassigned defects
		if(defectsByUser.containsKey(UNASSIGNED_OWNER_NAME)) {
			List<MergedDefectDataObj> userDefects = defectsByUser.get(UNASSIGNED_OWNER_NAME);
			if (userDefects.size() > 0) {
				html.append("<p><b>Unassigned Defects</b>");
				html.append("<table border=\"1\"><tr><th>CID</th><th>Checker</th><th>File</th></tr>");
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
				html.append("</table></p>");
			}
		}
		
		html.append("</body></html>");
		
		if(this.isDryRun) {
			System.out.println(html);
		}
		else {
			final String subject = "New Coverity defects";
			List<String> recipients = CimProxy.getInstance().notify(this.users, subject, html.toString());
			for(String recipient : recipients) {
				System.out.println("e-mail sucessfully sent to " + recipient);
			}
		}
		
		return true;
	}

	public static void main(String[] args) {
		try {
			if (args.length == 4) {
				NotifyDefectManagers notifyManagers = new NotifyDefectManagers(
						args[0], 
						Integer.parseInt(args[1]),
						args[2],
						args[3].equalsIgnoreCase("true"));
				if (notifyManagers.execute()) {
					System.out.println("\nSuccessful!");
				} else {
					System.out.println("\n*** Unsuccessful ***");
				}
			} else {
				System.err.println("This program e-mails a list of users new defects that have been detected in the last N number of days.");
				System.err.println("usage: java " + UserDefectReport.class.getName() + " <project-name> <num-days> <users-to-email> <is-dry-run>");
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
