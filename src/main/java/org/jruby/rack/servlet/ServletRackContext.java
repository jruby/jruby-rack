package org.jruby.rack.servlet;

import javax.servlet.ServletContext;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackContext;

/**
 *
 * @author nick
 *
 */
public interface ServletRackContext extends RackContext, ServletContext {

  RackApplicationFactory getRackFactory();

}
