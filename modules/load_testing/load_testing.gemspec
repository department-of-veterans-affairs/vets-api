lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'load_testing/version'

Gem::Specification.new do |spec|
  spec.name          = 'load_testing'
  spec.version       = LoadTesting::VERSION
  spec.authors       = ['Department of Veterans Affairs']
  spec.email         = ['']
  spec.summary       = 'Load testing framework for VA authentication'
  spec.description   = 'Provides load testing capabilities for VA authentication flows'
  spec.homepage      = 'https://github.com/department-of-veterans-affairs/vets-api'
  spec.license       = 'CC0-1.0'

  spec.files         = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '~> 7.1.3'
  spec.add_dependency 'sidekiq'

  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'factory_bot_rails'
  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'simplecov'
end 