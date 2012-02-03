WARBLER_CONFIG = {"public.root"=>"/", "rails.env"=>"production", "jruby.min.runtimes"=>"1", "jruby.max.runtimes"=>"2"}
ENV['GEM_HOME'] ||= $servlet_context.getRealPath('/WEB-INF/gems')
ENV['BUNDLE_WITHOUT'] = 'development:test'
ENV['BUNDLE_GEMFILE'] = 'Gemfile'

ENV['RAILS_ENV'] = 'production'
