require "bundler/gem_tasks"
require "rspec/core/rake_task"

task default: :spec

desc "Run specs"
RSpec::Core::RakeTask.new

namespace :example do
  desc 'Start example Sinatra application'
  task :sinatra do
    require './example/sinatra/app'
     SinatraExampleApp.run!
  end

  desc 'Start example Rails application'
  task :rails do
    require './example/rails/config/environment'
    require "thin"
    Thin::Server.start('0.0.0.0', 3000) do
      run EscrowExample::Application.to_app
    end
  end
end

