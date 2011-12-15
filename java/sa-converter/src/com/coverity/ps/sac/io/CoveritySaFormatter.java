package com.coverity.ps.sac.io;

import java.io.FileWriter;
import java.io.IOException;
import java.util.List;

/**
 * Formats a list of defects into the Coverity C# directory format
 * 
 * @author rhollines
 */
public class CoveritySaFormatter {
	public static final String OUTPUT_PATH = "output/intdir/cs";
	List<Defect> defects;
	private String functionMetrics;

	/**
	 * This class is a holder for Coverity defect information.
	 */
	public static class Defect {
		private String fileName;
		private String rule;
		private String eventTag;
		private int line;
		private String function;
		private String descritpion;

		/**
		 * Defect constructor.
		 */
		public Defect(String fileName, String rule, String eventTag,
				String line, String function, String descritpion) {
			this.fileName = fileName;
			this.eventTag = eventTag;
			this.rule = rule;
			this.line = Integer.parseInt(line);
			this.function = function;
			this.descritpion = descritpion;
		}

		public String getRule() {
			return this.rule;
		}

		public String getEventTag() {
			return this.eventTag;
		}

		public String getFileName() {
			return this.fileName;
		}

		public String getFunction() {
			return this.function;
		}

		public String getDescritpion() {
			return this.descritpion;
		}

		public int getLine() {
			if (this.line < 1) {
				return 1;
			}
			return this.line;
		}
	}

	/**
	 * CoveritySaFormatter constructor.
	 * 
	 * @param defects
	 *            list of defects
	 * @param functionMetrics 
	 */
	public CoveritySaFormatter(List<Defect> defects, String functionMetrics) {
		this.defects = defects;
		this.functionMetrics = functionMetrics;
	}

	/**
	 * Writes defect information to the intermediate directory
	 * 
	 * @throws IOException
	 */
	public void write() throws IOException {
		FileWriter errorsWriter = null;
		FileWriter metricsWriter = null;
		try {
			StringBuilder errors = new StringBuilder();
			for (int i = 0; i < defects.size(); i++) {
				// generate errors XML
				errors.append("<error><checker>");
				errors.append(defects.get(i).getRule());
				errors.append("</checker><file>");
				errors.append(defects.get(i).getFileName());
				errors.append("</file><function>");
				errors.append(defects.get(i).getFunction().equals("unknown") ? "" :  defects.get(i).getFunction());
				errors.append("</function>");
				errors.append("<event><main>true</main><tag>");
				errors.append(defects.get(i).getEventTag());
				errors.append("</tag><description>");
				errors.append(defects.get(i).getDescritpion());
				errors.append("</description><line>");
				errors.append(defects.get(i).getLine());
				errors.append("</line><file>");
				errors.append(defects.get(i).getFileName());
				errors.append("</file></event><extra></extra><subcategory>none</subcategory></error>");
			}
			
			/*
		    // generate metrics xml
			metrics.append("<fnmetric><file>");
			metrics.append(defects.get(i).getFileName());
			metrics.append("</file><fnmet>");
			metrics.append(defects.get(i).getFunction());
			metrics.append("</fnmet></fnmetric>");
			 */
			
			errorsWriter = new FileWriter(OUTPUT_PATH
					+ "/output/defects.errors.xml");
			errorsWriter.write(errors.toString());

			metricsWriter = new FileWriter(OUTPUT_PATH
					+ "/output/METRICS.errors.xml");
			metricsWriter.write(this.functionMetrics);
		} finally {
			try {
				if (errorsWriter != null) {
					errorsWriter.close();
				}

				if (metricsWriter != null) {
					metricsWriter.close();
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}
}