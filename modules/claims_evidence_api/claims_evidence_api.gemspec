# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'claims_evidence_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'claims_evidence_api'
  spec.version     = ClaimsEvidenceApi::VERSION
  spec.authors     = ['Wayne Weibel']
  spec.email       = ['wayne.weibel@adhocteam.us']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'Interaction with the Claims Evidence API - a file service for handling the storage and management of files supporting VA benefit claims. It serves as a modernized point of entry to files previously only accessible through VBMS eFolder. It is designed for easier implementation by consuming systems, but also with the ability to eventually replace the eFolder logic within VBMS.'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
