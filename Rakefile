#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake/clean'
require 'spec/rake/spectask'
require 'rbconfig'
load 'src/main/ruby/jruby/rack/version.rb'

CLASSPATH = Dir["src/main/jars/*.jar"] +
  ["target/classes", "target/test-classes", File.join(Config::CONFIG['libdir'], Config::CONFIG['LIBRUBY'])]
CLASSPATH.each {|p| $CLASSPATH << p}
ENV['CLASSPATH'] = CLASSPATH.join(File::PATH_SEPARATOR)

CLEAN << 'target'

directory 'target/classes'

desc "Compile java classes"
task :compile => "target/classes" do |t|
  sh "javac -source 1.5 -target 1.5 -d #{t.prerequisites.first} #{Dir['src/main/java/**/*.java'].join(' ')}"
end

directory 'target/test-classes'

task :compilespec => "target/test-classes" do |t|
  sh "javac -source 1.5 -target 1.5 -d #{t.prerequisites.first} #{Dir['src/spec/java/**/*.java'].join(' ')}"
end

desc "Unpack the rack gem"
task :unpack_gem => "target" do |t|
  Dir.chdir(t.prerequisites.first) do
    unless File.directory?("rack")
      ruby "-S", "gem", "unpack", "-v", "0.4.0", "rack"
      mv FileList["rack-*"].first, "rack"
    end
  end
end

desc "Copy resources"
task :resources => ["target/classes", :unpack_gem] do |t|
  ['src/main/ruby', 'target/rack/lib'].each do |dir|
    FileList["#{dir}/*"].each do |f|
      cp_r f, t.prerequisites.first
    end
  end
  meta_inf = File.join(t.prerequisites.first, "META-INF")
  mkdir_p meta_inf
  cp "src/main/tld/jruby-rack.tld", meta_inf
end

desc "Run specs"
Spec::Rake::SpecTask.new(:spec => [:compile, :resources, :compilespec]) do |t|
  t.pattern = "src/spec/ruby/**/*_spec.rb"
  t.spec_opts = ["--format", "specdoc"]
end

task :test => :spec

desc "Create the jar"
task :jar => :spec do
  sh "jar cf target/jruby-rack-#{JRuby::Rack::VERSION}.jar -C target/classes ."
end

task :default => :jar

task :classpath do
  puts "export CLASSPATH=#{ENV['CLASSPATH']}"
end
