#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/chunked' # exists since Rack 1.1

# Disables the Rack response body chunking performed by `Rack::Chunked::Body`.
# It is "necessary" since Rails does instantiate the body directly instead of
# using `Rack::Chunked` as a middleware.
# 
# @note This monkey-patch is not required to support chunking with servlets and 
# won't be applied unless **jruby.rack.response.dechunk** is 'patch' (default).
# Set **jruby.rack.response.dechunk** to 'true' to simply "dechunk" the body and
# keep the `Rack::Chunked::Body` class as is (or 'false' to do no de-chunking at
# all).
Rack::Chunked::Body.class_eval do

  def each(&block)
    @body.each(&block) # no-chunking on servlets
  end
  
end if defined? Rack::Chunked::Body

unless defined? Rack::Chunked::Body # Rack 1.1
  
  Rack::Chunked.class_eval do
    
    def each(&block)
      @body.each(&block) # no-chunking on servlets
    end
    
  end
  
end