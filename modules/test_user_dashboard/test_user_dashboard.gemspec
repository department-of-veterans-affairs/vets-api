$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "test_user_dashboard/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "test_user_dashboard"
  spec.version     = TestUserDashboard::VERSION
  spec.authors     = ["John Bramley"]
  spec.email       = ["john.bramley@adhocteam.us"]
  spec.summary     = "Test User Dashboard API"
  spec.description = "Test User Dashboard manages the creation, modification, and use of va.gov test user accounts."
  spec.homepage    = 'https://api.va.gov'
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  # restore when adding specs
  # spec.test_files = Dir['spec/**/*']
  spec.add_dependency "rails", "~> 6.0.3", ">= 6.0.3.4"
  # spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency "pg"
end
