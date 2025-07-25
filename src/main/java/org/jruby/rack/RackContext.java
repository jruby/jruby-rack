/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 * Abstraction of an application context to make parts of the library
 * independent of the servlet context.
 * @author nicksieger
 */
public interface RackContext extends RackLogger {
    RackConfig getConfig(); /// NOTE: deprecate ?
    String getServerInfo();
}
