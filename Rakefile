#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

raise "JRuby-Rack must be built with JRuby: try again with `jruby -S rake'" unless defined?(JRUBY_VERSION)

begin
  require 'bundler/setup'
rescue LoadError => e
  require('rubygems') && retry
  puts "Please install Bundler and run `bundle install` to ensure you have all dependencies"
  raise e
end
require 'appraisal'

desc "Remove target directory"
task :clean do
  rm_r 'target' rescue nil
end

GENERATED = FileList.new

namespace :clean do
  desc "Remove generated files"
  task :generated do
    GENERATED.each { |fn| rm_r fn rescue nil }
  end
end

directory 'target/classes'

file 'target/classpath.rb' do
  sh 'mvn org.jruby.plugins:jruby-rake-plugin:classpath -Djruby.classpath.scope=test'
end
GENERATED << 'target/classpath.rb'

desc "Compile classes"
task :compile => [:'target/classes'] do |t|
  sh 'mvn compile'
end

directory 'target/test-classes'

desc "Compile test classes"
task :test_compile => ['target/test-classes'] do |t|
  sh 'mvn test-compile'
end

desc "Unpack the rack gem"
task :unpack_gem => "target" do |t|
  target = File.expand_path(t.prerequisites.first)
  spec = Gem.loaded_specs["rack"]
  if spec.respond_to?(:cache_file)
    gem_file = spec.cache_file
  else
    gem_file = File.join(spec.installation_path, 'cache', spec.file_name)
  end
  unless uptodate?("#{target}/vendor/rack.rb", [__FILE__, gem_file])
    mkdir_p "target/vendor"
    require 'rubygems/installer'
    rack_dir = File.basename(gem_file).sub(/\.gem$/, '')
    Gem::Installer.new(gem_file, :unpack => true, :install_dir => rack_dir).unpack "#{target}/#{rack_dir}"
    File.open("#{target}/vendor/rack.rb", "w") do |f|
      f << "dir = File.dirname(__FILE__)\n"
      f << "if dir =~ /.jar!/ && dir !~ /^file:/\n"
      f << "  $LOAD_PATH.unshift 'file:' + dir + '/#{rack_dir}'\n"
      f << "else\n"
      f << "  $LOAD_PATH.unshift dir + '/#{rack_dir}'\n"
      f << "end\n"
      f << "require 'rack'"
    end
  end
end
GENERATED << 'target/vendor/rack.rb'

desc "Generate (ruby) resources"
task :resources => ['target/classes', :unpack_gem] do |t|
  rack_dir = File.basename(FileList["target/rack-*"].first)
  classes_dir = t.prerequisites.first
  { 'target/vendor' => "#{classes_dir}/vendor",
    "target/#{rack_dir}/lib" => "#{classes_dir}/vendor/#{rack_dir}"}.each do |src,dest|
    mkdir_p dest
    FileList["#{src}/*"].each do |f|
      cp_r f, dest
    end
  end
end

task :test_resources => ['target/test-classes'] do |t|
  FileList["src/spec/ruby/merb/gems/gems/merb-core-*/lib/*"].each do |f|
    cp_r f, t.prerequisites.first
  end
end

namespace :resources do
  desc "Copy (and generate) resources"
  task :copy => :resources do
    sh 'mvn process-resources'
  end
  desc "Generate test resources"
  task :test => :test_resources
end

task :speconly => ['target/classpath.rb', :resources, :test_resources] do
  if ENV['SKIP_SPECS'] && ENV['SKIP_SPECS'] == "true"
    puts "Skipping specs due to SKIP_SPECS=#{ENV['SKIP_SPECS']}"
  else
    opts = ENV['SPEC_OPTS'] ? ENV['SPEC_OPTS'] : %q{ --format documentation --color }
    spec = ENV['SPEC'] || File.join(Dir.getwd, "src/spec/ruby/**/*_spec.rb")
    opts = opts.split(' ').push *FileList[spec].to_a
    ruby "-Isrc/spec/ruby", "-rbundler/setup", "-S", "rspec", *opts
  end
end

desc "Run specs"
task :spec => [:compile, :test_compile, :speconly]
task :test => :spec

POM_FILE = 'pom.xml'
VERSION_FILE = 'src/main/ruby/jruby/rack/version.rb'

GEM_VERSION = 
  if File.read(VERSION_FILE).match(/VERSION =.*?['"](.+)['"].*?$/m)
    $1
  else
    raise "VERSION = ... not matched in #{VERSION_FILE}"
  end
  
JAR_VERSION = GEM_VERSION.sub(/\.(\D+\w*)/, '-\1') # 1.1.1.SNAPSHOT -> 1.1.1-SNAPSHOT

file "target/jruby-rack-#{JAR_VERSION}.jar" => :compile do |t|
  sh "jar cf #{t.name} -C target/classes ." # TODO `mvn package` instead ?
end

desc "Create the jruby-rack-#{JAR_VERSION}.jar"
task :jar => (target_jar = "target/jruby-rack-#{JAR_VERSION}.jar")

task :default => :jar

task :debug do
  ENV['DEBUG'] = 'true'
  Rake::Task['jar'].invoke
end

desc "Print the (Maven) class-path"
task :classpath => 'target/classpath.rb' do
  require './target/classpath'
  classpath = Maven.classpath
  classpath = classpath.reject { |p| p =~ /target\/(test-)?classes$/ }
  puts *classpath
end

file 'target/gem/lib/jruby-rack.rb' do |t|
  mkdir_p File.dirname(t.name)
  File.open(t.name, "wb") do |f|
    f << %Q{
module JRubyJars
  def self.jruby_rack_jar_path
    File.expand_path("../jruby-rack-#{JAR_VERSION}.jar", __FILE__)
  end
  require jruby_rack_jar_path if defined?(JRUBY_VERSION)
end
}
  end
end
GENERATED << 'target/gem/lib/jruby-rack.rb'

file "target/gem/lib/jruby/rack/version.rb" => "src/main/ruby/jruby/rack/version.rb" do |t|
  mkdir_p File.dirname(t.name)
  cp t.prerequisites.first, t.name
end

desc "Build the jruby-rack-#{GEM_VERSION}.gem"
task :gem => [target_jar, "target/gem/lib/jruby-rack.rb", "target/gem/lib/jruby/rack/version.rb"] do |t|
  Rake::Task['spec'].invoke
  cp FileList["History.txt", "LICENSE.txt", "README.md"], "target/gem"
  cp t.prerequisites.first, "target/gem/lib"
  if (jars = FileList["target/gem/lib/*.jar"].to_a).size > 1
    abort "Too many jars! #{jars.map{|j| File.basename(j)}.inspect}\nRun a clean build `rake clean` first"
  end
  require 'date'
  Dir.chdir("target/gem") do
    rm_f 'jruby-rack.gemspec'
    gemspec = Gem::Specification.new do |s|
      s.name = %q{jruby-rack}
      s.version = GEM_VERSION
      s.authors = ['Nick Sieger']
      s.date = Date.today.to_s
      s.description = %{JRuby-Rack is a combined Java and Ruby library that adapts the Java Servlet API to Rack. For JRuby only.}
      s.summary = %q{Rack adapter for JRuby and Servlet Containers}
      s.email = ['nick@nicksieger.com']
      s.files = FileList["./**/*"].exclude("*.gem").map{|f| f.sub(/^\.\//, '')}
      s.homepage = %q{http://jruby.org}
      s.has_rdoc = false
      s.rubyforge_project = %q{jruby-extras}
    end
    Gem::Builder.new(gemspec).build
    File.open('jruby-rack.gemspec', 'w') {|f| f << gemspec.to_ruby }
    mv FileList['*.gem'], '..'
  end
end
GENERATED << 'target/gem/jruby-rack.gemspec'

task :release_checks do
  sh "git diff --exit-code > /dev/null" do |ok,_|
    fail "There are uncommitted changes.\nPlease commit changes or clean workspace before releasing." unless ok
  end

  sh "git rev-parse #{GEM_VERSION} > /dev/null 2>&1" do |ok,_|
    fail "Tag #{GEM_VERSION} already exists.\n" +
      "Please execute these commands to remove it before releasing:\n" +
      "  git tag -d #{GEM_VERSION}\n" +
      "  git push origin :#{GEM_VERSION}" if ok
  end

  pom_version = `mvn help:evaluate -Dexpression=project.version`.
    split("\n").reject { |line| line =~ /[INFO]/ }.first.chomp
  if pom_version =~ /dev|SNAPSHOT/
    fail "Can't release a dev/snapshot version.\n" +
      "Please update pom.xml to the final release version, run `mvn install', and commit the result."
  end

  unless pom_version.sub(/\-(\D+\w*)/, '.\1') == GEM_VERSION
    fail "Can't release because pom.xml version (#{pom_version}) is different than " +
      "jruby/rack/version.rb (#{GEM_VERSION}).\n" +
      "Please run `mvn install' to bring the two files in sync."
  end

  puts "Release looks ready to go!"
end

desc "Release the gem to rubygems and jar to repository.codehaus.org"
task :release => [:release_checks, :clean, :gem] do
  sh "git tag #{GEM_VERSION}"
  sh "mvn deploy -DupdateReleaseInfo=true"
  sh "gem push target/jruby-rack-#{GEM_VERSION}.gem"
  sh "git push --tags #{ENV['GIT_REMOTE'] || 'origin'} master"
  puts "released JRuby-Rack #{GEM_VERSION} update next SNAPSHOT version using `rake update_version`"
end

task :update_version do
  version = ENV["VERSION"] || ''
  if version.empty? # next version
    gem_version = Gem::Version.create(GEM_VERSION)
    if gem_version.segments.last.is_a?(String)
      version = gem_version.segments[0...-1] # 1.1.1.SNAPSHOT -> 1.1.1
    else  # 1.1.1 -> 1.1.2.SNAPSHOT
      version = gem_version.segments.dup
      version[-1] = version[-1] + 1
      version = version + ['SNAPSHOT']
    end
    version = version.join('.')
  end
  if version != GEM_VERSION
    gem_version = Gem::Version.create(version) # validates VERSION string
    
    lines = File.readlines(VERSION_FILE) # update JRuby::Rack::VERSION
    lines.each {|l| l.sub!(/VERSION =.*$/, %{VERSION = '#{version}'})}
    File.open(VERSION_FILE, "wb") { |f| f.puts *lines }
    
    pom_version = if gem_version.prerelease?
      segs = gem_version.segments
      "#{segs[0...-1].join('.')}-#{segs[-1]}"
    else
      gem_version.version
    end
    doc = nil # update pom.xml <version>
    File.open(POM_FILE, 'r') do |file|
      require "rexml/document"
      doc = REXML::Document.new file
      doc.root.elements.each('version') { |el| el.text = pom_version }
    end
    File.open(POM_FILE, 'w') do |file|
      file.puts doc.to_s
    end if doc
  end
end
