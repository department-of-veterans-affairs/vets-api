# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

# Load rake support files
Dir[Rails.root.join('lib', 'tasks', 'support', '**', '*.rb')].each { |f| require f }

Rails.application.load_tasks

unless Rails.env.production?
  require 'rspec/core/rake_task'
  task(:spec).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb,modules/*/spec/**/*_spec.rb'
  end
end
