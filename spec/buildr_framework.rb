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

if defined?(Buildr)
require 'rexml/document'

module RSpec
  RSPEC_REQUIRES = [(defined?(JRUBY) ? JRUBY : "org.jruby:jruby-complete:jar:1.1b1"),
    Buildr::Java::TestTask::JUNIT_REQUIRES]
  RSPEC_TESTS_PATTERN = "*"

  class << self
    def included(mod)
      mod::TEST_FRAMEWORKS << :rspec
    end
    private :included
  end

  private
  def jruby_home
    @project._(".jruby")
  end

  def gem_path(gem_name, *additional)
    dir = Dir["#{jruby_home}/lib/ruby/gems/1.8/gems/#{gem_name}*"].to_a.first
    dir = File.join(dir, *additional) unless additional.empty?
    dir
  end

  def required_gems
    ["ci_reporter", options[:required_gems]].flatten.compact
  end

  def rspec_run(args)
    cmd_options = args.only(:classpath, :properties, :java_args)
    cmd_options[:java_args] ||= []
    cmd_options[:java_args] << "-Xmx512m" unless cmd_options[:java_args].detect {|a| a =~ /^-Xmx/}
    cmd_options[:properties] ||= {}
    cmd_options[:properties]["jruby.home"] = jruby_home

    unless required_gems.all? {|g| gem_path(g)}
      java_args = ["org.jruby.Main", "-S", "maybe_install_gems", *required_gems]
      java_args << cmd_options.merge({:name => "JRuby Setup"})
      Buildr.java *java_args
    end

    begin
      failed_examples = []
      report_dir = report_to.to_s
      FileUtils.rm_rf report_dir
      ENV['CI_REPORTS'] = report_dir

      java_args = ["org.jruby.Main", "-Ilib", "-S", "spec",
        "--require", gem_path("ci_reporter", "lib/ci/reporter/rake/rspec_loader"),
        "--format", "CI::Reporter::RSpec", @project._("spec"),
        cmd_options.merge({:name => "RSpec"}) ]
      Buildr.java *java_args
    rescue
      Dir["#{report_dir}/**/*.xml"].each do |xmlf|
        doc = File.open(xmlf) {|f| REXML::Document.new(f)}
        doc.root.elements.to_a("/testsuite/testcase/failure/..").each do |el|
          failed_examples << el.parent.attributes["name"] + " " + el.attributes["name"]
        end
      end
      raise if failed_examples.empty?
    end
    failed_examples
  end
end

class Buildr::Java::TestTask
  include RSpec
end
end
