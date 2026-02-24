/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;

import jakarta.servlet.ServletOutputStream;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.WriteListener;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;

/**
 * Response wrapper used to buffer the output of a server-side include. 
 */
public class ServletRackIncludedResponse extends HttpServletResponseWrapper {

	private final static int BUFFER_SIZE = 16 * 1024;  // 16K buffer size
	
	private int bufferSize;
	private ServletResponse wrappedResponse;
	private PrintWriter writer;
	private ServletOutputStream outputStream;
	private ByteArrayOutputStream outputStreamBuffer;
	
    /**
     * Wraps a response.
     * @param response the response
     * @see #setBufferSize(int)
     */
	public ServletRackIncludedResponse(HttpServletResponse response) {
		super(response);
		bufferSize = BUFFER_SIZE;
		wrappedResponse = response;
	}
	
	/**
	 * Returns the output of the include as a string, encoded by the
	 * character encoding available {@link #getCharacterEncoding()}}.
	 * @return the included output as a String
	 * @throws IOException if there's an IO exception
	 */
	public String getOutput() throws IOException {
        flushBuffer();
        String charEnc = super.getResponse().getCharacterEncoding();
        return outputStreamBuffer.toString(charEnc);
	}
	
	@Override
	public ServletResponse getResponse() {
		return wrappedResponse;
	}

	@Override
	public void setResponse(ServletResponse response) {
		wrappedResponse = response;
	}

	@Override
	public void flushBuffer() throws IOException {
		if (writer != null) {
			writer.flush();
		} else if (outputStream != null) {
			outputStream.flush();
		}
	}

	/**
	 * All content written to an included response is buffered,
	 * this method will return either the initial buffer size
	 * or the one specified using {@link #setBufferSize(int)}.
     * @return the (initial/set) buffer size
	 */
	@Override
	public int getBufferSize() {
		return bufferSize;
	}

	/**
	 * Calls to this method has no effect if the stream has already been written
     * to, unless {@link #resetBuffer()} is called.
     * @param size the buffer size (in bytes)
	 */
	@Override
	public void setBufferSize(int size) {
		bufferSize = size;
	}
    
	@Override
	public ServletOutputStream getOutputStream() throws IllegalStateException {
		if (writer != null) {
			throw new IllegalStateException("getWriter() has already been called for this response");
		}
		if (outputStream == null) {
			initializeOutputStream();
		}
		return outputStream;
	}

	@Override
	public PrintWriter getWriter() throws UnsupportedEncodingException, IllegalStateException {
		if (outputStream != null) {
			throw new IllegalStateException("getOutputStream() has already been called for this response");
		}
		if (writer == null) {
			initializeWriter();
		}
		return writer;
	}

	@Override
	public void reset() throws UnsupportedOperationException {
		throw new UnsupportedOperationException("Cannot reset an included response");
	}

	@Override
	public void resetBuffer() throws IllegalStateException {
		if ( getResponse().isCommitted() ) {
			throw new IllegalStateException("Illegal call to resetBuffer() after response has been committed");
		}
		if ( writer != null ) {
            try {
                initializeWriter();
            } // NOTE: should not happen since we've created a writer previously
            catch (UnsupportedEncodingException e) {
                throw new IllegalStateException(e);
            }
		}
        else if ( outputStream != null ) {
			initializeOutputStream();
		}
	}
	
	private void initializeWriter() throws UnsupportedEncodingException {
		String charSet = super.getResponse().getCharacterEncoding();
		outputStreamBuffer = new ByteArrayOutputStream(bufferSize);
		writer = new PrintWriter(new OutputStreamWriter(outputStreamBuffer, charSet));
	}
	
	private void initializeOutputStream() {
		String charSet = super.getResponse().getCharacterEncoding();
		outputStreamBuffer = new ByteArrayOutputStream(bufferSize);
		outputStream = new ByteArrayServletOutputStream(outputStreamBuffer, charSet);
	}
	
	/**
	 * Crunchy ServletOutputStream coating hiding a chewy ByteArrayOutputStream center. 
	 * @author bhaidri
	 */
	private static class ByteArrayServletOutputStream extends ServletOutputStream {
		
		private final static String LINE_SEPARATOR = System.lineSeparator();
		private final DataOutputStream dataOutputStream;
		private final String charSet;
		
		public ByteArrayServletOutputStream(ByteArrayOutputStream byteOutputStream, String charSet) {
			super();
			this.dataOutputStream = new DataOutputStream(byteOutputStream);
			this.charSet = charSet;
		}

		@Override
		public void write(byte[] b, int off, int len) throws IOException {
			dataOutputStream.write(b, off, len);
		}

		@Override
		public void write(byte[] b) throws IOException {
			dataOutputStream.write(b);
		}

		@Override
		public void write(int i) throws IOException {
			dataOutputStream.write(i);
		}

		@Override
		public void print(String s) throws IOException {
			dataOutputStream.write(s.getBytes(charSet));
		}

		@Override
		public void print(boolean b) throws IOException {
			dataOutputStream.writeBoolean(b);
		}

		@Override
		public void print(char c) throws IOException {
			dataOutputStream.writeChar(c);
		}

		@Override
		public void print(int i) throws IOException {
			dataOutputStream.write(i);
		}

		@Override
		public void print(long l) throws IOException {
			dataOutputStream.writeLong(l);
		}

		@Override
		public void print(float f) throws IOException {
			dataOutputStream.writeFloat(f);
		}

		@Override
		public void print(double d) throws IOException {
			dataOutputStream.writeDouble(d);
		}

		@Override
		public void println() throws IOException {
			dataOutputStream.write(LINE_SEPARATOR.getBytes(charSet));
		}

		@Override
		public void println(String s) throws IOException {
			print(s);
		}

		@Override
		public void println(boolean b) throws IOException {
			print(b);
			println();
		}

		@Override
		public void println(char c) throws IOException {
			print(c);
			println();
		}

		@Override
		public void println(int i) throws IOException {
			print(i);
			println();
		}

		@Override
		public void println(long l) throws IOException {
			print(l);
			println();
		}

		@Override
		public void println(float f) throws IOException {
			print(f);
			println();
		}

		@Override
		public void println(double d) throws IOException {
			print(d);
			println();
		}

		@Override
		public boolean isReady() {
			return true;
		}

		@Override
		public void setWriteListener(WriteListener writeListener) {
			throw new UnsupportedOperationException("writeListener not supported");
		}
	}
}
