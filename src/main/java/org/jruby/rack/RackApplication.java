/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
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
    RackResponse call(ServletRequest env);
    void destroy();
}
