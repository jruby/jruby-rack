gem 'warbler'
require 'warbler'

class Warbler::Task
  def define_jruby_jar_split_tasks
    with_namespace_and_config do |name, config|
      app_task = Rake.application.lookup("app")
      jruby_complete_jar = app_task.prerequisites.detect {|p| p =~ /jruby-complete/}
      app_task.prerequisites.delete(jruby_complete_jar)
      jruby_core_name = jruby_complete_jar.sub(/complete/, 'core')
      jruby_stdlib_name = jruby_complete_jar.sub(/complete/, 'stdlib')
      working_dir = "tmp/jar_unpack"

      puts jruby_complete_jar, jruby_core_name, jruby_stdlib_name

      task :unpack_jruby_complete_jar => jruby_complete_jar do |t|
        rm_rf working_dir
        mkdir_p "#{working_dir}/jruby_complete"
        mkdir_p "#{working_dir}/jruby_core"
        complete_jar_file = File.expand_path(t.prerequisites.first)
        Dir.chdir("#{working_dir}/jruby_complete") do
          sh "jar xf #{complete_jar_file}"
          mv FileList[*%w(builtin jruby org com jline)], "../jruby_core"
        end
        rm_f complete_jar_file
      end

      file jruby_core_name => :unpack_jruby_complete_jar do |t|
        sh "jar cf #{t.name} -C #{working_dir}/jruby_core ."
      end

      file jruby_stdlib_name => :unpack_jruby_complete_jar do |t|
        sh "jar cf #{t.name} -C #{working_dir}/jruby_complete ."
      end

      task :clean do
        rm_rf working_dir
      end

      task :app => [jruby_core_name, jruby_stdlib_name]
    end
  end
end

warbler = Warbler::Task.new
warbler.define_jruby_jar_split_tasks

task :clean => "war:clean"

task :warble => "war"

task :deploy => :warble do
  sh "asadmin deploy --name rails --contextroot rails tmp/war"
end

task :undeploy do
  sh "asadmin undeploy rails"
end
