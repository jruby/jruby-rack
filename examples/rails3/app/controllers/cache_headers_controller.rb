class CacheHeadersController < ApplicationController
  before_filter :set_cache_header

  def index
    render :text => "caching"
  end

  def set_cache_header
    # set modify date to current timestamp
    response.headers["Last-Modified"] = CGI::rfc1123_date(Time.now -  1000)
    # set expiry to back in the past
    # (makes us a bad candidate for caching)
    response.headers["Expires"] = "0"
    # HTTP 1.0 (disable caching)
    response.headers["Pragma"] = "no-cache"
    # HTTP 1.1 (disable caching of any kind)
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, pre-check=0, post-check=0"
  end
end
