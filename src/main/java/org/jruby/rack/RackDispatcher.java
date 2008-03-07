/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL/GPL/LGPL tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author nicksieger
 */
public interface RackDispatcher {
    final String EXCEPTION = "rack.exception";
    void process(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException;
}
