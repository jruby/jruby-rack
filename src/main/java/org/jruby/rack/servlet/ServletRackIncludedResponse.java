package org.jruby.rack.servlet;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;

import javax.servlet.ServletOutputStream;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 * Response wrapper used to buffer the output of a server-side include. 
 * @author bhaidri
 */
public class ServletRackIncludedResponse extends HttpServletResponseWrapper {

	private final static int BUFFER_SIZE = 16 * 1024;  // 16K buffer size
	
	private int bufferSize;
	private ServletResponse wrappedResponse;
	private PrintWriter writer;
	private ServletOutputStream outputStream;
	private ByteArrayOutputStream byteOutputStream;
	
	public ServletRackIncludedResponse(HttpServletResponse response) {
		super(response);
		bufferSize = BUFFER_SIZE;
		wrappedResponse = response;
	}
	
	/**
	 * Returns the output of the include as a string, encoded by the
	 * character encoding available in {@link ServletReponse.getCharacterEncoding()}}
	 * @return
	 */
	public String getOutput() {
		String charSet = super.getResponse().getCharacterEncoding();
		try {
			flushBuffer();
			return byteOutputStream.toString(charSet);
		} catch (Exception e) {
			throw new RuntimeException(e);
		}
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
	 * All content written to this response is buffered,
	 * but this method will return either the initial buffer size
	 * or the one specified using {@link #setBufferSize(int)}.
	 */
	@Override
	public int getBufferSize() {
		return bufferSize;
	}

	@Override
	public ServletOutputStream getOutputStream() throws IOException {
		if (writer != null) {
			throw new IllegalStateException("Cannot return output stream after a writer has been returned");
		}
		if (outputStream == null) {
			initializeOutputStream();
		}
		return outputStream;
	}

	@Override
	public PrintWriter getWriter() throws IOException {
		if (outputStream != null) {
			throw new IllegalStateException("Cannot return writer after an output stream has been returned");
		}
		if (writer == null) {
			initializeWriter();
		}
		return writer;
	}

	@Override
	public void reset() {
		throw new UnsupportedOperationException("Cannot reset a response from inside a server-side include");
	}

	@Override
	public void resetBuffer() {
		if (getResponse().isCommitted()) {
			throw new IllegalArgumentException("Illegal call to resetBuffer() after response has been committed");
		}
		if (writer != null) {
			initializeWriter();
		} else if (outputStream != null) {
			initializeOutputStream();
		}
	}

	/**
	 *  Calls to this method are ignored if the stream has already been written to,
	 *  unless {@link #resetBuffer()} is called.
	 */
	@Override
	public void setBufferSize(int size) {
		bufferSize = size;
	}
	
	private void initializeWriter() {
		String charSet = super.getResponse().getCharacterEncoding();
		byteOutputStream = new ByteArrayOutputStream(bufferSize);
		try {
			writer = new PrintWriter(new OutputStreamWriter(byteOutputStream, charSet));
		} catch (UnsupportedEncodingException e) {
			throw new RuntimeException(e);
		}
	}
	
	private void initializeOutputStream() {
		String charSet = super.getResponse().getCharacterEncoding();
		byteOutputStream = new ByteArrayOutputStream(bufferSize);
		outputStream = new ByteArrayServletOutputStream(byteOutputStream, charSet);
	}
	
	/**
	 * Crunchy ServletOutputStream coating hiding a chewy ByteArrayOutputStream center. 
	 * @author bhaidri
	 */
	private final static class ByteArrayServletOutputStream extends ServletOutputStream {
		
		private final static String LINE_SEPARATOR = System.getProperty("line.separator");
		private final DataOutputStream dataOutputStream;
		private final String charSet;
		
		public ByteArrayServletOutputStream(ByteArrayOutputStream byteOutputStream, String charSet) {
			super();
			this.dataOutputStream = new DataOutputStream(byteOutputStream);
			this.charSet = charSet;
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
		public void print(double d) throws IOException {
			dataOutputStream.writeDouble(d);
		}

		@Override
		public void print(float f) throws IOException {
			dataOutputStream.writeFloat(f);
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
		public void print(String s) throws IOException {
			dataOutputStream.write(s.getBytes(charSet));
		}

		@Override
		public void println() throws IOException {
			dataOutputStream.write(LINE_SEPARATOR.getBytes(charSet));
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
		public void println(double d) throws IOException {
			print(d);
			println();
		}

		@Override
		public void println(float f) throws IOException {
			print(f);
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
		public void println(String s) throws IOException {
			print(s);
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
	}
}
