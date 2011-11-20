package org.jruby.rack.servlet;

import javax.servlet.ServletInputStream;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import org.jruby.rack.RackConfig;
import org.jruby.rack.io.RewindableInputStream;

public class RequestCapture extends HttpServletRequestWrapper {

    private Map<String,String[]> requestParams;
    private final boolean rewindable;
    private InputStream inputStream;

    public RequestCapture(HttpServletRequest request, RackConfig config) {
        super(request);
        rewindable = config.isRewindable();
    }

    @Override public BufferedReader getReader() throws IOException {
        if (inputStream != null) {
            String enc = getCharacterEncoding();
            if (enc == null) {
                enc = "UTF-8";
            }
            return new BufferedReader(new InputStreamReader(inputStream, enc));
        } 
        else {
            return super.getReader();
        }
    }
    
    @Override 
    public ServletInputStream getInputStream() throws IOException {
        if ( ! rewindable ) {
            return super.getInputStream();
        }
        if (inputStream == null) {
            inputStream = new RewindableInputStream(super.getInputStream());
        }
        return new ServletInputStream() {
            @Override
            public long skip(long l) throws IOException {
                return inputStream.skip(l);
            }

            @Override
            public int available() throws IOException {
                return inputStream.available();
            }

            @Override
            public void close() throws IOException {
                inputStream.close();
            }

            @Override
            public void mark(int i) {
                inputStream.mark(i);
            }

            @Override
            public void reset() throws IOException {
                inputStream.reset();
            }

            @Override
            public boolean markSupported() {
                return inputStream.markSupported();
            }

            @Override
            public int read(byte[] bytes) throws IOException {
                return inputStream.read(bytes);
            }

            @Override
            public int read(byte[] bytes, int i, int i1) throws IOException {
                return inputStream.read(bytes, i, i1);
            }

            @Override
            public int read() throws IOException {
                return inputStream.read();
            }
        };
    }

    @Override
    public String getParameter(String name) {
        if ( parseRequestParams() ) {
            String[] values = requestParams.get(name);
            if (values != null) {
                return values[0];
            }
            return null;
        } else {
            return super.getParameter(name);
        }
    }

    @Override
    public Map getParameterMap() {
        if ( parseRequestParams() ) {
            return requestParams;
        } else {
            return super.getParameterMap();
        }
    }

    @Override
    public Enumeration getParameterNames() {
        if ( parseRequestParams() ) {
            return new Enumeration() {
                Iterator keys = requestParams.keySet().iterator();
                public boolean hasMoreElements() {
                    return keys.hasNext();
                }

                public Object nextElement() {
                    return keys.next();
                }
            };
        } else {
            return super.getParameterNames();
        }
    }

    @Override
    public String[] getParameterValues(String name) {
        if ( parseRequestParams() ) {
            return requestParams.get(name);
        } else {
            return super.getParameterValues(name);
        }
    }

    private boolean parseRequestParams() {
        if ( this.requestParams != null ) return true;
        if ( ! "application/x-www-form-urlencoded".equals(getContentType()) ) {
            return false;
        }
        // Need to re-parse form params from the request
        // All this because you can't mix use of request#getParameter
        // and request#getInputStream in the Servlet API.
        String line = "";
        try {
            line = getReader().readLine();
        } 
        catch (IOException e) {
        }
        
        Map<String,String[]> params = new HashMap<String,String[]>();
        
        String[] pairs = line.split("\\&");
        for (int i = 0; i < pairs.length; i++) {
            try {
                String[] fields = pairs[i].split("=", 2);
                String key = URLDecoder.decode(fields[0], "UTF-8");
                String value = null;
                if (fields.length == 2) {
                    value = URLDecoder.decode(fields[1], "UTF-8");
                }
                if (value != null) {
                    String[] newValues;
                    if (params.containsKey(key)) {
                        String[] values = params.get(key);
                        newValues = new String[values.length + 1];
                        System.arraycopy(values, 0, newValues, 0, values.length);
                        newValues[values.length] = value;
                    } else {
                        newValues = new String[1];
                        newValues[0] = value;
                    }
                    params.put(key, newValues);
                }
            } 
            catch (UnsupportedEncodingException e) { /* UTF-8 should be fine */ }
        }
        
        this.requestParams = params;
        
        return true;
    }

    public void reset() throws IOException {
        if (inputStream instanceof RewindableInputStream) {
            ((RewindableInputStream) inputStream).rewind();
        }
    }
}
