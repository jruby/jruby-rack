package org.jruby.rack.embed;

import java.io.IOException;

import org.jruby.rack.AbstractRackDispatcher;
import org.jruby.rack.DefaultRackApplication;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackResponseEnvironment;
import org.jruby.runtime.builtin.IRubyObject;

public class Dispatcher extends AbstractRackDispatcher {

  private final DefaultRackApplication rackApplication;

  public Dispatcher(RackContext rackContext, IRubyObject application) {
    super(rackContext);
    this.rackApplication = new DefaultRackApplication(application);
  }

  @Override
  protected void afterException(RackEnvironment request, Exception re,
      RackResponseEnvironment response) throws IOException {
    // TODO print out a 500 or something?
    re.printStackTrace(System.err);
  }

  @Override
  protected void afterProcess(RackApplication app) throws IOException {
  }

  @Override
  protected RackApplication getApplication(RackContext context)
      throws RackInitializationException {
    return rackApplication;
  }

  public void destroy() {
    this.rackApplication.destroy();
  }


}
