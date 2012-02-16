package com.coverity.ps.sac.io;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.List;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import javax.xml.xpath.XPathExpression;
import org.xml.sax.SAXException;

import com.coverity.ps.sac.parser.Parser;

/**
 * Parses an SA input specification and creates the a C# output intermediate
 * directory.
 * 
 * @author rhollines
 */
public class InputParser {
	private final static String CONFIGURATION_FILE = "defect-spec.xml";
	private List<CoveritySaFormatter.Defect> defects = new ArrayList<CoveritySaFormatter.Defect>();
	private String filename;
	private int functionCount = 0;
	private int lineCount = 0;

	public static void main(String[] args) {
		new InputParser(args[0]);
	}

	/**
	 * Default constructor
	 * 
	 * @param filename
	 *            file to parse
	 */
	public InputParser(String filename) {
		this.filename = filename;
	}

	private InputConfiguration loadConfigurationFile() throws SAXException,
			IOException, ParserConfigurationException {
		System.out.println("Parsing configuration file...");
		DocumentBuilderFactory documentFactory = DocumentBuilderFactory
				.newInstance();
		DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
		Document document = documentBuilder.parse(CONFIGURATION_FILE);

		// get parser tag
		NodeList parserNode = document.getDocumentElement()
				.getElementsByTagName("parser");
		if (parserNode.getLength() != 1) {
			System.err.println("Invalid or missing parser configuration tag!");
		}
		final String parserClassName = ((Element) parserNode.item(0))
				.getAttribute("class");
		if (parserClassName.length() == 0) {
			System.err.println("Invalid or missing parser configuration tag!");
			System.exit(1);
		}

		// get file tag
		NodeList fileNode = document.getDocumentElement().getElementsByTagName(
				"file-tag");
		if (fileNode.getLength() != 1) {
			System.err.println("Invalid or missing file configuration tag!");
			System.exit(1);
		}
		Element fileElem = (Element) fileNode.item(0);
		final String fileElemName = fileElem.getAttribute("path");
		final String fileAttribName = fileElem.getAttribute("attrib");
		if (fileElemName.length() == 0 || fileAttribName.length() == 0) {
			System.err.println("Invalid or missing file configuration tag!");
			System.exit(1);
		}

		// get defect tag
		NodeList defectNode = fileElem.getElementsByTagName("defect-tag");
		if (defectNode.getLength() != 1) {
			System.err.println("Invalid or missing defect configuration tag!");
			System.exit(1);
		}
		final String defectElemName = ((Element) defectNode.item(0))
				.getAttribute("path");
		if (defectElemName.length() == 0) {
			System.err.println("Invalid or missing defect configuration tag!");
			System.exit(1);
		}

		// get checker tag
		NodeList checkerNode = fileElem.getElementsByTagName("checker-tag");
		if (checkerNode.getLength() != 1) {
			System.err.println("Invalid or missing checker configuration tag!");
			System.exit(1);
		}
		final String checkerElemName = ((Element) checkerNode.item(0))
				.getAttribute("path");
		final String checkerAttribName = ((Element) checkerNode.item(0))
				.getAttribute("attrib");
		if (checkerElemName.length() == 0 || checkerAttribName.length() == 0) {
			System.err.println("Invalid or missing checker configuration tag!");
			System.exit(1);
		}

		// get event tag
		NodeList eventNode = fileElem.getElementsByTagName("event-tag");
		if (eventNode.getLength() != 1) {
			System.err.println("Invalid or missing event configuration tag!");
			System.exit(1);
		}
		final String eventElemName = ((Element) eventNode.item(0))
				.getAttribute("path");
		final String eventAttribName = ((Element) eventNode.item(0))
				.getAttribute("attrib");
		if (eventElemName.length() == 0 || eventAttribName.length() == 0) {
			System.err.println("Invalid or missing event configuration tag!");
			System.exit(1);
		}

		// get line tag
		NodeList lineNode = fileElem.getElementsByTagName("line-tag");
		if (lineNode.getLength() != 1) {
			System.err.println("Invalid or missing line configuration tag!");
			System.exit(1);
		}
		final String lineElemName = ((Element) lineNode.item(0))
				.getAttribute("path");
		final String lineAttribName = ((Element) lineNode.item(0))
				.getAttribute("attrib");
		if (lineElemName.length() == 0 || lineAttribName.length() == 0) {
			System.err.println("Invalid or missing file configuration tag!");
			System.exit(1);
		}

		// get function tag
		NodeList functionNode = fileElem.getElementsByTagName("function-tag");
		String functionElemName = "";
		String functionAttribName = "";
		if (functionNode.getLength() == 1) {
			functionElemName = ((Element) functionNode.item(0))
					.getAttribute("path");
			functionAttribName = ((Element) functionNode.item(0))
					.getAttribute("attrib");
		}

		// get description tag
		NodeList descriptionNode = fileElem
				.getElementsByTagName("description-tag");
		if (descriptionNode.getLength() != 1) {
			System.err
					.println("Invalid or missing description configuration tag!");
			System.exit(1);
		}
		final String descriptionElemName = ((Element) descriptionNode.item(0))
				.getAttribute("path");
		final String descriptionAttribName = ((Element) descriptionNode.item(0))
				.getAttribute("attrib");
		if (descriptionElemName.length() == 0
				|| descriptionAttribName.length() == 0) {
			System.err
					.println("Invalid or missing description configuration tag!");
			System.exit(1);
		}

		return new InputConfiguration(parserClassName, defectElemName,
				fileElemName, fileAttribName, checkerElemName,
				checkerAttribName, eventElemName, eventAttribName,
				lineElemName, lineAttribName, functionElemName,
				functionAttribName, descriptionElemName, descriptionAttribName);
	}

	private void prepareIntermediateDirectory() throws IOException {
		// parse PMD input
		FileWriter versionEmitFile = null;
		FileWriter domainEmitFile = null;
		FileWriter versionOutputFile = null;
		FileWriter domainOutputFile = null;

		try {
			// setup directories
			System.out.println("Preparing intermdireate directory");

			File outputDirectory = new File("output/intdir");
			outputDirectory.mkdir();

			outputDirectory = new File(CoveritySaFormatter.OUTPUT_PATH);
			outputDirectory.mkdir();

			outputDirectory = new File(CoveritySaFormatter.OUTPUT_PATH
					+ "/emit");
			outputDirectory.mkdir();

			outputDirectory = new File(CoveritySaFormatter.OUTPUT_PATH
					+ "/output");
			outputDirectory.mkdir();

			// create meta files
			versionEmitFile = new FileWriter(CoveritySaFormatter.OUTPUT_PATH
					+ "/emit/version");
			versionEmitFile
					.write("# Version file created with Prevent version 5.4.1\n64");
			domainEmitFile = new FileWriter(CoveritySaFormatter.OUTPUT_PATH
					+ "/emit/cov-domain-tag");
			domainEmitFile.write("C#\n");

			versionOutputFile = new FileWriter(CoveritySaFormatter.OUTPUT_PATH
					+ "/output/version");
			versionOutputFile
					.write("# Version file created with Prevent version 5.4.1\n64");
			domainOutputFile = new FileWriter(CoveritySaFormatter.OUTPUT_PATH
					+ "/output/cov-domain-tag");
			domainOutputFile.write("C#\n");
		} finally {
			try {
				if (versionEmitFile != null) {
					versionEmitFile.close();
				}

				if (versionOutputFile != null) {
					versionOutputFile.close();
				}

				if (domainEmitFile != null) {
					domainEmitFile.close();
				}

				if (domainOutputFile != null) {
					domainOutputFile.close();
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}

	public void parse() {
		try {
			// read the configuration file and prepare the intermediate
			// directory
			InputConfiguration configuration = loadConfigurationFile();
			prepareIntermediateDirectory();

			System.out.println("Parsing input file: " + filename);
			DocumentBuilderFactory domFactory = DocumentBuilderFactory
					.newInstance();
			domFactory.setNamespaceAware(true); // never forget this!
			DocumentBuilder builder = domFactory.newDocumentBuilder();
			Document doc = builder.parse(this.filename);

			XPathFactory factory = XPathFactory.newInstance();
			XPath xpath = factory.newXPath();
			XPathExpression fileExpr = xpath.compile(configuration
					.getFileElemName());

			xpath = factory.newXPath();
			XPathExpression defectExpr = xpath.compile(configuration
					.getDefectElemName());

			xpath = factory.newXPath();
			XPathExpression checkerExpr = xpath.compile(configuration
					.getCheckerElemName());

			xpath = factory.newXPath();
			XPathExpression eventExpr = xpath.compile(configuration
					.getEventElemName());

			xpath = factory.newXPath();
			XPathExpression lineExpr = xpath.compile(configuration
					.getLineElemName());

			xpath = factory.newXPath();
			XPathExpression descExpr = xpath.compile(configuration
					.getDescriptionElemName());

			NodeList fileNodes = (NodeList) fileExpr.evaluate(doc,
					XPathConstants.NODESET);
			
			StringBuffer functionMetrics = new StringBuffer();
			if (fileNodes != null) {
				for (int i = 0; i < fileNodes.getLength(); i++) {
					Element fileElem = (Element) fileNodes.item(i);
					final String filename = fileElem.getAttribute(configuration
							.getFileAttribName()).replace('\\', '/');
					
					// load the parser
					Parser parser = null;
					final String parserClassName = configuration.getParserClassName();
					if (parserClassName.length() > 0) {
						parser = (Parser) Class.forName(parserClassName).newInstance();
					}
					System.out.println("Parsing source file: " + filename);
					
					// TODO: not parse if filename is provided
					if (parser.parse(filename, functionMetrics)) {
						this.functionCount += parser.getFunctionCount();
						this.lineCount += parser.getLineCount();

						// generate a list of defects
						NodeList defectNodes = (NodeList) defectExpr.evaluate(
								fileElem, XPathConstants.NODESET);
						for (int j = 0; j < defectNodes.getLength(); j++) {
							Element defectElem = (Element) defectNodes.item(j);

							// get rule
							NodeList checkerNodes = (NodeList) checkerExpr
									.evaluate(defectElem,
											XPathConstants.NODESET);
							if (checkerNodes.getLength() != 1) {
								System.err.println("Invalid checker tag!");
								System.exit(1);
							}
							Element checkerElem = (Element) checkerNodes
									.item(0);
							String rule;
							if (!configuration.getCheckerAttribName().equals(
									"#")) {
								rule = checkerElem.getAttribute(configuration
										.getCheckerAttribName());
							} else {
								rule = checkerElem.getFirstChild()
										.getNodeValue();
							}
							rule = rule.substring(rule.lastIndexOf('.') + 1,
									rule.length());
							rule = "EXT:" + rule;

							// get event
							NodeList eventNodes = (NodeList) eventExpr
									.evaluate(defectElem,
											XPathConstants.NODESET);
							if (eventNodes.getLength() != 1) {
								System.err.println("Invalid event tag!");
								System.exit(1);
							}
							Element eventElem = (Element) eventNodes.item(0);
							String event;
							if (!configuration.getEventAttribName().equals("#")) {
								event = eventElem.getAttribute(configuration
										.getEventAttribName());
							} else {
								event = eventElem.getFirstChild()
										.getNodeValue();
							}

							// get line
							NodeList lineNodes = (NodeList) lineExpr.evaluate(
									defectElem, XPathConstants.NODESET);
							if (lineNodes.getLength() != 1) {
								System.err.println("Invalid line tag!");
								System.exit(1);
							}
							Element lineElem = (Element) lineNodes.item(0);
							String line;
							if (!configuration.getLineAttribName().equals("#")) {
								line = lineElem.getAttribute(configuration
										.getLineAttribName());
							} else {
								line = lineElem.getFirstChild().getNodeValue();
							}

							// get function
							String function = parser.getFunction(Integer.parseInt(line));

							// get description
							NodeList descNodes = (NodeList) descExpr.evaluate(
									defectElem, XPathConstants.NODESET);
							if (descNodes.getLength() != 1) {
								System.err.println("Invalid desc tag!");
								System.exit(1);
							}
							Element descElem = (Element) descNodes.item(0);
							String description;
							if (!configuration.getDescriptionAttribName()
									.equals("#")) {
								description = descElem
										.getAttribute(configuration
												.getDescriptionAttribName());
							} else {
								description = descElem.getFirstChild()
										.getNodeValue();
							}
							
							if(filename == null || filename.length() == 0) {
								System.err.println("Invalid filename value!");
								System.exit(1);
							}
							
							if(rule == null || rule.length() == 0) {
								System.err.println("Invalid rule value!");
								System.exit(1);
							}
							
							if(event == null || event.length() == 0) {
								System.err.println("Invalid event value!");
								System.exit(1);
							}
							
							if(line == null || line.length() == 0) {
								System.err.println("Invalid line value!");
								System.exit(1);
							}
							
							if(function == null || function.length() == 0) {
								System.err.println("Invalid function value!");
								System.exit(1);
							}
							
							if(description == null || description.length() == 0) {
								System.err.println("Invalid description value!");
								System.exit(1);
							}
							
							// add new defect
							defects.add(new CoveritySaFormatter.Defect(
									filename, rule, event, line, function,
									description));
						}
					} else {
						throw new IOException("Unable to parse source file "
								+ filename);
					}
				}
			}
			// generate intermediate files
			if (fileNodes.getLength() > 0) {
				System.out.println("Writing intermdireate files");
				CoveritySaFormatter writer = new CoveritySaFormatter(defects, functionMetrics.toString());
				writer.write();
				System.out.println("------------------");
				DecimalFormat decimalFormat = new DecimalFormat("###,###,###");
				System.out.println("Processed "
						+ decimalFormat.format(fileNodes.getLength())
						+ " file(s), " + decimalFormat.format(this.lineCount)
						+ " LOC and "
						+ decimalFormat.format(this.functionCount)
						+ " function(s)");
			} else {
				System.out
						.println("No defects where deteced or no files where scanned.");
				System.exit(1);
			}
		} catch (ParserConfigurationException e) {
			e.printStackTrace();
		} catch (SAXException e) {
			e.printStackTrace();
		} catch (IOException e) {
			System.err
					.println("Unable to open input file or write intermediate directory.");
		} catch (InstantiationException e) {
			System.err.println("Unable unable to load specified parser.");
		} catch (IllegalAccessException e) {
			System.err.println("Unable unable to load specified parser.");
		} catch (ClassNotFoundException e) {
			System.err.println("Unable unable to load specified parser.");
		} catch (XPathExpressionException e) {
			e.printStackTrace();
		}
	}
}