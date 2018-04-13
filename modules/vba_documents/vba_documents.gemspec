$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "vba_documents/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "vba_documents"
  s.version     = VBADocuments::VERSION
  s.authors     = ["Patrick Vinograd"]
  s.email       = ["patrick@adhocteam.us"]
  s.homepage    = "https://api.vets.gov/services/vba_documents/docs/v0"
  s.summary     = "VBA Documents Upload"
  s.description = "VBA Documents Upload API"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.7.1"
  s.add_dependency "aws-sdk-s3", "~> 1"

  s.add_development_dependency "sqlite3"
end
