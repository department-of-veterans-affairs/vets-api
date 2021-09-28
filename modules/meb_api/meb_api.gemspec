# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'meb_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'meb_api'
  spec.version     = MebApi::VERSION
  spec.authors     = ['bradbergeron-us']
  spec.email       = ['bradley.bergeron@va.gov']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'My Education Benefits Automation Service API'
  spec.description = 'The My Education Benefits API allows for pre-populating benefit form data and decisions from existing databases.'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
