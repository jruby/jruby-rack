#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

repositories.remote << "http://repo1.maven.org/maven2" << "http://snapshots.repository.codehaus.org"

JRUBY = 'org.jruby:jruby-complete:jar:1.1.3'

desc 'JRuby Rack adapter'
define 'jruby-rack' do
  project.group = 'org.jruby.rack'
  project.version = '0.9.3-SNAPSHOT'
  compile.with 'javaee:javaee:jar:5.0', JRUBY
  meta_inf << file("src/main/tld/jruby-rack.tld")

  directory _("target")
  task :unpack_gems => _("target") do |t|
    Dir.chdir(t.prerequisites.first) do
      unless File.directory?(_("target/rack"))
        ruby "-S", "gem", "unpack", "-v", "0.4.0", "rack"
        mv FileList["rack-*"].first, "rack"
      end
    end
  end

  resources.from _('src/main/ruby'), _('target/rack/lib')
  task :resources => task('unpack_gems')

  test.using :rspec

  # Exclude the test stubs from the final jar
  package(:jar).exclude(_('target/classes/org/jruby/rack/fake'))
end
