# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'mobile/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'mobile'
  spec.version     = Mobile::VERSION
  spec.authors     = ['Alastair Dawson', 'Jonathan Julian']
  spec.email       = ['alastair@adhocteam.us', 'jonathan@adhocteam.us']
  spec.homepage    = 'https://www.va.gov'
  spec.summary     = 'VA Mobile API'
  spec.description = 'API endpoints for the flagship VA Mobile iOS and Android Apps.'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']
  
  spec.add_development_dependency 'factory_bot_rails'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'rspec-rails'
end
