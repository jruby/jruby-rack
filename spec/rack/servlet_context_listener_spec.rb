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

import org.jruby.rack.RackApplicationFactory
import org.jruby.rack.RackServletContextListener

describe RackServletContextListener do
  before(:each) do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context_event = javax.servlet.ServletContextEvent.new @servlet_context
    @factory = mock "application factory"
    @listener = RackServletContextListener.new @factory
  end

  describe "contextInitialized" do
    it "should create a Rack application factory and store it in the context" do
      @servlet_context.should_receive(:setAttribute).with(
        RackServletContextListener::FACTORY_KEY, an_instance_of(RackApplicationFactory))
      @factory.stub!(:init)
      @listener.contextInitialized @servlet_context_event
    end

    it "should initialize it" do
      @servlet_context.stub!(:setAttribute)
      @factory.should_receive(:init).with(an_instance_of(javax.servlet.ServletContext))
      @listener.contextInitialized @servlet_context_event
    end

    it "should log an error if initialize failed" do
      @servlet_context.stub!(:setAttribute)
      @factory.should_receive(:init).and_raise "help"
      @servlet_context.should_receive(:log).with(/initialization failed/)
      @listener.contextInitialized @servlet_context_event
    end
  end

  describe "contextDestroyed" do
    before :each do
      @servlet_context.should_receive(:getAttribute).with(
        RackServletContextListener::FACTORY_KEY).and_return @factory
    end

    it "should remove the application factory from the servlet context" do
      @servlet_context.should_receive(:removeAttribute).with(
        RackServletContextListener::FACTORY_KEY)
      @factory.stub!(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end

    it "should destroy it" do
      @servlet_context.stub!(:removeAttribute)
      @factory.should_receive(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end
  end
end
