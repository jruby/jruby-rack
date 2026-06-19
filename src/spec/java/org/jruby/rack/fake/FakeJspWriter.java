/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.fake;

import java.io.IOException;
import javax.servlet.jsp.JspWriter;

/**
 * Currently only used as a mock for testing.
 *
 * @author tyler
 */
@SuppressWarnings("unused") // Used from Ruby
public class FakeJspWriter extends JspWriter {
    private final StringBuilder sb = new StringBuilder();

    public FakeJspWriter() {
        super(0, false);
    }
    
    public String toString() {
        return sb.toString();
    }
    
    @Override
    public void write(String str) {
        sb.append(str);
    }
    
    @Override
    public void write(char[] arg0, int arg1, int arg2) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void clear() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void clearBuffer() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void close() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void flush() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public int getRemaining() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void newLine() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(boolean arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(char arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(int arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(long arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(float arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(double arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(char[] arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(String arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void print(Object arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println() {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(boolean arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(char arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(int arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(long arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(float arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(double arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(char[] arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(String arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    @Override
    public void println(Object arg0) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

}
