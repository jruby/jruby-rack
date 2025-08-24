/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

import org.jruby.rack.RackResponseEnvironment;

/**
 * The default (servlet) {@link RackResponseEnvironment} implementation.
 *
 * @author nicksieger
 */
public class ServletRackResponseEnvironment extends HttpServletResponseWrapper
    implements RackResponseEnvironment {

    public ServletRackResponseEnvironment(HttpServletResponse response) {
        super(response);
    }

}
