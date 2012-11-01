/*
 * The MIT License
 *
 * Copyright 2012 kares.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package org.jruby.rack.util;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Input - Output (stream) helpers.
 *
 * @author kares
 */
public abstract class IOHelpers {
    
    public static String inputStreamToString(final InputStream stream)
        throws IOException {
        if ( stream == null ) return null;
        
        final StringBuilder str = new StringBuilder();
        int c = stream.read();
        Reader reader;
        String coding = "UTF-8";
        if (c == '#') {     // look for a coding: pragma
            str.append((char) c);
            while ((c = stream.read()) != -1 && c != 10) {
                str.append((char) c);
            }
            Pattern pattern = Pattern.compile("coding:\\s*(\\S+)");
            Matcher matcher = pattern.matcher(str.toString());
            if (matcher.find()) {
                coding = matcher.group(1);
            }
        }

        str.append((char) c);
        reader = new InputStreamReader(stream, coding);

        while ((c = reader.read()) != -1) {
            str.append((char) c);
        }

        return str.toString();
    }
    
}