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

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.RackServlet

describe RackServlet do
  before :each do
    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    @servlet_context.should_receive(:getAttribute).with("rack.factory").and_return @rack_factory
    @servlet = RackServlet.new
    @servlet.init(@servlet_config)
  end

  describe "service" do
    it "should delegate to process" do
      request = javax.servlet.http.HttpServletRequest.impl {}
      response = javax.servlet.http.HttpServletResponse.impl {}
      application = mock("application")
      @rack_factory.stub!(:getApplication).and_return application
      @rack_factory.stub!(:finishedWithApplication)
      application.stub!(:call).and_raise "error"

      lambda {
        @servlet.service request, response
      }.should raise_error(javax.servlet.ServletException)
    end
  end

  describe "process" do
    it "should retrieve a RackApplication and call it" do
      application = mock("application")
      request = mock("request")
      response = mock("response")
      result = mock("rack result")

      @rack_factory.should_receive(:getApplication).and_return(application)
      @rack_factory.should_receive(:finishedWithApplication).with(application)
      application.should_receive(:call).with(request).and_return result
      result.should_receive(:writeStatus)
      result.should_receive(:writeHeaders)
      result.should_receive(:writeBody)

      @servlet.process(request, response)
    end

    it "should raise a servlet exception if the application could not be initialized" do
      @rack_factory.stub!(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
      lambda {
        @servlet.process(mock("request"), mock("response"))
      }.should raise_error(javax.servlet.ServletException)
    end

    it "should raise a servlet exception if an unexpected exception leaks out" do
      application = mock("application")
      @rack_factory.stub!(:getApplication).and_return application
      @rack_factory.stub!(:finishedWithApplication)
      application.stub!(:call).and_raise "error"

      lambda {
        @servlet.process(mock("request"), mock("response"))
      }.should raise_error(javax.servlet.ServletException)
    end
  end
end
