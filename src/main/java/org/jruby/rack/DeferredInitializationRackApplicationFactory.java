package org.jruby.rack;

import org.jruby.Ruby;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 */
public class DeferredInitializationRackApplicationFactory extends DefaultRackApplicationFactory {
    private DefaultRackApplicationFactory realFactory;

    /**
     * Only works if factory is implemented by overriding createApplicationObject
     */ 
    public DeferredInitializationRackApplicationFactory(DefaultRackApplicationFactory factory) {
        realFactory = factory;
    }
    
    @Override
    public IRubyObject createApplicationObject(Ruby runtime) {
        return realFactory.createApplicationObject(runtime);
    }

    @Override
    public RackApplication getApplication() throws RackInitializationException {
        RackApplication app = new DeferredInitializationRackApplication(newApplication());
        app.init();
        return app;
    }
}
