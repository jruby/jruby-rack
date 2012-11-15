/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.merb;

import org.jruby.Ruby;
import org.jruby.rack.DefaultRackApplicationFactory;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * @deprecated Merb support is deprecated and will be removed in 1.2
 * @author dudley
 */
@Deprecated
public class MerbRackApplicationFactory extends DefaultRackApplicationFactory {
    @Override
    public IRubyObject createApplicationObject(Ruby runtime) {
        runtime.evalScriptlet("load 'jruby/rack/boot/merb.rb'");
        return createRackServletWrapper(runtime, "run JRuby::Rack::MerbFactory.new");
    }
}
