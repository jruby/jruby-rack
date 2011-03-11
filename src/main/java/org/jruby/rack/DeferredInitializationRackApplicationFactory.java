package org.jruby.rack;

/**
 *
 */
public class DeferredInitializationRackApplicationFactory extends DefaultRackApplicationFactory {
    
    @Override
    public RackApplication getApplication() throws RackInitializationException {
        RackApplication app = new DeferredInitializationRackApplication(newApplication());
        app.init();
        return app;
    }
}
