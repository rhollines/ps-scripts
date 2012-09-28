package com.coverity.ps.common.plugins.bugtracking;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.rmi.RemoteException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.Calendar;
import java.util.Date;
import java.util.Map;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import javax.xml.rpc.ServiceException;

import com.atlassian.jira.rpc.soap.beans.RemoteComponent;
import com.atlassian.jira.rpc.soap.beans.RemoteCustomFieldValue;
import com.atlassian.jira.rpc.soap.beans.RemoteField;
import com.atlassian.jira.rpc.soap.beans.RemoteIssue;
import com.atlassian.jira.rpc.soap.beans.RemoteVersion;
import com.atlassian.jira.rpc.soap.jirasoapservice_v2.JiraSoapService;
import com.atlassian.jira.rpc.soap.jirasoapservice_v2.JiraSoapServiceService;
import com.atlassian.jira.rpc.soap.jirasoapservice_v2.JiraSoapServiceServiceLocator;
import com.coverity.ps.common.CimProxy;
import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.MergedDefectDataObj;

public class Jira implements BugTracking {
	// Constants for issue creation
	static TrustManager[] trustAllCerts;
	static HostnameVerifier hv;
	String jiraProject;
	private JiraSoapServiceService jiraSoapServiceLocator;
    private JiraSoapService jiraSoapService;
    private String token;
	private MergedDefectDataObj defect;
	private String project;
	
	// set proxy settings
	static {
		// proxy settings
    	System.setProperty("https.proxyHost", "proxy.jf.intel.com");
    	System.setProperty("https.proxyPort", "911");
    	System.setProperty("https.proxySet", "true");
	}
    
    public Jira(String webServicePort, String userName, String password) throws RemoteException, MalformedURLException, NoSuchAlgorithmException, KeyManagementException {
    	// disabling certificate validation
    	disableCertificateValidation();
		SSLContext sc = SSLContext.getInstance("SSL");
		sc.init(null, trustAllCerts, new SecureRandom());
		HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
		HttpsURLConnection.setDefaultHostnameVerifier(hv);
    	
    	createService(new URL(webServicePort), userName, password);
    }
    
    public Jira() throws RemoteException, MalformedURLException {
    	ConfigurationManager configurationManager = ConfigurationManager.getInstance();
    	URL webServicePort = new URL(configurationManager.getBugTrackingAddress());
    	String userName = configurationManager.getBugTrackingUser();
    	String password = configurationManager.getBugTrackingPassword();
    	
    	createService(webServicePort, userName, password);
    }
    
    public void createService(URL webServicePort, String userName, String password) throws RemoteException, MalformedURLException {
    	jiraSoapServiceLocator = new JiraSoapServiceServiceLocator();
        try {
            this.jiraSoapService = jiraSoapServiceLocator.getJirasoapserviceV2(webServicePort);
            this.token = jiraSoapService.login(userName, password);
        }
        catch (ServiceException e) {
            throw new RuntimeException("ServiceException during SOAPClient contruction", e);
        }
    }

	public String createBug(String project, MergedDefectDataObj defect, boolean isDryRun) throws Exception {
		this.defect = defect;
		this.project = project;
		Map<String, String> properties = ConfigurationManager.getInstance().getBugProperties();
		return createIssue(properties);
	}
	
	private RemoteComponent getComponent(String name) throws java.rmi.RemoteException {
		RemoteComponent[] components = jiraSoapService.getComponents(token, jiraProject);
		for(RemoteComponent component : components) {
			if(component.getName().equals(name)) {
				return component;
			}
		}
		
		return null;
	}
	
	private RemoteVersion getVersion(String name) throws java.rmi.RemoteException {
		RemoteVersion[] versions = jiraSoapService.getVersions(token, jiraProject);
		for(RemoteVersion version : versions) {
			if(version.getName().equals(name)) {
				return version;
			}
		}
		
		return new RemoteVersion();
	}
	
	private RemoteCustomFieldValue createCustomFieldValue(String name, String value) throws java.rmi.RemoteException {
		return new RemoteCustomFieldValue(getCustomField(name).getId(), "", new String[] { value });
	}
	
	private RemoteField getCustomField(String name) throws java.rmi.RemoteException {
		RemoteField[] fields = jiraSoapService.getCustomFields(token);
		for(RemoteField field : fields) {
			if(field.getName().equals(name)) {
				return field;
			}
		}
		
		return null;
	}

	private String createIssue(Map<String, String> properties) throws java.rmi.RemoteException, CovRemoteServiceException_Exception {
		final String issueId = properties.get("issue-type");
		final String summary;
		if(this.defect != null) {
			summary = properties.get("summary") + " : " + this.defect.getCheckerName() + " : " + this.defect.getCid();		
		}
		else {
			summary = properties.get("summary") + " : " + new Date();
		}
		final String priority = properties.get("priority");
		final String component = properties.get("component");
		final String version = properties.get("version");
		final String assignee = properties.get("assignee");
		final String environment = properties.get("environment");
		this.jiraProject = properties.get("project");
		
		if(!validInput(issueId) || !validInput(summary) || !validInput(priority) || !validInput(component) || 
				!validInput(version) || !validInput(assignee) || !validInput(environment) || 
				!validInput(this.jiraProject)) {
			return null;
		}
		
		// Create the issue
		RemoteIssue issue = new RemoteIssue();
		issue.setProject(jiraProject);
		issue.setType(issueId);

		issue.setSummary(summary);
		issue.setPriority(priority);
		if(this.defect != null) {
			StringBuilder defectUrl = new StringBuilder("http://");
			defectUrl.append( ConfigurationManager.getInstance().getAddress());
			defectUrl.append(':');
			defectUrl.append( ConfigurationManager.getInstance().getPort());
			defectUrl.append("/sourcebrowser.htm?projectId=");
			defectUrl.append(CimProxy.getInstance().getProject(this.project).getProjectKey());
			defectUrl.append("#mergedDefectId=");
			defectUrl.append(this.defect.getCid());
			
			StringBuilder description = new StringBuilder("A ");
			description.append(this.defect.getCheckerName());
			description.append(" Coverity defect was found in the ");
			description.append(this.jiraProject);
			description.append(" project. This defect was detected in file the '");
			description.append(this.defect.getFilePathname());
			description.append("' within function '");
			description.append(this.defect.getFunctionDisplayName());
			description.append(".\n\nA link to the defect is below\n");
			description.append(defectUrl.toString());
			
			issue.setDescription(description.toString());
		}
		else {
			issue.setDescription("Coverity JIRA plug-in testing");
		}
		issue.setDuedate(Calendar.getInstance());
		issue.setAssignee(assignee);
		issue.setEnvironment(environment);
		
		// Add remote components
		issue.setComponents(new RemoteComponent[] { getComponent(component) });
		
		// Add remote versions
		issue.setAffectsVersions(new RemoteVersion[] { getVersion(version) } );
		
		// Add custom fields
		// TODO: map custom values that defect
		RemoteCustomFieldValue[] customFieldValues = new RemoteCustomFieldValue[] { 
			createCustomFieldValue("Reproducibility", "10606"), // 100%
			createCustomFieldValue("Profile/s", "10811"), // smart phone
			createCustomFieldValue("Defect Classification", "10836"), // security
			createCustomFieldValue("Severity", "10006") // normal
		};
		issue.setCustomFieldValues(customFieldValues);
		
		// Run the create issue code
		RemoteIssue returnedIssue = jiraSoapService.createIssue(token, issue);
		final String issueKey = returnedIssue.getKey();

		// System.out.println("\tSuccessfully created issue " + issueKey);
		// dumpIssue(returnedIssue);
		
		return issueKey;
	}
	
	private boolean validInput(String field) {
		if(field == null || field.length() == 0) {
			return false;
		}
		
		return true;
	}

	private static void dumpIssue(RemoteIssue issue) {
		System.out.println("Issue Details : ");
		Method[] declaredMethods = issue.getClass().getDeclaredMethods();
		for (int i = 0; i < declaredMethods.length; i++) {
			Method declaredMethod = declaredMethods[i];
			if (declaredMethod.getName().startsWith("get")
					&& declaredMethod.getParameterTypes().length == 0) {
				System.out.print("\t Issue." + declaredMethod.getName()
						+ "() -> ");
				try {
					Object obj = declaredMethod.invoke(issue, new Object[] {});
					if (obj instanceof Object[]) {
						obj = arrayToStr((Object[]) obj);
					}
					System.out.println(obj);
				} catch (IllegalAccessException e) {
					e.printStackTrace();
				} catch (InvocationTargetException e) {
					e.printStackTrace();
				}
			}
		}
	}
   	
	private static String arrayToStr(Object[] o) {
		StringBuffer sb = new StringBuffer();
		for (int i = 0; i < o.length; i++) {
			sb.append(o[i]).append(" ");
		}
		return sb.toString();
	}
	
	public static void disableCertificateValidation() {
	  // Create a trust manager that does not validate certificate chains
	  trustAllCerts = new TrustManager[] { 
		new X509TrustManager() {
		  public X509Certificate[] getAcceptedIssuers() { 
			return new X509Certificate[0]; 
		  }
		  public void checkClientTrusted(X509Certificate[] certs, String authType) {}
		  public void checkServerTrusted(X509Certificate[] certs, String authType) {}
	  }};

	  // Ignore differences between given hostname and certificate hostname
	  hv = new HostnameVerifier() {
		public boolean verify(String hostname, SSLSession session) { return true; }
	  };
	}
	
	/*
	 * Main command line driver. Please see class constructor for required arguments.
	 */
	public static void main(String[] args) {
		try {
			Map<String, String> properties = ConfigurationManager.getInstance().getBugProperties();
			Jira jira = new Jira(
					"https://tz.otcshare.org/jira/rpc/soap/jirasoapservice-v2?wsdl",
					"coverityuser", "COVERITY.123");
			jira.createIssue(properties);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
