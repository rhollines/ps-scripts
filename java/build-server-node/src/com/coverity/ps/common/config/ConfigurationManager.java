package com.coverity.ps.common.config;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

/*
 * Manages XML configuration data 
 */
public class ConfigurationManager {
	private static ConfigurationManager instance;
	private static final String CONFIGURATION_FILE = "config/coverity-bn-config.xml";
	private String address;
	private int port;
	private String user;
	private String password;
	private List<ScmConfigData> scmStreamData = new ArrayList<ScmConfigData>();
	private List<ScmConfigData> scmProjectData = new ArrayList<ScmConfigData>();
	private String scmClass;
	private String bugTrackingClass;
	private String bugTrackingAddress;
	private String bugTrackingUser;
	private String bugTrackingPassword;
	private Map<String, String> bugProperties;
	
	private ConfigurationManager() {
		try {
			loadConfigurationFile();
		} catch (SAXException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (ParserConfigurationException e) {
			e.printStackTrace();
		}
	}
	
	public static ConfigurationManager getInstance() {
		if (instance == null) {
			instance = new ConfigurationManager();
		}

		return instance;
	}
	
	private void loadConfigurationFile() throws SAXException, IOException,
			ParserConfigurationException {
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory
				.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(CONFIGURATION_FILE);
		
		// get cim tag
		NodeList cimNode = document.getDocumentElement().getElementsByTagName("cim");
		if (cimNode.getLength() != 1) {
			System.err.println("Invalid or missing cim configuration tag!");
		}
		Element cimElem = (Element) cimNode.item(0);
		
		NodeList addressNode = cimElem.getElementsByTagName("address");
		if (addressNode.getLength() != 1) {
			System.err.println("Invalid or missing address configuration tag!");
		}
		Element addressElem = (Element) addressNode.item(0);
		this.address = addressElem.getTextContent();
		
		NodeList portNode = cimElem.getElementsByTagName("port");
		if (portNode.getLength() != 1) {
			System.err.println("Invalid or missing port configuration tag!");
		}
		Element portElem = (Element) portNode.item(0);
		this.port = Integer.parseInt(portElem.getTextContent());
		
		NodeList userNode = cimElem.getElementsByTagName("user");
		if (userNode.getLength() != 1) {
			System.err.println("Invalid or missing user configuration tag!");
		}
		Element userElem = (Element) userNode.item(0);
		this.user = userElem.getTextContent();
		
		NodeList passwordNode = cimElem.getElementsByTagName("password");
		if (passwordNode.getLength() != 1) {
			System.err.println("Invalid or missing password configuration tag!");
		}
		Element passwordElem = (Element) passwordNode.item(0);
		this.password = passwordElem.getTextContent();
		
		// get scm tag
		NodeList scmNode = document.getDocumentElement().getElementsByTagName("scm");
		if (scmNode.getLength() == 1) {
			Element scmElem = (Element) scmNode.item(0);
			
			NodeList systemNode = scmElem.getElementsByTagName("system");
			if (systemNode.getLength() != 1) {
				System.err.println("Invalid or missing system configuration tag!");
			}
			Element systemElem = (Element) systemNode.item(0);
			this.scmClass = systemElem.getAttribute("class");
			Map<String, String> data = new HashMap<String, String>();
			
			// stream data
			NodeList streamNodes = systemElem.getElementsByTagName("stream");
			for(int i = 0; i < streamNodes.getLength(); i++) {
				Element streamElem = (Element) streamNodes.item(i);
				String name = streamElem.getAttribute("name");
				data.put("name", name);				
				String cimStripPath = getElement(streamElem, "cim-strip-path", 1);
				
				if (cimStripPath != null)
				   data.put("cimStripPath", cimStripPath);

				String localPrependPath = getElement(streamElem, "local-prepend-path", 1);
				
				if (localPrependPath != null)
				   data.put("localPrependPath", localPrependPath);
				   
				String repository = getElement(streamElem, "repository", 1);

				if (repository != null)
  				   data.put("repository", repository);
				
				scmStreamData.add(new ScmConfigData(data));
			}
			
/*			
			// project data
			NodeList projectNodes = systemElem.getElementsByTagName("project");
			for(int i = 0; i < projectNodes.getLength(); i++) {
				Element projectElem = (Element) projectNodes.item(i);
				String name = projectElem.getAttribute("name");
				
				NodeList cimStripPathNode = systemElem.getElementsByTagName("cim-strip-path");
				if (cimStripPathNode.getLength() != 1) {
					System.err.println("Invalid or missing cimStripPath configuration tag!");
				}
				Element cimStripPathElem = (Element) cimStripPathNode.item(0);
				String cimStripPath = cimStripPathElem.getTextContent();
				
				NodeList localPrependPathNode = systemElem.getElementsByTagName("local-prepend-path");
				if (localPrependPathNode.getLength() != 1) {
					System.err.println("Invalid or missing localPrependPath configuration tag!");
				}
				Element localPrependPathElem = (Element) localPrependPathNode.item(0);
				String localPrependPath = localPrependPathElem.getTextContent();
				
				this.scmProjectData.add(new ScmConfigData(name, cimStripPath, localPrependPath));
			}
*/			
		}
					
		// get bug tracking tag
		NodeList bugTrackingNode = document.getDocumentElement().getElementsByTagName("bug-tracking");
		if (bugTrackingNode.getLength() == 1) {
			Element bugTrackingElem = (Element) bugTrackingNode.item(0);
			
			NodeList systemNode = bugTrackingElem.getElementsByTagName("system");
			if (systemNode.getLength() != 1) {
				System.err.println("Invalid or missing system configuration tag!");
			}
			Element systemElem = (Element) systemNode.item(0);
			this.bugTrackingClass = systemElem.getAttribute("class");
			
			NodeList bugTrackingAddressNode = systemElem.getElementsByTagName("address");
			if (bugTrackingAddressNode.getLength() != 1) {
				System.err.println("Invalid or missing Address configuration tag!");
			}
			Element bugTrackingAddressElem = (Element) bugTrackingAddressNode.item(0);
			this.bugTrackingAddress = bugTrackingAddressElem.getTextContent();
			
			NodeList bugTrackingUserNode = systemElem.getElementsByTagName("user");
			if (bugTrackingUserNode.getLength() != 1) {
				System.err.println("Invalid or missing user configuration tag!");
			}
			Element bugTrackingUserElem = (Element) bugTrackingUserNode.item(0);
			this.bugTrackingUser = bugTrackingUserElem.getTextContent();
			
			NodeList bugTrackingPasswordNode = systemElem.getElementsByTagName("password");
			if (bugTrackingPasswordNode.getLength() != 1) {
				System.err.println("Invalid or missing password configuration tag!");
			}
			Element bugTrackingPasswordElem = (Element) bugTrackingPasswordNode.item(0);
			this.bugTrackingPassword = bugTrackingPasswordElem.getTextContent();
			
			// get properties
			this.bugProperties = new HashMap<String, String>();
			NodeList bugPropertiesNode = systemElem.getElementsByTagName("property");
			for (int i = 0; i < bugPropertiesNode.getLength(); i++) {
				Element bugPropertyNode  = (Element) bugPropertiesNode.item(i);
				bugProperties.put(bugPropertyNode.getAttribute("name"), 
						bugPropertyNode.getTextContent());
			}
		}
	}

	
	private String getElement(Element systemElem, String name, int nbElements) {
		NodeList nl = systemElem.getElementsByTagName(name);
		if (nl.getLength() != nbElements) {
			System.err.println("Invalid or missing " + name + " configuration tag!");
			return null;
		}
		Element elem = (Element) nl.item(0);
		return elem.getTextContent();
	}
			
	public String getBugTrackingClass() {
		return bugTrackingClass;
	}

	public String getBugTrackingAddress() {
		return bugTrackingAddress;
	}

	public String getBugTrackingUser() {
		return bugTrackingUser;
	}

	public String getBugTrackingPassword() {
		return bugTrackingPassword;
	}

	public String getScmClass() {
		return scmClass;
	}

	public List<ScmConfigData> getScmStreamData() {
		return scmStreamData;
	}
	
	public List<ScmConfigData> getScmProjectData() {
		return scmProjectData;
	}

	public String getAddress() {
		return address;
	}

	public int getPort() {
		return port;
	}

	public String getUser() {
		return user;
	}

	public String getPassword() {
		return password;
	}
	
	public Map<String, String> getBugProperties() {
		return bugProperties;
	}
}
