package org.jruby.rack.servlet;

import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;

public class ResponseCapture extends HttpServletResponseWrapper {
    
    private int status = 200;

    public ResponseCapture(HttpServletResponse response) {
        super(response);
    }

    @Override public void sendError(int status, String message) throws IOException {
        this.status = status;
    }

    @Override public void sendError(int status) throws IOException {
        this.status = status;
    }

    @Override public void sendRedirect(String path) throws IOException {
        this.status = 302;
        super.sendRedirect(path);
    }

    @Override public void setStatus(int status) {
        this.status = status;
        if (!isError()) {
            super.setStatus(status);
        }
    }

    @Override public void setStatus(int status, String message) {
        this.status = status;
        if (!isError()) {
            super.setStatus(status, message);
        }
    }

    @Override public void flushBuffer() throws IOException {
        if (!isError()) {
            super.flushBuffer();
        }
    }

    @Override public ServletOutputStream getOutputStream() throws IOException {
        if (isError()) {
            return new ServletOutputStream() {
                @Override 
                public void write(int b) throws IOException {
                    // swallow output, because we're going to discard it
                }
            };
        } else {
            return super.getOutputStream();
        }
    }

    @Override
    public PrintWriter getWriter() throws IOException {
        if (isError()) {
            return new PrintWriter(new OutputStream() {
                @Override 
                public void write(int i) throws IOException {
                    // swallow output, because we're going to discard it
                }
            });
        } else {
            return super.getWriter();
        }
    }

    public boolean isError() {
        return status >= 400;
    }
    
}
