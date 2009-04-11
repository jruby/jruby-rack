#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# Ruby-friendly extensions to the servlet API.

module Java::JavaxServletHttp::HttpServletRequest
  # Fetch an attribute from the servlet request.
  def [](key)
    getAttribute(key.to_s)
  end
  # Set an attribute in the servlet request.
  def []=(key, val)
    setAttribute(key.to_s, val)
  end
  # Retrieve all the attribute names (keys) from the servlet request.
  def keys
    getAttributeNames.to_a
  end
end

module Java::JavaxServletHttp::HttpSession
  # Fetch an attribute from the session.
  def [](key)
    getAttribute(key.to_s)
  end
  # Set an attribute in the session.
  def []=(key, val)
    setAttribute(key.to_s, val)
  end
  # Retrieve all the attribute names (keys) from the session.
  def keys
    getAttributeNames.to_a
  end
end
