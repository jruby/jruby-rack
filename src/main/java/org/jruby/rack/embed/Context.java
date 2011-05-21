package org.jruby.rack.embed;

import org.jruby.rack.DefaultRackConfig;
import org.jruby.rack.RackConfig;

public class Context implements org.jruby.rack.RackContext {

  private final String serverInfo;

  /**
   * @param serverInfo a string to describe the server software you have
   * embedded.  Exposed as a CGI variable.
   */
  public Context(String serverInfo) {
    this.serverInfo = serverInfo;
  }

  public RackConfig getConfig() {
    return new DefaultRackConfig();
  }

  public String getServerInfo() {
    return this.serverInfo;
  }

  public void log(String message) {
    System.out.println(message);
  }

  public void log(String message, Throwable ex) {
    System.out.println(message);
    ex.printStackTrace(System.err);
  }

}
