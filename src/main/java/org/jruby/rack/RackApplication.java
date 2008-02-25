/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletRequest;

/**
 *
 * @author nicksieger
 */
public interface RackApplication {
    void init() throws RackInitializationException;
    RackResult call(ServletRequest env);
    void destroy();
}
