#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake/clean'

if ENV['JRUBY_PARENT_CLASSPATH']
  classpath = []
  ENV['JRUBY_PARENT_CLASSPATH'].split(File::PATH_SEPARATOR).each {|p| classpath << p}
else
  require 'rbconfig'
  classpath = Dir["src/main/lib/*.jar"] + [File.join(Config::CONFIG['libdir'], Config::CONFIG['LIBRUBY'])]
end
classpath.unshift "target/classes", "target/test-classes"
classpath.each {|p| $CLASSPATH << p}
ENV['CLASSPATH'] = classpath.join(File::PATH_SEPARATOR)

CLEAN << 'target'

directory 'target/classes'

desc "Compile java classes"
task :compile => "target/classes" do |t|
  sh "javac -source 1.5 -target 1.5 -d #{t.prerequisites.first} #{Dir['src/main/java/**/*.java'].join(' ')}"
end

directory 'target/test-classes'

desc "Compile classes used for test/spec"
task :compilespec => "target/test-classes" do |t|
  sh "javac -source 1.5 -target 1.5 -d #{t.prerequisites.first} #{Dir['src/spec/java/**/*.java'].join(' ')}"
end

desc "Unpack the rack gem"
task :unpack_gem => "target" do |t|
  Dir.chdir(t.prerequisites.first) do
    unless File.directory?("rack")
      ruby "-S", "gem", "unpack", FileList["../src/main/lib/rack*.gem"].first
      mv FileList["rack-*"].first, "rack"
    end
  end
end

version_file = 'src/main/ruby/jruby/rack/version.rb'
load version_file

task :update_version do
  if ENV["VERSION"] && ENV["VERSION"] != JRuby::Rack::VERSION
    lines = File.readlines(version_file)
    lines.each {|l| l.sub!(/VERSION =.*$/, %{VERSION = "#{ENV["VERSION"]}"})}
    File.open(version_file, "wb") {|f| f.puts *lines }
  end
end

desc "Copy resources"
task :resources => ["target/classes", :unpack_gem, :update_version] do |t|
  ['src/main/ruby', 'target/rack/lib'].each do |dir|
    FileList["#{dir}/*"].each do |f|
      cp_r f, t.prerequisites.first
    end
  end
  meta_inf = File.join(t.prerequisites.first, "META-INF")
  mkdir_p meta_inf
  cp "src/main/tld/jruby-rack.tld", meta_inf
end

task :speconly do
  if ENV['SKIP_SPECS'] && !ENV['SKIP_SPECS'].empty?
    puts "Skipping specs due to SKIP_SPECS=#{ENV['SKIP_SPECS']}"
  else
    ruby "-S", "spec", "--format", "specdoc", *FileList["src/spec/ruby/**/*_spec.rb"].to_a
  end
end

desc "Run specs"
task :spec => [:compile, :resources, :compilespec, :speconly]

task :test => :spec

desc "Create the jar"
task :jar => :spec do
  sh "jar cf target/jruby-rack-#{JRuby::Rack::VERSION}.jar -C target/classes ."
end

task :default => :jar

task :classpath do
  puts "export CLASSPATH=#{ENV['CLASSPATH']}"
end
