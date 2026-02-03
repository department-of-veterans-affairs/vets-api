# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'debts_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'debts_api'
  spec.version     = DebtsApi::VERSION
  spec.authors     = ['Scott James']
  spec.email       = ['scott.james@govcio.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'API to provide endpoints for benefit debts, medical copays, and 5655 form'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']

  spec.add_dependency 'active_storage_validations', '~> 3.0.2'
end
