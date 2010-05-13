/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.util.Set;
import java.net.URL;
import java.io.InputStream;
import java.net.MalformedURLException;

/**
 * Abstraction of an application context to make parts of the library
 * independent of the servlet context.
 * @author nicksieger
 */
public interface RackContext extends RackLogger {
    RackApplicationFactory getRackFactory();
    String getInitParameter(String key);
    String getRealPath(String path);
    Set getResourcePaths(String path);
    URL getResource(String path) throws MalformedURLException;
    InputStream getResourceAsStream(String path);
}
