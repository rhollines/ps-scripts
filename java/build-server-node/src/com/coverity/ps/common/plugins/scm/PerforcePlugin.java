package com.coverity.ps.common.plugins.scm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

import com.coverity.ps.common.config.ScmConfigData;
import com.coverity.ps.common.CimProxy;
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.UserDataObj;

/*
 * Provides support for Perforce
 */
public class PerforcePlugin implements ScmPlugin {
	// build user map email -> user
	static Map<String, UserDataObj> userMap = new HashMap<String, UserDataObj>();
	static {
		try {
			// map  e-mail address to users
			List<UserDataObj> users;
			users = CimProxy.getInstance().getAllUsers();
			for(UserDataObj user : users) {
				userMap.put(user.getEmail(), user);
			}
		} catch (CovRemoteServiceException_Exception e) {
			e.printStackTrace();
		}
	}
	
	private ScmConfigData scmStreamData;
	
	
	public void setData(ScmConfigData scmStreamData) {
	   this.scmStreamData = scmStreamData;
	}
	
	
	private String getConfig(String key) {
	   return this.scmStreamData.get(key);
	}
	
	
	/**
	 * Returns the user name of the last person modified the file
	 */
	public String getFileOwner(String file) throws Exception {	 
		final StringBuilder commandBuilder = new StringBuilder(100);
		String p4client = getConfig("client");
		String p4port = getConfig("port");
		String p4user = getConfig("user");
		String p4password = getConfig("password");
		String p4repository = getConfig("repository");
		String p4strip = getConfig("strip-path");

		commandBuilder.append("p4 -s");

		if (p4client != null)
		   commandBuilder.append(" -c ").append(p4client);
		
		if (p4port != null)
		   commandBuilder.append(" -p ").append(p4port);
		
		if (p4user != null)
		   commandBuilder.append(" -u ").append(p4user);
		
		if (p4password != null)
		   commandBuilder.append(" -P ").append(p4password);
			    
		if ((p4repository != null) && (p4repository.length() > 0))
		   file = p4repository + file;

		if ((p4strip != null) && (p4strip.length() > 0))
		   file = file.replace(p4strip, "");

		file = file.replace("/", java.io.File.separator);
		commandBuilder.append("  filelog -i -m 5 ").append(file);
		String command = commandBuilder.toString();
		String owner = "nobody";

		try {
			Process process = Runtime.getRuntime().exec(command);
			BufferedReader br = new BufferedReader(new InputStreamReader(process.getInputStream()));			
			String text = br.readLine();
			Pattern p = Pattern.compile(".* by (\\w+)@");
			
			while (text != null) {			   
			   if (text.contains(" edit on ")) {
			     Matcher m = p.matcher(text);
			   
			     if (m.find()) {
			       owner = new String(m.group(1));
				   break;
			     }
			   }

			   text = br.readLine();
			}
						
			return owner;
		} catch (Exception e) {
		    e.printStackTrace();
			return "";
		}
	}
	

	private String parse_output_for_owner(String text) {
	   return "toto";
	}
	
	public static void main(String[] args) {
		try {
			if(args.length > 0) {
				PerforcePlugin svn = new PerforcePlugin();
				String author = svn.getFileOwner(args[0]);
				System.out.println("file owner=" + author);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
