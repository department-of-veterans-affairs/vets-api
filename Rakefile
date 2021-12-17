# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'rake'
require 'ddtrace'
require_relative 'config/application'

Datadog.configure do |c|
  c.use :rake
end

# Load rake support files
Dir[Rails.root.join('lib', 'tasks', 'support', '**', '*.rb')].sort.each { |f| require f }
Rails.application.load_tasks

unless Rails.env.production?
  require 'rspec/core/rake_task'
  require 'pact/tasks'
  task(spec: :environment).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = Dir.glob(['spec/**/*_spec.rb', 'modules/*/spec/**/*_spec.rb'])
    t.verbose = false
  end

  task default: 'pact:verify'
end
