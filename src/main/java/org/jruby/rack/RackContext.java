/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 * Abstraction of an application context to make parts of the library
 * independent of the servlet context.
 * @author nicksieger
 */
public interface RackContext {
    RackApplicationFactory getRackFactory();
    String getInitParameter(String key);
    void log(String message);
    void log(String message, Throwable ex);
    String getRealPath(String path);
}
