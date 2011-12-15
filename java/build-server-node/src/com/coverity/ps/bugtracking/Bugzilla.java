package com.coverity.ps.bugtracking;

import java.net.URL;
import java.util.HashMap;
import java.util.Map;

import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;
import org.apache.xmlrpc.client.XmlRpcCommonsTransportFactory;

public class Bugzilla {
	public void createBug() throws Exception {
		XmlRpcClientConfigImpl config = new XmlRpcClientConfigImpl();
		config.setServerURL(new URL("http://127.0.0.1:8080/XmlRpcServlet"));
		XmlRpcClient rpcClient = new XmlRpcClient();
		rpcClient.setTransportFactory(new XmlRpcCommonsTransportFactory(rpcClient));
		rpcClient.setConfig(config);
		
		// map of the login data
		Map<String, String> loginMap = new HashMap<String, String>();
		loginMap.put("login", "tomas.hubalek@....");
		loginMap.put("password", "*top*secret*");
		loginMap.put("rememberlogin", "Bugzilla_remember");

		// login to bugzilla
		Object loginResult = rpcClient.execute("User.login",
				new Object[] { loginMap });
		System.err.println("loginResult=" + loginResult);

		// map of the bug data
		Map<String, String> bugMap = new HashMap<String, String>();
		bugMap.put("product", "Playground");
		bugMap.put("component", "Database");
		bugMap.put("summary", "Bug created from groovy script");
		bugMap.put("description", "This is text including stacktrace");
		bugMap.put("version", "unspecified");
		bugMap.put("op_sys", "Linux");
		bugMap.put("platform", "PC");
		bugMap.put("priority", "P2");
		bugMap.put("severity", "Normal");
		bugMap.put("status", "NEW");

		// create bug
		Object createResult = rpcClient.execute("Bug.create",
				new Object[] { bugMap });
		System.err.println("createResult = " + createResult);
	}
	
	public static void main(String[] args) {
		try {
			Bugzilla bugzilla = new Bugzilla();
			bugzilla.createBug();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
