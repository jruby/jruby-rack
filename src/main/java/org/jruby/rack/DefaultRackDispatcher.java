package org.jruby.rack;

import java.io.IOException;

import org.jruby.rack.servlet.ServletRackContext;

/**
 * Dispatcher suited for use in a servlet container
 * @author nick
 *
 */
public class DefaultRackDispatcher extends AbstractRackDispatcher {

  private final ServletRackContext servletRackContext;

  public DefaultRackDispatcher(RackContext rackContext) {
    super(rackContext);
    this.servletRackContext = (ServletRackContext) rackContext;
  }

  @Override
  protected RackApplication getApplication(RackContext context) throws RackInitializationException {
    final RackApplicationFactory rackFactory = servletRackContext.getRackFactory();
    return rackFactory.getApplication();
  }

  @Override
  protected void afterException(RackEnvironment request, Exception re,
      RackResponseEnvironment response) throws IOException {
    try {
      RackApplication errorApp = getRackFactory().getErrorApplication();
      request.setAttribute(RackEnvironment.EXCEPTION, re);
      errorApp.call(request).respond(response);
    } catch (Exception e) {
      servletRackContext.log("Error: Couldn't handle error", e);
      response.sendError(500);
    }
  }


  public void destroy() {
    final RackApplicationFactory rackFactory = servletRackContext.getRackFactory();
    rackFactory.destroy();
  }

  protected RackApplicationFactory getRackFactory() {
    return servletRackContext.getRackFactory();
  }

  @Override
  protected void afterProcess(RackApplication app) {
    getRackFactory().finishedWithApplication(app);
  }

}
