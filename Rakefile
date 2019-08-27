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
    t.pattern = Dir.glob(
      [
        'spec/**/*_spec.rb',
        'modules/vba_documents/spec/**/*_spec.rb',
        'modules/appeals_api/spec/**/*_spec.rb',
        'modules/claims_api/spec/**/*_spec.rb',
        'modules/va_facilities/spec/**/*_spec.rb',
        'modules/veteran/spec/**/*_spec.rb',
        'modules/veteran_verification/spec/**/*_spec.rb',
        'modules/openid_auth/spec/**/*_spec.rb'
      ]
    )
    t.verbose = false
  end
end
