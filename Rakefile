# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'rake'
require 'datadog'
require_relative 'config/application'

Datadog.configure do |c|
  c.tracing.instrument :rake
end

# Load rake support files
Rails.root.glob('lib/tasks/support/**/*.rb').each { |f| require f }
Rake.add_rakelib 'rakelib/prod'
Rails.application.load_tasks

unless Rails.env.production?
  require 'rspec/core/rake_task'
  task(spec: :environment).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = Dir.glob(['spec/**/*_spec.rb', 'modules/*/spec/**/*_spec.rb'])
    t.verbose = false
  end
end
