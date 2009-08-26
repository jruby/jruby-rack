gem 'warbler'
require 'warbler'

class Warbler::Task
  def define_appengine_consolidation_tasks
    with_namespace_and_config do |name, config|
      app_task = Rake.application.lookup("app")
      gems_task = Rake.application.lookup("gems")
      app_task.prerequisites.delete("gems")
      gems_jar_name = File.expand_path(File.join(config.staging_dir, "WEB-INF", "lib", "gems.jar"))

      file gems_jar_name => gems_task.prerequisites do |t|
        Dir.chdir(File.join(config.staging_dir, "WEB-INF")) do
          sh "jar cf #{gems_jar_name} -C gems ."
          rm_rf "gems"
        end
      end

      task :app => gems_jar_name
    end
  end
end

warbler = Warbler::Task.new
warbler.define_appengine_consolidation_tasks

task :clean => "war:clean"

task :warble => "war"

def windows?
  require 'rbconfig'
  Config::CONFIG['host_os'] =~ /mswin32/
end

namespace :glassfish do
  task :deploy => :warble do
    sh "asadmin deploy --name rails --contextroot rails tmp/war" do |ok, res|
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
  task :deploy => :warble do
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

  task :server do
    sh "dev_appserver.sh --port=3000 tmp/war" do |ok, res|
      unless ok
        puts "Is the AppEngine-SDK/bin directory on your path?"
      end
    end
  end
end
