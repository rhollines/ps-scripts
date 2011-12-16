package com.coverity.ps.scm.plugins;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

public class Subversion implements ScmPlugin {
	@Override
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
			Subversion svn = new Subversion();
			String author = svn.getFileOwner("C:\\Users\\rhollines\\Documents\\Demo\\src\\vm\\lib_api.h");
			System.out.println("file owner=" + author);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
