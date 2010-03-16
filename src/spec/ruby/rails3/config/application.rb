module Myapp
  class Application
    def call(env)
      env['myapp.application'] = 'called'
      [200, {}, [""]]
    end
  end
end

Rails.application = Myapp::Application.new
