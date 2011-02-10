module DemoCaptureHelper
  def capture
    super
    output.puts("\n--- Request Environment", *(request.env.keys.sort.map do |k|
                                                 "#{k} = #{request.env[k]}"
                                               end))
  end
end

module FileStoreHelper
  def store
    require 'socket'
    if defined?(WARBLER_CONFIG) &&
        File.directory?(WARBLER_CONFIG['ENV_OUTPUT']) &&
        WARBLER_CONFIG['ENV_HOST'] == Socket.gethostname
      server_name = $servlet_context.server_info[/(.*)\(?/, 1].strip.gsub(/[^a-zA-Z0-9]+/, '-')
      file_name = File.join(WARBLER_CONFIG['ENV_OUTPUT'], server_name + '.txt')
      File.open(file_name, "wb") do |f|
        f << output.string
      end rescue $stderr.puts("Couldn't write environment to #{file_name}: #{$!}")
    end
    super rescue nil
  end
end

module DemoDummyHelper
  def output
    @output ||= begin; require 'stringio'; StringIO.new; end
  end

  def capture
    output.puts erb(:env)
  end

  def store
  end
end

if defined?(JRuby::Rack::Capture)
  class StandardError
    include JRuby::Rack::Capture::Environment
    include JRuby::Rack::Capture::JavaEnvironment
    include FileStoreHelper
  end
end
