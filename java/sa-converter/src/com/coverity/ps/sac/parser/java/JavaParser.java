package com.coverity.ps.sac.parser.java;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.coverity.ps.sac.io.CoveritySaFormatter;
import com.coverity.ps.sac.parser.Parser;

/**
 * Java language parser that detects classes and methods.
 * @author rhollines
 */
public class JavaParser implements Parser {
	static int parseCount = 0;
	private List<JavaScanner.Token> tokens;
	private int index = 0;
	JavaScanner.Token currentToken;
	Map<Integer, String> functions = new HashMap<Integer, String>();
	private JavaScanner scanner;
	String className = "";
	private StringBuffer functionMetrics;
	private String filename;
	private int functionCount = 0;

	/**
	 * Default Constructor
	 * 
	 */
	public JavaParser() {
	}

	/**
	 * Initializes the parser class
	 * 
	 * @param filename
	 *            file to parse
	 */
	private void initialize(String filename) throws IOException {
		this.filename = filename;
		BufferedReader reader = null;
		FileWriter inclFile = null;
		FileWriter sourceFile = null;
		try {
			// read file
			StringBuilder input = new StringBuilder();
			reader = new BufferedReader(new FileReader(filename));
			String line = reader.readLine();
			while (line != null) {
				input.append(line);
				input.append('\n');
				line = reader.readLine();
			}

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

			outputDirectory = new File(CoveritySaFormatter.OUTPUT_PATH
					+ "/emit/f" + (parseCount++));
			outputDirectory.mkdir();

			// create incl file
			inclFile = new FileWriter(outputDirectory.toString() + "/incl");
			inclFile.write(filename + '|');

			// create source file
			final String source = input.toString();
			sourceFile = new FileWriter(outputDirectory.toString() + "/source");
			sourceFile.write(source);

			// scan source
			this.scanner = new JavaScanner(source);
			tokens = this.scanner.scan();
			nextToken();
		} finally {
			try {
				if (reader != null) {
					reader.close();
				}

				if (inclFile != null) {
					inclFile.close();
				}

				if (sourceFile != null) {
					sourceFile.close();
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}

	public static void main(String[] args) throws Exception {
		if (args.length > 0) {
			JavaParser parser = new JavaParser();
			parser.parse(args[0], new StringBuffer());
		}
	}

	/**
	 * Get next token
	 */
	private void nextToken() {
		if (index < tokens.size()) {
			currentToken = (JavaScanner.Token) tokens.get(index++);
		} else {
			currentToken = new JavaScanner.Token(-1,
					JavaScanner.Token.Type.EOS);
		}
	}

	/**
	 * Get next token
	 * 
	 * @param i
	 *            position
	 */
	private JavaScanner.Token getToken(int i) {
		if (i < tokens.size()) {
			return tokens.get(i);
		}

		return new JavaScanner.Token(-1, JavaScanner.Token.Type.EOS);
	}

	private boolean match(JavaScanner.Token.Type type) {
		return type == currentToken.getType();
	}

	private JavaScanner.Token.Type getTokenType() {
		return currentToken.getType();
	}

	private int getTokenLineNumber() {
		return currentToken.getLineNumber();
	}

	private String getTokenValue() {
		return currentToken.getValue();
	}

	public String getFunction(int lineNumber) {
		String function = this.functions.get(lineNumber);
		if (function != null) {
			return function;
		}

		return "unknown";
	}

	public int getFunctionCount() {
		return this.functionCount;
	}

	public int getLineCount() {
		return this.scanner.getLineCount();
	}

	/**
	 * Parses ActionScript file
	 * 
	 * @throws IOException
	 */
	public boolean parse(String filename, StringBuffer functionMetrics) throws IOException {
		initialize(filename);
		this.functionMetrics = functionMetrics;

		String packageName = "";
		while (!match(JavaScanner.Token.Type.EOS)) {
			// match package
			if (match(JavaScanner.Token.Type.PACKAGE)) {
				nextToken();
				packageName = parseIdentifier();

				System.out.println("package='" + packageName + "'");
			}

			// match class
			while (match(JavaScanner.Token.Type.CLASS)) {
				nextToken();
				String classIdent = parseIdentifier();
				if (this.className.length() > 0) {
					classIdent = this.className + '.' + classIdent;
				} else if (packageName.length() > 0) {
					classIdent = packageName + '.' + classIdent;
				}
				className = classIdent;

//				System.out.println("class='" + className + "'");
			}

			// attempt to match a method
			if (match(JavaScanner.Token.Type.IDENT)) {
				String methodName = parseIdentifier();
				if (match(JavaScanner.Token.Type.OPRN)) {
					nextToken();

					StringBuffer buffer = new StringBuffer();
					buffer.append('(');
					boolean match = true;
					do {
						if (matchType(buffer)) {
							if (match(JavaScanner.Token.Type.IDENT)) {
								nextToken();
							}
							else {
								match = false;
							}					
						} else if(!match(JavaScanner.Token.Type.CPRN)) {
							match = false;
						}
					} while (match(JavaScanner.Token.Type.COMMA) && match);
					buffer.append(')');				
					nextToken();
					
					// verify we've matched a method (not a method call)
					if (match(JavaScanner.Token.Type.OCBR) && match) {
//						System.out.println("\tmethod='" + methodName+ buffer.toString() + "'");
						
						this.functionCount++;
						// add function entry
						this.functionMetrics.append("<fnmetric><file>");
						this.functionMetrics.append(this.filename);
						this.functionMetrics.append("</file><fnmet>");
						this.functionMetrics.append(methodName);
						this.functionMetrics.append("</fnmet></fnmetric>");
						
						int start = currentToken.getLineNumber();
						// find method end via curly braces
						int state = -1;
						do {
							nextToken();

							if (currentToken.getLineNumber() != start) {
								functions.put(start, methodName);
								start = currentToken.getLineNumber();
							}

							if (match(JavaScanner.Token.Type.OCBR)) {
								if (state < 0) {
									state = 1;
								} else {
									state++;
								}
							}

							if (match(JavaScanner.Token.Type.CCBR)) {
								state--;
							}
						} while (!match(JavaScanner.Token.Type.EOS) && 
								state != 0);
						functions.put(start, methodName);
					}
				}
			}

			// default update
			nextToken();
		}

		return true;
	}

	private boolean matchType() {
		return matchType(null);
	}

	private boolean matchType(StringBuffer buffer) {
		boolean isType = false;

		switch (getTokenType()) {
		case VOID:
			if (buffer != null) {
				buffer.append("void");
			}
			nextToken();
			isType = true;
			break;

		case BYTE:
			if (buffer != null) {
				buffer.append("byte");
			}
			nextToken();
			isType = true;
			break;

		case SHORT:
			if (buffer != null) {
				buffer.append("short");
			}
			nextToken();
			isType = true;
			break;

		case CHAR:
			if (buffer != null) {
				buffer.append("char");
			}
			nextToken();
			isType = true;
			break;

		case INT:
			if (buffer != null) {
				buffer.append("int");
			}
			nextToken();
			isType = true;
			break;

		case LONG:
			if (buffer != null) {
				buffer.append("long");
			}
			nextToken();
			isType = true;
			break;

		case FLOAT:
			if (buffer != null) {
				buffer.append("float");
			}
			nextToken();
			isType = true;
			break;

		case DOUBLE:
			if (buffer != null) {
				buffer.append("double");
			}
			nextToken();
			isType = true;
			break;

		case BOOLEAN:
			if (buffer != null) {
				buffer.append("boolean");
			}
			nextToken();
			isType = true;
			break;

		case IDENT: {
			if (buffer != null) {
				buffer.append(currentToken.getValue());
			}
			parseIdentifier();
			isType = true;
		}
			break;
		}

		if (isType) {
			matchGeneric(buffer);
			matchArray(buffer);
			if (match(JavaScanner.Token.Type.DOT)) {
				nextToken();
				if (match(JavaScanner.Token.Type.DOT)) {
					nextToken();
					if (match(JavaScanner.Token.Type.DOT)) {
						nextToken();
						buffer.append("...");
					}
				}
			}
		}

		return isType;
	}

	private boolean matchGeneric(StringBuffer buffer) {
		if (match(JavaScanner.Token.Type.LESS)) {
			if (buffer != null) {
				buffer.append('<');
			}
			nextToken();
			if (matchType(buffer)) {
				if (match(JavaScanner.Token.Type.GTR)) {
					if (buffer != null) {
						buffer.append('>');
					}
					nextToken();
					return true;
				}
			}
		}

		return false;
	}

	private boolean matchArray(StringBuffer buffer) {
		if (match(JavaScanner.Token.Type.OBR)) {
			while (match(JavaScanner.Token.Type.OBR)) {
				if (buffer != null) {
					buffer.append('[');
				}
				nextToken();
				if (match(JavaScanner.Token.Type.CBR)) {
					if (buffer != null) {
						buffer.append(']');
					}
					nextToken();
				}
			}

			return true;
		}

		return false;
	}

	private String parseIdentifier() {
		StringBuffer ident = new StringBuffer();
		boolean extend = true;
		while (match(JavaScanner.Token.Type.IDENT) && extend) {
			ident.append(currentToken.getValue());
			nextToken();
			if (match(JavaScanner.Token.Type.DOT)
					&& getToken(index + 1).getType() != JavaScanner.Token.Type.DOT) {
				ident.append('.');
				nextToken();
				extend = true;
			} else {
				extend = false;
			}
		}

		return ident.toString();
	}
}
