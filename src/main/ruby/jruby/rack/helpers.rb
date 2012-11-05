#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    module Helpers
    
      module_function

      def silence_warnings
        verbose, $VERBOSE = $VERBOSE, nil
        begin
          yield
        ensure
          $VERBOSE = verbose
        end
      end
      
    end
  end
end