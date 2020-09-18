# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'vaos/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'vaos'
  s.version     = VAOS::VERSION
  s.authors     = ['Alastair Dawson']
  s.email       = ['alastair@adhocteam.us']
  s.homepage    = 'https://api.va.gov'
  s.summary     = 'VAOS API'
  s.description = 'VOAS (VA Online Scheduling) is part of VAMF (VA Mobile Framework) and allows veterans to make and manage appointments for care'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'sidekiq'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pg'

  s.add_development_dependency 'rspec-rails'
end
