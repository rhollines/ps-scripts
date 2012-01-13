package com.coverity.ps.common.plugins.bugtracking;

import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.xmlrpc.XmlRpcRequest;
import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;
import org.apache.xmlrpc.client.XmlRpcClientException;
import org.apache.xmlrpc.client.XmlRpcSunHttpTransport;
import org.apache.xmlrpc.client.XmlRpcSunHttpTransportFactory;
import org.apache.xmlrpc.client.XmlRpcTransport;

import com.coverity.ps.common.config.ConfigurationManager;
import com.coverity.ws.v4.DefectStateCustomAttributeValueDataObj;
import com.coverity.ws.v4.MergedDefectDataObj;

public class Bugzilla implements BugTracking {
	private List<String> cookies = new ArrayList<String>();
	private XmlRpcClient rpcClient;
	
	public String createBug(String project, MergedDefectDataObj defect, boolean isDryRun) throws Exception {
		if(isDryRun) {
			return "tid-0420";
		}
		
		// load configuration service
		ConfigurationManager configurationManager = ConfigurationManager.getInstance();
		
		// create a client with cookie support
		XmlRpcClientConfigImpl config = new XmlRpcClientConfigImpl();
		config.setServerURL(new URL(configurationManager.getBugTrackingAddress()));
		rpcClient = new XmlRpcClient();
		rpcClient.setTransportFactory(new XmlRpcSunHttpTransportFactory(rpcClient) {
			public XmlRpcTransport getTransport() {
				return new XmlRpcSunHttpTransport(rpcClient) {
					private URLConnection conn;
					
					@Override
					protected URLConnection newURLConnection(URL pURL) throws IOException {
                    	conn = super.newURLConnection(pURL);
                    	return conn;
                    }
					
					@Override
					protected void initHttpHeaders(XmlRpcRequest request)
							throws XmlRpcClientException {
						super.initHttpHeaders(request);
						if (cookies.size() > 0) {
							StringBuilder commaSep = new StringBuilder();

							for (String str : cookies) {
								commaSep.append(str);
								commaSep.append(",");
							}
							setRequestHeader("Cookie", commaSep.toString());
						}
					}

					@Override
					protected void close() throws XmlRpcClientException {
						getCookies(conn);
					}

					private void getCookies(URLConnection conn) {
						if (cookies.size() == 0) {
							Map<String, List<String>> headers = conn.getHeaderFields();
							if (headers.containsKey("Set-Cookie")) {// avoid NPE
								List<String> vals = headers.get("Set-Cookie");
								for (String str : vals) {
									cookies.add(str);
								}
							}
						}

					}
				};
			}
		});
		rpcClient.setConfig(config);

		// map of the login data
		Map<String, String> loginMap = new HashMap<String, String>();
		loginMap.put("login", configurationManager.getBugTrackingUser());
		loginMap.put("password", configurationManager.getBugTrackingPassword());
		loginMap.put("rememberlogin", "Bugzilla_remember");

		// login to bugzilla
		Map loginResult = (Map) rpcClient.execute("User.login",	new Object[] { loginMap });
		System.err.println("loginResult=" + loginResult);
		
		// map of the bug data
		String summary = "Coverity defect " + defect.getCheckerName() + ":" + defect.getCid();
		String description = defect.getComment();
		if(description == null || description.length() == 0) {
			description = "No description provided by Coverity";
		}
		
		String product = null;
		String component = null;		
		List<DefectStateCustomAttributeValueDataObj> attribs = defect.getDefectStateCustomAttributeValues();
		for(DefectStateCustomAttributeValueDataObj  attrib : attribs) {
			if(attrib.getAttributeDefinitionId().getName().equals("Component")) {
				component = attrib.getAttributeValueId().getName();
			}
			else if(attrib.getAttributeDefinitionId().getName().equals("Product")) {
				product = attrib.getAttributeValueId().getName();
			}
		}
		
		Map<String, String> bugMap = new HashMap<String, String>();
		bugMap.put("version", "V6.0.0 Glenlivet");
		bugMap.put("product", product);
		bugMap.put("component", component);
		bugMap.put("summary", summary);
		bugMap.put("description", description);
		
		// create bug and return id
		Map createResult = (Map) rpcClient.execute("Bug.create", new Object[] { bugMap });
		System.err.println("createResult = " + createResult);
		for(Object value : createResult.values()) {
			return value.toString();
		}
		
		return "";
	}
}
