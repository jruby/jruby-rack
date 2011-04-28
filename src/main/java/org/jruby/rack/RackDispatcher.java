/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletException;
import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public interface RackDispatcher {
    void process(RackEnvironment request, RackResponseEnvironment response)
        throws ServletException, IOException;
    void destroy();
}
