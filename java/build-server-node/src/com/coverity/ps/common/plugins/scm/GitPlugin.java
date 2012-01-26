package com.coverity.ps.common.plugins.scm;

import java.io.BufferedReader;
import java.io.InputStreamReader;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

/*
 * Provides support for subversion
 */
public class GitPlugin implements ScmPlugin {
	/**
	 * Returns the username of the last person modified the file
	 */
	public String getFileOwner(String stream, String file) throws Exception {
		final String command = "git log -1 --author=coverity --format=%ce " + file;
		try {
			Process process = Runtime.getRuntime().exec(command);
			String response = new BufferedReader(new InputStreamReader(process.getInputStream())).readLine();
			
			// TOOD: map Git response to CIM user
			// ...
			
			return response;
		} catch (Exception e) {
			return "";
		}
	}
	
	public static void main(String[] args) {
		try {
			if(args.length > 0) {
				GitPlugin svn = new GitPlugin();
				String author = svn.getFileOwner(args[0], "compiler_win");
				System.out.println("file owner=" + author);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
