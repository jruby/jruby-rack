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
        runtime.evalScriptlet("require 'merb/rack/bootstrap'"); 
        return createRackServletWrapper(runtime, 
            "use Merb::Rack::ServletSetup; run Merb::Config[:app];"
        );
    }
}
