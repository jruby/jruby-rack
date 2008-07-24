package org.jruby.rack.merb;

import org.jruby.Ruby;
import org.jruby.rack.DefaultRackApplicationFactory;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author dudley
 */
public class MerbRackApplicationFactory extends DefaultRackApplicationFactory {
    @Override
    public IRubyObject createApplicationObject(Ruby runtime) {
        runtime.evalScriptlet("load 'jruby/rack/boot/merb.rb'");
        return createRackServletWrapper(runtime, "run JRuby::Rack::MerbFactory.new");
    }
}
