#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    class Errors
      EXCEPTION = org.jruby.rack.RackEnvironment::EXCEPTION
      def initialize(file_server)
        @file_server = file_server
      end

      def call(env)
        [code = response_code(env), *response_content(env, code)]
      end

      def response_code(env)
        exc = env[EXCEPTION]
        if exc
          env['rack.showstatus.detail'] = exc.getMessage
          if exc.getCause.kind_of?(Java::JavaLang::InterruptedException)
            503
          else
            500
          end
        else
          500
        end
      end

      def response_content(env, code)
        @responses ||= Hash.new do |h,k|
          env["PATH_INFO"] = "/#{code}.html"
          response = @file_server.call(env)
          body = response[2]
          unless Array === body
            newbody = ""
            body.each do |chunk|
              newbody << chunk
            end
            response[2] = [newbody]
          end
          h[k] = response
        end
        response = @responses[code]
        if response[0] != 404
          env["rack.showstatus.detail"] = nil
          response[1..2]
        else
          [{}, []]
        end
      end
    end

    class ErrorsApp
      def self.new
        ::Rack::Builder.new {
          use ::Rack::ShowStatus
          run Errors.new(::Rack::File.new(JRuby::Rack.booter.public_path))
        }.to_app
      end
    end
  end
end
