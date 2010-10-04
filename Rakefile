#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

raise "JRuby-Rack must be built with JRuby: try again with `jruby -S rake'" unless defined?(JRUBY_VERSION)

require 'rake/clean'
require 'date'
require 'java'

def compile_classpath
  if ENV['JRUBY_PARENT_CLASSPATH']
    classpath = []
    ENV['JRUBY_PARENT_CLASSPATH'].split(File::PATH_SEPARATOR).each {|p| classpath << p}
  else
    java_classpath = Java::JavaLang::System.getProperty("java.class.path").split(File::PATH_SEPARATOR)
    java_classpath += Java::JavaLang::System.getProperty("sun.boot.class.path").split(File::PATH_SEPARATOR)
    classpath = Dir["#{File.expand_path 'src/main/lib'}/*.jar"] + java_classpath
  end
end

def test_classpath
  compile_classpath + [File.expand_path("target/classes"), File.expand_path("target/test-classes")]
end

CLEAN << 'target'

directory 'target/classes'

desc "Compile java classes"
task :compile => "target/classes" do |t|
  sh 'javac -Xlint:deprecation -Xlint:unchecked -classpath "' + compile_classpath.join(File::PATH_SEPARATOR) + '" -source 1.5 ' +
    '-target 1.5 -d ' + t.prerequisites.first + ' ' + Dir["src/main/java/**/*.java"].join(" ")
end

directory 'target/test-classes'

desc "Compile classes used for test/spec"
task :compilespec => "target/test-classes" do |t|
  sh 'javac -classpath "' + test_classpath.join(File::PATH_SEPARATOR) + '" -source 1.5 ' +
    '-target 1.5 -d ' + t.prerequisites.first + ' ' + Dir["src/spec/java/**/*.java"].join(" ")
end

desc "Unpack the rack gem"
task :unpack_gem => "target" do |t|
  Dir.chdir(t.prerequisites.first) do
    gem_file = FileList["../src/main/lib/rack*.gem"].first
    unless uptodate?("vendor/rack.rb", [__FILE__, gem_file])
      mkdir_p "vendor"
      require 'rubygems/installer'
      path = File.basename(gem_file).sub(/\.gem$/, '')
      Gem::Installer.new(gem_file, :unpack => true, :install_dir => path).unpack path
      rack_dir = FileList["rack-*"].first
      File.open("vendor/rack.rb", "w") do |f|
        f << "dir = File.dirname(__FILE__)\n"
        f << "if dir =~ /.jar!/ && dir !~ /^file:/\n"
        f << "$LOAD_PATH.unshift 'file:' + dir + '/#{rack_dir}'\n"
        f << "else\n"
        f << "$LOAD_PATH.unshift dir + '/#{rack_dir}'\n"
        f << "end\n"
        f << "require 'rack'"
      end
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


task :test_resources => ["target/test-classes"] do |t|
  FileList["src/spec/ruby/merb/gems/gems/merb-core-*/lib/*"].each do |f|
    cp_r f, t.prerequisites.first
  end
end

desc "Copy resources"
task :resources => ["target/classes", :unpack_gem, :update_version, :test_resources] do |t|
  rack_dir = File.basename(FileList["target/rack-*"].first)
  classes_dir = t.prerequisites.first
  { 'src/main/ruby' => classes_dir,
    'target/vendor' => "#{classes_dir}/vendor",
    "target/#{rack_dir}/lib" => "#{t.prerequisites.first}/vendor/#{rack_dir}"}.each do |src,dest|
    mkdir_p dest
    FileList["#{src}/*"].each do |f|
      cp_r f, dest
    end
  end
  meta_inf = File.join(t.prerequisites.first, "META-INF")
  mkdir_p meta_inf
  cp "src/main/tld/jruby-rack.tld", meta_inf
end

task :speconly do
  if ENV['SKIP_SPECS'] && ENV['SKIP_SPECS'] == "true"
    puts "Skipping specs due to SKIP_SPECS=#{ENV['SKIP_SPECS']}"
  else
    test_classpath.each {|p| $CLASSPATH << p }
    opts = ["--format", "specdoc"]
    opts << ENV['SPEC_OPTS'] if ENV['SPEC_OPTS']
    spec = ENV['SPEC'] || File.join(Dir.getwd, "src/spec/ruby/**/*_spec.rb")
    opts.push *FileList[spec].to_a
    ENV['CLASSPATH'] = test_classpath.join(File::PATH_SEPARATOR)
    ruby "-Isrc/spec/ruby", "-S", "spec", *opts
  end
end

desc "Run specs"
task :spec => [:compile, :resources, :compilespec, :speconly]

task :test => :spec

file "target/jruby-rack-#{JRuby::Rack::VERSION}.jar" => :always_build do |t|
  Rake::Task['spec'].invoke
  sh "jar cf #{t.name} -C target/classes ."
end
task :always_build              # dummy task to force jar to get built

desc "Create the jar"
task :jar => [:spec, "target/jruby-rack-#{JRuby::Rack::VERSION}.jar"]

task :default => :jar

task :install => "target/jruby-rack-#{JRuby::Rack::VERSION}.jar" do |t|
  repos_dir = File.expand_path "~/.m2/repository/org/jruby/rack/jruby-rack/#{JRuby::Rack::VERSION}"
  mkdir_p repos_dir
  cp t.prerequisites.first, repos_dir
  cp "pom.xml", "#{repos_dir}/jruby-rack-#{JRuby::Rack::VERSION}.pom"
end

task :classpaths do
  puts "compile_classpath:",*compile_classpath
  puts "test_classpath:", *test_classpath
end

file "target/gem/lib/jruby-rack.rb" do |t|
  mkdir_p File.dirname(t.name)
  File.open(t.name, "wb") do |f|
    f << %q{require 'jruby/rack/version'
module JRubyJars
  def self.jruby_rack_jar_path
    File.expand_path("../jruby-rack-#{JRuby::Rack::VERSION}.jar", __FILE__)
  end
  require jruby_rack_jar_path
end
}
  end
end

file "target/gem/lib/jruby/rack/version.rb" => "src/main/ruby/jruby/rack/version.rb" do |t|
  mkdir_p File.dirname(t.name)
  cp t.prerequisites.first, t.name
end

desc "Build gem"
task :gem => ["target/jruby-rack-#{JRuby::Rack::VERSION}.jar",
              "target/gem/lib/jruby-rack.rb",
              "target/gem/lib/jruby/rack/version.rb"] do |t|
  cp FileList["History.txt", "LICENSE.txt", "README.md"], "target/gem"
  cp t.prerequisites.first, "target/gem/lib"
  if (jars = FileList["target/gem/lib/*.jar"].to_a).size > 1
    abort "Too many jars! #{jars.map{|j| File.basename(j)}.inspect}\nRun a clean build first"
  end
  Dir.chdir("target/gem") do
    gemspec = Gem::Specification.new do |s|
      s.name = %q{jruby-rack}
      s.version = JRuby::Rack::VERSION.sub(/-SNAPSHOT/, '')
      s.authors = ["Nick Sieger"]
      s.date = Date.today.to_s
      s.description = %{JRuby-Rack is a combined Java and Ruby library that adapts the Java Servlet API to Rack. For JRuby only.}
      s.summary = %q{Rack adapter for JRuby and Servlet Containers}
      s.email = ["nick@nicksieger.com"]
      s.files = FileList["./**/*"].exclude("*.gem")
      s.homepage = %q{http://jruby.org}
      s.has_rdoc = false
      s.rubyforge_project = %q{jruby-extras}
    end
    Gem::Builder.new(gemspec).build
    mv FileList['*.gem'], '..'
  end
end
