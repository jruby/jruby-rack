package org.jruby.rack;

import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;

import org.jruby.rack.servlet.ServletRackContext;

public class RackFilter extends UnmappedRackFilter {

  private boolean filterAddsHtml, filterVerifiesResource;
  private ServletRackContext servletContext;

  /** Default constructor for servlet container */
  public RackFilter() {
  }

  /** Dependency-injected constructor for testing */
  public RackFilter(RackDispatcher dispatcher, RackContext context) {
    super(dispatcher, context);
    configure();
  }

  @Override
  public void init(FilterConfig config) throws ServletException {
    super.init(config);
    configure();
  }

  private void configure() {
    this.servletContext = (ServletRackContext) context;
    this.filterAddsHtml = context.getConfig().isFilterAddsHtml();
    this.filterVerifiesResource = context.getConfig().isFilterVerifiesResource();
  }

  @Override
  protected HttpServletRequest getHttpServletRequest(ServletRequest request,
      RackEnvironment env) {
    return maybeAppendHtmlToPath(request, env);
  }

  private HttpServletRequest maybeAppendHtmlToPath(ServletRequest request, RackEnvironment env) {
    HttpServletRequest httpRequest = (HttpServletRequest) request;

    if (!filterAddsHtml) {
        return httpRequest;
    }

    String path = env.getPathInfo();
    String additional = "";

    if (path.lastIndexOf('.') <= path.lastIndexOf('/')) {
        if (path.endsWith("/")) {
            additional += "index";
        }
        additional += ".html";

        // Welcome file list already triggered mapping to index.html, so don't modify the request any further
        if (httpRequest.getServletPath().equals(path + additional)) {
            return httpRequest;
        }

        if (filterVerifiesResource && !resourceExists(path + additional)) {
            return httpRequest;
        }

        final String requestURI = httpRequest.getRequestURI() + additional;
        if (httpRequest.getPathInfo() != null) {
            final String pathInfo = httpRequest.getPathInfo() + additional;
            httpRequest = new HttpServletRequestWrapper(httpRequest) {
                @Override
                public String getPathInfo() {
                    return pathInfo;
                }
                @Override
                public String getRequestURI() {
                    return requestURI;
                }
            };
        } else {
            final String servletPath = httpRequest.getServletPath() + additional;
            httpRequest = new HttpServletRequestWrapper(httpRequest) {
                @Override
                public String getServletPath() {
                    return servletPath;
                }
                @Override
                public String getRequestURI() {
                    return requestURI;
                }
            };
        }
    }
    return httpRequest;
}

  private boolean resourceExists(String path) {
    try {
      return servletContext.getResource(path) != null;
      // FIXME: Should we really be swallowing *all* exceptions here?
    } catch (Exception e) {
        return false;
    }
  }

}
