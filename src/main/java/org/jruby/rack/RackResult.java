/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author nicksieger
 */
public interface RackResult {
    void writeStatus(HttpServletResponse response);
    void writeHeaders(HttpServletResponse response);
    void writeBody(HttpServletResponse response);
}
