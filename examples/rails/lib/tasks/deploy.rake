gem 'warbler'
require 'warbler'

warbler = Warbler::Task.new

task :clean => "war:clean"

task :warble => "war"

def windows?
  require 'rbconfig'
  Config::CONFIG['host_os'] =~ /mswin32/
end

task "tmpwar" => :warble do
  if defined?(Warbler::War)     # Warbler 1.0, need to unpack the war file
    rm_rf "tmp/war"
    mkdir_p "tmp/war"
    Dir.chdir("tmp/war") do
      sh "jar xf ../../rails.war"
    end
  end
end

namespace :glassfish do
  task :deploy => :warble do
    sh "asadmin deploy --name rails --contextroot rails rails.war" do |ok, res|
      unless ok
        puts "Is the GLASSFISH/bin directory on your path?"
      end
    end
  end

  task :undeploy do
    sh "asadmin undeploy rails"
  end
end

namespace :appengine do
  task :deploy => "tmpwar" do
    email = ENV['EMAIL']
    pass = ENV['PASSWORD']
    passfile = ENV['PASSWORDFILE']
    fail "Please supply your Google account email using EMAIL={email}" unless email
    fail %{Please supply your Google password using PASSWORD={pass} or PASSWORDFILE={file}.
PASSWORDFILE should only contain the password value.} unless pass || passfile
    require 'tempfile'
    tmpfile = nil
    passcmd = if pass
                tmpfile = Tempfile.new("gaepass") {|f| f << pass }
                "cat #{tmpfile.path}"
              else
                "cat #{passfile}"
              end
    fullcmd = "#{passcmd} | appcfg.sh --email=#{email} --passin --enable_jar_splitting update tmp/war"
    if windows?
      fullcmd.sub!(/^cat /, 'type ')
      fullcmd.sub!(/appcfg.sh /, 'appcfg.cmd ')
    end
    sh fullcmd do |ok, res|
      unless ok
        puts "Is the AppEngine-SDK/bin directory on your path?"
      end
      tmpfile.unlink if tmpfile
    end
  end

  task :server => "tmpwar" do
    sh "dev_appserver.sh --port=3000 tmp/war" do |ok, res|
      unless ok
        puts "Is the AppEngine-SDK/bin directory on your path?"
      end
    end
  end
end
