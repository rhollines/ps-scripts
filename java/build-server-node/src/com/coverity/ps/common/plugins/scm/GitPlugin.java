package com.coverity.ps.common.plugins.scm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.coverity.ps.common.CimProxy;
import com.coverity.ws.v4.CovRemoteServiceException_Exception;
import com.coverity.ws.v4.UserDataObj;

/*
 * Provides support for subversion
 */
public class GitPlugin implements ScmPlugin {
	// build user map email -> user
	static Map<String, UserDataObj> userMap = new HashMap<String, UserDataObj>();
	static {
		try {
			// map git e-mail address to users
			List<UserDataObj> users;
			users = CimProxy.getInstance().getAllUsers();
			for(UserDataObj user : users) {
				userMap.put(user.getEmail(), user);
			}
		} catch (CovRemoteServiceException_Exception e) {
			e.printStackTrace();
		}
	}
	
	/**
	 * Returns the user name of the last person modified the file
	 */
	public String getFileOwner(String file) throws Exception {
		final String command = "git log -1 --author=coverity --format=%ce " + file;
		try {
			Process process = Runtime.getRuntime().exec(command);
			String ownerEmail = new BufferedReader(new InputStreamReader(process.getInputStream())).readLine();
			
			UserDataObj user = userMap.get(ownerEmail);
			if(user != null) {
				return user.getUsername(); 
			}
			
			return "nobody";
		} catch (Exception e) {
			return "";
		}
	}
	
	public static void main(String[] args) {
		try {
			if(args.length > 0) {
				GitPlugin svn = new GitPlugin();
				String author = svn.getFileOwner(args[0]);
				System.out.println("file owner=" + author);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
