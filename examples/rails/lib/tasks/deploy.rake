def load_warbler
  gem 'warbler'
  require 'warbler'
  Warbler::Task.new
end

task :clean do
  load_warbler
  Rake::Task['war:clean']
end

task :warble do
  load_warbler
  Rake::Task['war']
end

task :deploy => :warble do
  sh "asadmin deploy --name rails --contextroot rails tmp/war"
end

task :undeploy do
  sh "asadmin undeploy rails"
end
