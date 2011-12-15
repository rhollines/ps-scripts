package com.coverity.ps.sac.parser.as;

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
 * ActionScript 3.0 language parser that detects classes and methods.
 * @author rhollines
 */
public class ActionScriptParser implements Parser {
	static int parseCount = 0;
	private List<ActionScriptScanner.Token> tokens;
	private int index = 0;
	ActionScriptScanner.Token currentToken;
	Map<Integer, String> functions = new HashMap<Integer, String>();
	private ActionScriptScanner scanner;
	private StringBuffer functionMetrics;
	private String filename;
	private int functionCount = 0;
	
	/**
	 * Default Constructor
	 * 
	 */
	public ActionScriptParser() {
	}
	
	/**
	 * Initializes the parser class
	 * 
	 * @param filename file to parse
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
			this.scanner = new ActionScriptScanner(source);
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
			ActionScriptParser parser = new ActionScriptParser();
			parser.parse(args[0], new StringBuffer());
		}
	}
	
	/**
	 * Get next token
	 */
	private void nextToken() {
		if (index < tokens.size()) {
			currentToken = (ActionScriptScanner.Token) tokens.get(index++);
		} else {
			currentToken = new ActionScriptScanner.Token(-1,
					ActionScriptScanner.Token.Type.EOS);
		}
	}

	/**
	 * Get next token
	 * 
	 * @param i position
	 */
	private ActionScriptScanner.Token getToken(int i) {
		if (i < tokens.size()) {
			return tokens.get(i);
		}

		return new ActionScriptScanner.Token(-1,
				ActionScriptScanner.Token.Type.EOS);
	}

	private boolean match(ActionScriptScanner.Token.Type type) {
		return type == currentToken.getType();
	}

	private ActionScriptScanner.Token.Type getTokenType() {
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
	 * @throws IOException 
	 */
	public boolean parse(String filename, StringBuffer functionMetrics) throws IOException {
		initialize(filename);
		this.functionMetrics = functionMetrics;
		
		StringBuilder packageName = new StringBuilder();
		String className = "";
		while (!match(ActionScriptScanner.Token.Type.EOS)) {
			if (match(ActionScriptScanner.Token.Type.PACKAGE)) {
				nextToken();
				while (match(ActionScriptScanner.Token.Type.IDENT)) {
					packageName.append(currentToken.getValue());
					nextToken();
					if (match(ActionScriptScanner.Token.Type.DOT)) {
						packageName.append('.');
						nextToken();
					}
				}
			}

			if (match(ActionScriptScanner.Token.Type.CLASS)) {
				nextToken();
				className = currentToken.getValue();
			}

			// found a function
			if (match(ActionScriptScanner.Token.Type.FUNCTION)) {
				int start = currentToken.getLineNumber();
				nextToken();

				// check to see if we have an anonymous function
				final String functionName = currentToken.getValue() == "(" ? "unknown"
						: (packageName.toString() + "." + className + "." + currentToken
								.getValue());
				this.functionCount ++;
				
				// add function entry
				this.functionMetrics.append("<fnmetric><file>");
				this.functionMetrics.append(this.filename);
				this.functionMetrics.append("</file><fnmet>");
				this.functionMetrics.append(functionName);
				this.functionMetrics.append("</fnmet></fnmetric>");
				
				// find function end via curly braces
				int state = -1;
				do {
					nextToken();

					if (currentToken.getLineNumber() != start) {
						functions.put(start, functionName);
						start = currentToken.getLineNumber();
					}

					if (match(ActionScriptScanner.Token.Type.OCBR)) {
						if (state < 0) {
							state = 1;
						} else {
							state++;
						}
					}

					if (match(ActionScriptScanner.Token.Type.CCBR)) {
						state--;
					}
				} while (!match(ActionScriptScanner.Token.Type.EOS) && state != 0);
				functions.put(start, functionName);
			}
			
			// default update
			nextToken();
		}

		return true;
	}
}
