package com.coverity.ps.sac.parser.java;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The MIT License (MIT)
 * Copyright (c) 2007 Randy Hollines - jhttphtml project
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a 
 * copy of this software and associated documentation files (the "Software"), 
 * to deal in the Software without restriction, including without limitation 
 * the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
 * sell copies of the Software, and to permit persons to whom the Software is 
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in 
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
 * IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 * Java language scanner
 * @author rhollines
 * 
 */
public class JavaScanner {
	private static final char EOS = '\0';
	private static Map<String, Token.Type> keyWords = new HashMap<String, Token.Type>();

	// keywords
	static {
		keyWords.put("abstract", Token.Type.ABSTRACT);
		keyWords.put("continue", Token.Type.CONTINUE);	
		keyWords.put("for", Token.Type.FOR);
		keyWords.put("new", Token.Type.NEW);
		keyWords.put("switch", Token.Type.SWITCH);
		keyWords.put("assert", Token.Type.ASSERT);
		keyWords.put("default", Token.Type.DEFAULT);
		keyWords.put("goto", Token.Type.GOTO);
		keyWords.put("package", Token.Type.PACKAGE);
		keyWords.put("synchronized", Token.Type.SYNCHRONIZED);
		keyWords.put("boolean", Token.Type.BOOLEAN);
		keyWords.put("do", Token.Type.DO);
		keyWords.put("if", Token.Type.IF);
		keyWords.put("private", Token.Type.PRIVATE);
		keyWords.put("this", Token.Type.THIS);
		keyWords.put("break", Token.Type.BREAK);
		keyWords.put("double", Token.Type.DOUBLE);
		keyWords.put("implements", Token.Type.IMPLEMENTS);
		keyWords.put("protected", Token.Type.PROTECTED);
		keyWords.put("throw", Token.Type.THROW);
		keyWords.put("byte", Token.Type.BYTE);
		keyWords.put("else", Token.Type.ELSE);
		keyWords.put("import", Token.Type.IMPORT);
		keyWords.put("public", Token.Type.PUBLIC);
		keyWords.put("throws", Token.Type.THROWS);
		keyWords.put("case", Token.Type.CASE);
		keyWords.put("enum", Token.Type.ENUM);
		keyWords.put("instanceof", Token.Type.INSTANCEOF);
		keyWords.put("return", Token.Type.RETURN);
		keyWords.put("transient", Token.Type.TRANSIENT);
		keyWords.put("catch", Token.Type.CATCH);
		keyWords.put("extends", Token.Type.EXTENDS);
		keyWords.put("int", Token.Type.INT);
		keyWords.put("short", Token.Type.SHORT);
		keyWords.put("try", Token.Type.TRY);
		keyWords.put("char", Token.Type.CHAR);
		keyWords.put("final", Token.Type.FINAL);
		keyWords.put("interface", Token.Type.INTERFACE);
		keyWords.put("static", Token.Type.STATIC);
		keyWords.put("void", Token.Type.VOID);
		keyWords.put("class", Token.Type.CLASS);
		keyWords.put("finally", Token.Type.FINALLY);
		keyWords.put("long", Token.Type.LONG);
		keyWords.put("strictfp", Token.Type.STRICTFP);
		keyWords.put("volatile", Token.Type.VOLATILE);
		keyWords.put("const", Token.Type.CONST);
		keyWords.put("float", Token.Type.FLOAT);
		keyWords.put("native", Token.Type.NATIVE);
		keyWords.put("super", Token.Type.SUPER);
		keyWords.put("while", Token.Type.WHILE);
		// reserved literals
		keyWords.put("false", Token.Type.FALSE);
		keyWords.put("null", Token.Type.NULL);
		keyWords.put("true", Token.Type.TRUE);
	}

	String code;
	private int startIndex = 0;
	private int endIndex = 0;
	private char[] codeChars;
	private int scanPosition = 0;
	private int lineNumber = 1;
	private char currentChar, nextChar;

	/**
	 * Default constructor
	 * 
	 * @param code
	 *            code to scan represented as a string
	 */
	public JavaScanner(String code) {
		this.code = code;
		codeChars = code.toCharArray();
		nextChar();
	}

	/**
	 * Scans tokens
	 */
	public List<Token> scan() {
		List<Token> tokens = new ArrayList<Token>();
		Token token = null;
		do {
			token = getNextToken();
			if(token.getType() != Token.Type.OTHER) {
				tokens.add(token);
			}
		} while (token.getType() != Token.Type.EOS);
/*		
		for(Token t : tokens) {
			System.out.print("### " + t + " ###\n");
		}
*/
		return tokens;
	}
	
	public int getLineCount() {
		return this.lineNumber;
	}

	/**
	 * Gets the next character in the stream
	 */
	private void nextChar() {
		if (scanPosition < codeChars.length) {
			currentChar = codeChars[scanPosition++];
			if (scanPosition < codeChars.length) {
				nextChar = codeChars[scanPosition];
			} else {
				nextChar = EOS;
			}
		} else {
			currentChar = EOS;
		}
	}

	/**
	 * Ignores whitespace
	 */
	private void whiteSpace() {
		while (currentChar != EOS
				&& (currentChar == ' ' || currentChar == '\t'
						|| currentChar == '\n' || currentChar == '\r')) {
			if (currentChar == '\n') {
				lineNumber++;
			}
			nextChar();
		}
	}

	/**
	 * Gets the next token
	 */
	private Token getNextToken() {
		// ignore white space
		whiteSpace();

		// skip multi-line comment
		if (currentChar == '/' && nextChar == '*') {
			nextChar();
			nextChar();
			boolean done = false;
			while (currentChar != EOS && !done) {
				if (currentChar == '\n') {
					lineNumber++;
				}
				// find end
				if (currentChar == '*' && nextChar == '/') {
					done = true;
					nextChar();
				}
				nextChar();
			}

			return new Token(lineNumber, Token.Type.COMMENT, "/* */");
		}

		// skip single-line comment
		if (currentChar == '/' && nextChar == '/') {
			nextChar();
			nextChar();
			while (currentChar != EOS && currentChar != '\n') {
				nextChar();
			}
			lineNumber++;
			nextChar();

			return new Token(lineNumber - 1, Token.Type.COMMENT, "//");
		}

		// parse string
		if (currentChar == '"') {
			startIndex = endIndex = scanPosition - 1;
			nextChar();
			endIndex++;
			while (currentChar != EOS && currentChar != '"') {
				if (currentChar == '\\' && nextChar == '"') {
					nextChar();
					endIndex++;
				}
				nextChar();
				endIndex++;
			}
			nextChar();
			endIndex++;

			return new Token(lineNumber, Token.Type.STRING, code.substring(
					startIndex, endIndex));
		} else if (Character.isLetter(currentChar) || currentChar == '_') {
			startIndex = endIndex = scanPosition - 1;
			while (Character.isLetterOrDigit(currentChar) || currentChar == '_') {
				nextChar();
				endIndex++;
			}

			return lookupIdent(code.substring(startIndex, endIndex));
		} else if (Character.isDigit(currentChar) || (currentChar == '.' && Character.isDigit(nextChar))) {
			startIndex = endIndex = scanPosition - 1;
			boolean foundDot = false;
			while (Character.isDigit(currentChar) || currentChar == '.') {
				// could check for scan error here
				if (currentChar == '.') {
					foundDot = true;
				}
				nextChar();
				endIndex++;
			}
			// return result
			if (foundDot) {
				return new Token(lineNumber, Token.Type.NUM, code.substring(
						startIndex, endIndex));
			} else {
				return new Token(lineNumber, Token.Type.INTEGER,
						code.substring(startIndex, endIndex));
			}
		} else {
			Token token = null;
			switch (currentChar) {
			// TODO: >>=, >>>=, <<=, <<<=, ===, !==, &&=, ||=, ...
			case EOS:
				token = new Token(lineNumber, Token.Type.EOS);
				nextChar();
				break;

			case ':':
				if (nextChar == ':') {
					nextChar();
					token = new Token(lineNumber, Token.Type.NAME_QUAL, "::");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.TYPE, ":");
					nextChar();
				}
				break;

			case ';':
				token = new Token(lineNumber, Token.Type.SEMI_COLON, ";");
				nextChar();
				break;

			case '{':
				token = new Token(lineNumber, Token.Type.OCBR, "{");
				nextChar();
				break;

			case '}':
				token = new Token(lineNumber, Token.Type.CCBR, "}");
				nextChar();
				break;

			case '[':
				token = new Token(lineNumber, Token.Type.OBR, "[");
				nextChar();
				break;

			case ']':
				token = new Token(lineNumber, Token.Type.CBR, "]");
				nextChar();
				break;

			case '.':
				token = new Token(lineNumber, Token.Type.DOT, ".");
				nextChar();
				break;

			case '#':
				token = new Token(lineNumber, Token.Type.POUND, ".");
				nextChar();
				break;

			case '(':
				token = new Token(lineNumber, Token.Type.OPRN, "(");
				nextChar();
				break;

			case ')':
				token = new Token(lineNumber, Token.Type.CPRN, ")");
				nextChar();
				break;
				
			case '@':
				token = new Token(lineNumber, Token.Type.AT, ")");
				nextChar();
				break;

			case '=':
				token = new Token(lineNumber, Token.Type.EQL, "=");
				nextChar();
				break;

			case ',':
				token = new Token(lineNumber, Token.Type.COMMA, ",");
				nextChar();
				break;

			case '~':
				token = new Token(lineNumber, Token.Type.NOT, "~");
				nextChar();
				break;

			case '|':
				if (nextChar == '|') {
					nextChar();
					token = new Token(lineNumber, Token.Type.OR_OR, "||");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.OR, "|");
					nextChar();
				}
				break;

			case '?':
				token = new Token(lineNumber, Token.Type.QUESTION, "?");
				nextChar();
				break;

			case '&':
				if (nextChar == '&') {
					nextChar();
					token = new Token(lineNumber, Token.Type.AND_AND, "&&");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.AND, "&");
					nextChar();
				}
				break;

			case '+':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.ADD_EQL, "+=");
					nextChar();
				} else if (nextChar == '+') {
					nextChar();
					token = new Token(lineNumber, Token.Type.INC, "++");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.ADD, "+");
					nextChar();
				}
				break;

			case '-':
				if (nextChar == '-') {
					nextChar();
					token = new Token(lineNumber, Token.Type.DECL, "--");
					nextChar();
				} else if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.MINUS_EQL, "-=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.MINUS, "-");
					nextChar();
				}
				break;

			case '*':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.MUL_EQL, "*=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.MUL, "*");
					nextChar();
				}
				break;

			case '/':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.DIV_EQL, "/=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.DIV, "/");
					nextChar();
				}
				break;

			case '%':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.MOD_EQL, "%=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.MOD, "%");
					nextChar();
				}
				break;

			case '!':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.NEQL, "!=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.NEG, "NEG");
					nextChar();
				}
				break;

			case '<':
				if (nextChar == '<') {
					nextChar();
					token = new Token(lineNumber, Token.Type.LEFT_SHIFT, "<<");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.LESS, "<");
					nextChar();
				}
				break;

			case '>':
				if (nextChar == '=') {
					nextChar();
					token = new Token(lineNumber, Token.Type.GTR_EQL, ">=");
					nextChar();
				} else {
					token = new Token(lineNumber, Token.Type.GTR, ">");
					nextChar();
				}
				break;

			case '\'':
				nextChar();
				token = new Token(lineNumber, Token.Type.CHAR,
						Character.toString(currentChar));
				nextChar();
				nextChar();
				break;

			default:
				// we only care about ASCII characters
				if(currentChar < 128) {
					System.err.print("Unknown token: " + currentChar + " line=" + lineNumber);
					System.exit(1);
				}
				token = new Token(lineNumber, Token.Type.OTHER, "*OTHER* " + currentChar);
				nextChar();
				break;
			}
			// return token
			return token;
		}
	}

	/**
	 * Checks to see if an identifier is a keyword
	 */
	private Token lookupIdent(String ident) {
		Token.Type tokenType = keyWords.get(ident);
		if (tokenType == null) {
			return new Token(lineNumber, Token.Type.IDENT, ident);
		} else {
			return new Token(lineNumber, tokenType, ident);
		}
	}

	/**
	 * Token class
	 */
	public static class Token {
		public enum Type {
			// tokens
			OTHER, 
			EOS, 
			COMMENT, 
			STRING, 
			IDENT, 
			CHAR, 
			GTR, 
			NUM, 
			LESS, 
			GTR_EQL, 
			LEFT_SHIFT, 
			NEG, 
			NEQL, 
			MOD, 
			MOD_EQL, 
			DIV, 
			DIV_EQL, 
			MUL, 
			MUL_EQL, 
			MINUS, 
			MINUS_EQL, 
			DECL, 
			INTEGER, 
			NAME_QUAL, 
			TYPE, 
			ADD, 
			INC, 
			SEMI_COLON, 
			ADD_EQL, 
			OCBR, 
			AND, 
			DOT, 
			AND_AND, 
			POUND, 
			OR_OR, 
			NOT, 
			CBR, 
			CCBR, 
			AT, 
			OBR, 
			QUESTION, 
			EQL, 
			OR, 
			OPRN, 
			COMMA, 
			CPRN, 
			FALSE, 
			NULL, 
			TRUE, 
			ABSTRACT, 
			CONTINUE, 
			FOR, 
			PACKAGE, 
			TRANSIENT, 
			ASSERT, 
			WHILE, 
			SUPER, 
			NATIVE, 
			FLOAT, 
			NEW, 
			SWITCH, 
			GOTO, 
			DEFAULT, 
			CONST, 
			VOLATILE, 
			THROWS, 
			INSTANCEOF, 
			RETURN, 
			STATIC, 
			PROTECTED, 
			EXTENDS, 
			VOID, 
			ELSE, 
			ENUM, 
			BOOLEAN, 
			THIS, 
			IF, 
			PUBLIC, 
			FINALLY, 
			STRICTFP, 
			LONG, 
			SYNCHRONIZED, 
			DO, 
			PRIVATE, 
			DOUBLE, 
			TRY, 
			CLASS, 
			THROW, 
			INT, 
			FINAL, 
			INTERFACE, 
			BREAK, 
			SHORT, 
			CATCH, 
			CASE, 
			IMPLEMENTS, 
			BYTE, 
			IMPORT
		}

		private Type type;
		private String value;
		private int lineNumber;

		/**
		 * Constructor
		 */
		public Token(int lineNumber, Type type) {
			this(lineNumber, type, "");
		}

		/**
		 * Constructor
		 */
		public Token(int lineNumber, Type type, String value) {
			this.lineNumber = lineNumber;
			this.type = type;
			this.value = value;
			this.lineNumber = lineNumber;
		}

		public Type getType() {
			return this.type;
		}

		public int getLineNumber() {
			return this.lineNumber;
		}

		public String getValue() {
			return value;
		}

		public String toString() {
			StringBuilder buffer = new StringBuilder();
			buffer.append(type);
			buffer.append(":");
			buffer.append(lineNumber);
			buffer.append("-> '");
			buffer.append(value);
			buffer.append("'");
			return buffer.toString();
		}
	}
}