package com.coverity.ps.common.plugins.scm;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;



/*
 * Provides support for subversion
 */
public class ClearCase implements ScmPlugin {
	String view;
	
	public ClearCase() {
		view = "cleartool desc -fmt"; 
	}
	
	/**
	 * Returns the username of the last person modified the file
	 */
	public String getFileOwner(String file) throws Exception {
		final String command = "cleartool desc -fmt + '\"' + " + view + file + '\"';
		try {
			Process process = Runtime.getRuntime().exec(command);
			String result = InputStreamToString(process.getInputStream());			
			return result;
		} catch (Exception e) {
			return "";
		}
	}
	
	private String InputStreamToString(InputStream in) throws IOException {	
		StringBuilder inputStringBuilder = new StringBuilder();
        BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(in, "UTF-8"));
        
        String line = bufferedReader.readLine();
        while(line != null){
            inputStringBuilder.append(line);
            line = bufferedReader.readLine();
        }
        
        return inputStringBuilder.toString();
	}

	/**
	 * Command line test
	 * 
	 * @param args file name
	 */
	public static void main(String[] args) {
		try {
			if(args.length == 1) {
				ClearCase svn = new ClearCase();
				String author = svn.getFileOwner(args[0]);
				System.out.println("file owner=" + author);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
