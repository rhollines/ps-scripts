package com.coverity.ps.sac;

import java.text.DecimalFormat;

import com.coverity.ps.sac.io.InputParser;

/**
 * Driver for the static analysis converter
 * 
 * @author rhollines
 */
public class SaConverter {
	public static void main(String[] args) throws Exception {
		if (args.length > 0) {
			long startTime = System.nanoTime();
			
			InputParser parser = new InputParser(args[0]);
			parser.parse();
			
			long estimatedTime = System.nanoTime() - startTime;
			DecimalFormat decimalFormat = new DecimalFormat("#.##");
			System.out.println("Conversion  time: "	+ decimalFormat.format(estimatedTime * 0.000000001) + " sec(s)");
		}
	}
}
