#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'

# Ruby-friendly extensions to the Servlet API.

module Java::JakartaServlet::ServletContext
  # Fetch an attribute from the servlet context.
  def [](key)
    getAttribute(key.to_s)
  end
  # Set an attribute in the servlet context.
  def []=(key, val)
    setAttribute(key.to_s, val)
  end
  # Remove an attribute for the given key.
  def delete(key)
    removeAttribute(key.to_s)
  end
  # Retrieve all the attribute names (keys).
  # like Hash#keys
  def keys
    getAttributeNames.to_a
  end
  # like Hash#values
  def values
    getAttributeNames.map { |name| getAttribute(name) }
  end
  # Iterate over every attribute name/value pair from the context.
  # like Hash#each
  def each
    getAttributeNames.each { |name| yield(name, getAttribute(name)) }
  end
end

module Java::JakartaServlet::ServletRequest
  # Fetch an attribute from the servlet request.
  def [](key)
    getAttribute(key.to_s)
  end
  # Set an attribute in the servlet request.
  def []=(key, val)
    setAttribute(key.to_s, val)
  end
  # Remove an attribute for the given key.
  def delete(key)
    removeAttribute(key.to_s)
  end
  # Retrieve all the attribute names (keys) from the servlet request.
  # like Hash#keys
  def keys
    getAttributeNames.to_a
  end
  # like Hash#values
  def values
    getAttributeNames.map { |name| getAttribute(name) }
  end
  # Iterate over every attribute name/value pair from the servlet request.
  # like Hash#each
  def each
    getAttributeNames.each { |name| yield(name, getAttribute(name)) }
  end
end

module Java::JakartaServletHttp::HttpSession
  # Fetch an attribute from the session.
  def [](key)
    getAttribute(key.to_s)
  end
  # Set an attribute in the session.
  def []=(key, val)
    setAttribute(key.to_s, val)
  end
  # Remove an attribute for the given key.
  def delete(key)
    removeAttribute(key.to_s)
  end
  # Retrieve all the attribute names (keys) from the session.
  # like Hash#keys
  def keys
    getAttributeNames.to_a
  end
  # like Hash#values
  def values
    getAttributeNames.map { |name| getAttribute(name) }
  end
  # Iterate over every attribute name/value pair from the session.
  # like Hash#each
  def each
    getAttributeNames.each { |name| yield(name, getAttribute(name)) }
  end
end
