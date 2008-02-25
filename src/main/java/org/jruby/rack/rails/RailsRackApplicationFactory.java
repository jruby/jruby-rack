/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import org.jruby.Ruby;
import org.jruby.rack.DefaultRackApplicationFactory;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class RailsRackApplicationFactory extends DefaultRackApplicationFactory {
    @Override
    public IRubyObject createApplicationObject(Ruby runtime) {
        runtime.evalScriptlet("require 'rack/adapter/rails'");
        return createRackServletWrapper(runtime, "run JRuby::Rack::RailsFactory.new");
    }
}
