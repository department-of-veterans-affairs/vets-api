$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'covid_research/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'covid_research'
  spec.version     = CovidResearch::VERSION
  spec.authors     = ['LeakyBucket']
  spec.email       = ['Lawrence.Holcomb@va.gov']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'CovidResearch API'
  spec.description = 'This exists to support the intake of COVID Research volunteers'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']

  spec.add_dependency 'rails', '~> 6.1.5'
  spec.add_dependency 'sidekiq'

  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'rspec-rails'
end
