package com.coverity.ps.bugtracking;

import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.apache.xmlrpc.XmlRpcRequest;
import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;
import org.apache.xmlrpc.client.XmlRpcClientException;
import org.apache.xmlrpc.client.XmlRpcSunHttpTransport;
import org.apache.xmlrpc.client.XmlRpcSunHttpTransportFactory;
import org.apache.xmlrpc.client.XmlRpcTransport;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import com.coverity.ps.common.config.ConfigurationManager;

public class Bugzilla {
	private String cid;
	private String project;
	private List<String> cookies = new ArrayList<String>();
	private XmlRpcClient rpcClient;

	private void parseInputFile(String inputFile) throws Exception {
		// final String xml = readFileAsString(inputFile);

		DocumentBuilderFactory documentFactory = DocumentBuilderFactory
				.newInstance();
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
			System.err
					.println("Invalid or missing mergedDefect configuration tag!");
		}
		Element mergedDefectElem = (Element) mergedDefectNode.item(0);

		NodeList cidNode = mergedDefectElem.getElementsByTagName("cid");
		if (cidNode.getLength() != 1) {
			System.err.println("Invalid or missing cid configuration tag!");
		}
		Element cidElem = (Element) cidNode.item(0);
		this.cid = cidElem.getTextContent();
	}

	public void createBug(String inputFile) throws Exception {
		// load config service and parse input xml
		ConfigurationManager configurationManager = ConfigurationManager.getInstance();
		parseInputFile(inputFile);
		
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
		
		// TODO: get project information
		
		
		// map of the bug data
		Map<String, String> bugMap = new HashMap<String, String>();
		bugMap.put("version", "unspecified");
		bugMap.put("product", "3rd Party Products");
		bugMap.put("component", "VMWare");
		bugMap.put("summary", "Testing 42.");
		bugMap.put("description", "Testing 42.");
		
		// create bug
		Map createResult = (Map) rpcClient.execute("Bug.create", new Object[] { bugMap });
		System.err.println("createResult = " + createResult);
	}

	public static void main(String[] args) {
		try {
			final String inputFile = "C:\\Program Files\\Coverity\\Coverity Integrity Manager\\server\\coverity-tomcat\\temp\\cov-export7701100041627747036.xml";
			Bugzilla bugzilla = new Bugzilla();
			bugzilla.createBug(inputFile);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
