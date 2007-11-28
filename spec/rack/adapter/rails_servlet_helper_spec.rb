#--
# **** BEGIN LICENSE BLOCK *****
# Version: CPL 1.0/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Common Public
# License Version 1.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.eclipse.org/legal/cpl-v10.html
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# Copyright (C) 2007 Sun Microsystems, Inc.
#
# Alternatively, the contents of this file may be used under the terms of
# either of the GNU General Public License Version 2 or later (the "GPL"),
# or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
# in which case the provisions of the GPL or the LGPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of either the GPL or the LGPL, and not to allow others to
# use your version of this file under the terms of the CPL, indicate your
# decision by deleting the provisions above and replace them with the notice
# and other provisions required by the GPL or the LGPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the CPL, the GPL or the LGPL.
# **** END LICENSE BLOCK ****
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack/adapter/rails_servlet_helper'

describe Rack::Adapter::RailsServletHelper do
  before :each do
    @servlet_context = mock("servlet context")
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = Rack::Adapter::RailsServletHelper.new @servlet_context
  end
  
  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_helper
    @helper.rails_root.should == "./WEB-INF"
  end

  it "should default RAILS_ROOT to /WEB-INF" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_helper
    @helper.rails_root.should == "./WEB-INF"
  end

  it "should determine RAILS_ENV from the 'rails.env' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("rails.env").and_return "test"
    create_helper
    @helper.rails_env.should == "test"
  end

  it "should default RAILS_ENV to 'production'" do
    create_helper
    @helper.rails_env.should == "production"
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should default public root to '/WEB-INF/public'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/public").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should determine the static uris from the 'static.uris' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("static.uris").and_return "/static"
    create_helper
    @helper.static_uris.should == ["/static"]
  end

  it "should default the status uris appropriately" do
    create_helper
    @helper.static_uris.should include("/images", "/stylesheets", "/javascripts")
  end
  it "should create a Logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end
end
