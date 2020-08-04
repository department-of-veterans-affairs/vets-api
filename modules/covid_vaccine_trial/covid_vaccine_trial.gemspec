$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'covid_vaccine_trial/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'covid_vaccine_trial'
  spec.version     = CovidVaccineTrial::VERSION
  spec.authors     = ['LeakyBucket']
  spec.email       = ['Lawrence.Holcomb@va.gov']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'COVID Vaccine Trial API'
  spec.description = 'This is in support of volunteer intake for VA\'s potential COVID Vaccine trails'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']

  spec.add_dependency 'rails', '~> 6.0.3', '>= 6.0.3.2'
  spec.add_dependency 'sidekiq'

  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'rspec-rails'
end
