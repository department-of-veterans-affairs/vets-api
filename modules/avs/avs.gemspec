# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'avs/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'avs'
  spec.version     = Avs::VERSION
  spec.authors     = ['Adrian Rollett']
  spec.email       = ['adrian.rollett@va.gov']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'After Visit Summary API'
  spec.description = 'API endpoints for After Visit Summaries'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
