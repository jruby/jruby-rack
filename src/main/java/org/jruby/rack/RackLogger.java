/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 * Abstraction of a logging device.
 * @author nicksieger
 */
public interface RackLogger {
    
    void log(String message);
    void log(String message, Throwable e);
    
    final String DEBUG = "DEBUG";
    final String INFO = "INFO";
    final String WARN = "WARN";
    final String ERROR = "ERROR";
    
    void log(String level, String message);
    void log(String level, String message, Throwable e);
    
}
