$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "veteran_service/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "veteran_service"
  s.version     = VeteranService::VERSION
  s.authors     = ["Michael Bastos"]
  s.email       = ["bastosmichael@gmail.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of VeteranService."
  s.description = "TODO: Description of VeteranService."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.11.1"

  s.add_development_dependency 'rspec-rails'
end
