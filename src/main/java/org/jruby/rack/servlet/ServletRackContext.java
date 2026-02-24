/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import jakarta.servlet.ServletContext;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackContext;

/**
 *
 * @author nick
 *
 */
public interface ServletRackContext extends RackContext, ServletContext {

  RackApplicationFactory getRackFactory();

  @Override
  default void log(String message) {
    RackContext.super.log(message);
  }

  @Override
  default void log(String message, Throwable ex) {
    RackContext.super.log(message, ex);
  }
}
