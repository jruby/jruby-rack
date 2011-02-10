module DemoHelpers
  @@capture = []
  def capture
    @@capture
  end

  def pre_capture_paths
    require 'rbconfig'
    @@capture += ["jruby.home: #{Config::CONFIG['prefix']}",
                  "Gem.dir: #{Gem.dir}",
                  "Gem.path: #{Gem.path}",
                  "$LOAD_PATH:"
                 ] + $LOAD_PATH
  end

  def post_capture_paths
    @@capture += ["",
                  "After Bundler.setup",
                  "Bundler.bundle_path: #{Bundler.bundle_path}",
                  "Bundler.root: #{Bundler.root}",
                  "Gem.dir: #{Gem.dir}",
                  "Gem.path: #{Gem.path}",
                  "$LOAD_PATH:"
                 ] + $LOAD_PATH
  end

  def write_environment(content = nil, exception = nil)
    require 'socket'
    if defined?(WARBLER_CONFIG) &&
        File.directory?(WARBLER_CONFIG['ENV_OUTPUT']) &&
        WARBLER_CONFIG['ENV_HOST'] == Socket.gethostname
      server_name = $servlet_context.server_info[/(.*)\(?/, 1].strip.gsub(/[^a-zA-Z0-9]+/, '-')
      file_name = File.join(WARBLER_CONFIG['ENV_OUTPUT'], server_name + '.txt')
      File.open(file_name, "wb") do |f|
        if content
          f.puts content
        else
          f.puts "Server: #{$servlet_context.server_info}"
          f.puts "Ruby: #{RUBY_DESCRIPTION}"
          f.puts "Generated: #{Time.now.to_s}"
          f.puts
          f.puts "--- Boot variables"
          f.puts *@@capture
        end
        if exception
          f.puts "--- Exception"
          f.puts e, *e.backtrace
        end
      end rescue $stderr.puts("Couldn't write environment to #{file_name}: #{$!}")
    end
  end
end
