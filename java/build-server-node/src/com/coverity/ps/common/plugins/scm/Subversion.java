package com.coverity.ps.common.plugins.scm;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

/*
 * Provides support for subversion
 */
public class Subversion implements ScmPlugin {
	/**
	 * Returns the username of the last person modified the file
	 */
	public String getFileOwner(String filename) {
		final String command = "svn ls --xml " + filename;
		try {
			Process process = Runtime.getRuntime().exec(command);
			DocumentBuilderFactory documentFactory = DocumentBuilderFactory.newInstance();
			DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
			Document document = documentBuilder.parse(process.getInputStream());
			
			// get author tag
			NodeList authorNode = document.getDocumentElement()
					.getElementsByTagName("author");
			if (authorNode.getLength() != 1) {
				return "";
			}
			Element authorElem = (Element) authorNode.item(0);
			return authorElem.getTextContent();
		} catch (Exception e) {
			return "";
		}
	}

	public static void main(String[] args) {
		try {
			if(args.length > 0) {
				Subversion svn = new Subversion();
				String author = svn.getFileOwner(args[0]);
				System.out.println("file owner=" + author);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
