#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

repositories.remote << "http://repo1.maven.org/maven2" << "http://snapshots.repository.codehaus.org"

JRUBY = 'org.jruby:jruby-complete:jar:1.1RC-SNAPSHOT'

require './spec/buildr_framework'

desc 'JRuby Rack adapter'
define 'jruby-rack' do
  project.group = 'org.jruby.rack'
  project.version = '1.0-SNAPSHOT'
  compile.with 'javax.servlet:servlet-api:jar:2.3', JRUBY

  directory _("target")
  task :unpack_gems => _("target") do |t|
    Dir.chdir(t.prerequisites.first) do
      unless File.directory?(_("target/rack"))
        ruby "-S", "gem", "unpack", "rack"
        mv FileList["rack-*"].first, "rack"
      end
    end
  end

  resources.from _('lib'), _('target/rack/lib')
  task :resources => task('unpack_gems')

  test.using :rspec

  package :jar, :id => 'jruby-rack'
end
