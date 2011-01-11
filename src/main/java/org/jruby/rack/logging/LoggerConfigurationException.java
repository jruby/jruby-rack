/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

public class LoggerConfigurationException extends RuntimeException {
    private static final long serialVersionUID = 1L;
    public LoggerConfigurationException(String msg, Throwable e) {
        super(msg,e);
    }
}
