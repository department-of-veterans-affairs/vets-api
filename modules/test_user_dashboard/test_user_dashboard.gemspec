# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'test_user_dashboard/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'test_user_dashboard'
  spec.version     = TestUserDashboard::VERSION
  spec.authors     = ['John Bramley']
  spec.email       = ['john.bramley@adhocteam.us']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'Test User Dashboard API'
  spec.description = 'The Test User Dashboard API supports the TUD frontend'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']

  spec.add_dependency 'rails', '~> 6.1.5'

  spec.add_development_dependency 'factory_bot_rails'
  spec.add_development_dependency 'rspec-rails'
end
