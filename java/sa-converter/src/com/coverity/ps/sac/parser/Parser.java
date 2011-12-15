package com.coverity.ps.sac.parser;

import java.io.IOException;


/**
 * Interface for language parsers.
 * @author rhollines
 */
public interface Parser {
	/**
	 * Returns the number of functions in a file
	 */
	public int getFunctionCount();
	
	/**
	 * Returns the number of lines in a file
	 */
	public int getLineCount();
	
	/**
	 * Returns function name for the give line number
	 */
	public String getFunction(int lineNumber);
	
	/**
	 * Parses the source file
	 * @param functionMetrics 
	 * @throws IOException 
	 * 
	 */
	public boolean parse(String filename, StringBuffer functionMetrics) throws IOException;
}
