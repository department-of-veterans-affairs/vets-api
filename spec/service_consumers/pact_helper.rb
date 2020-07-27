# frozen_string_literal: true

# ensure pacts run in test
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __dir__)
require 'pact/provider/rspec'
require 'rspec/rails'
require 'support/factory_bot'
require 'service_consumers/add_authentication_headers'
require 'support/authenticated_session_helper'
require 'support/vcr'
require 'support/mvi/stub_mvi'
require 'support/stub_emis'
require 'support/vet360/stub_vet360'
Dir.glob(File.expand_path('../provider_states_for/*.rb', __FILE__), &method(:require))

VCR.configure do |c|
  # PACT requests are performed before insert_cassette is invoked
  c.allow_http_connections_when_no_cassette = true
end

# Ensure your provider application version enables you to trace back to an exact
# state of your provider codebase.
# The easiest way to do this is to include the build number (or a SHA) in your version.
git_sha = ENV['GIT_COMMIT'] || `git rev-parse --verify HEAD`
git_branch = ENV['GIT_BRANCH'] || `git rev-parse --abbrev-ref HEAD`
# don't publish results if running in local development env
publish_flag = ENV['PUBLISH_PACT_VERIFICATION_RESULTS'] == "true" || (! Rails.env.development?)

RSpec.configure do |config|
  config.before do |example|
    stub_mvi unless example.metadata[:skip_mvi]
    stub_emis unless example.metadata[:skip_emis]
    stub_vet360 unless example.metadata[:skip_vet360]
  end

  #If we can figure out which directory the dynamic specs from pact are generated in, 
  # we may be able to define type: :request and have access to the cookies hash
  # thus, being able to use sign_in_as(user) <--- which will set the cookie for us
  
  # config.define_derived_metadata(:file_path => Regexp.new('/spec/service_consumers/*')) do |metadata|
  #   metadata[:type] = :request
  # end
end

Pact.service_provider 'VA.gov API' do
  # inject the auth headers via Rack reverse proxy
  app { AddAuthenticationHeaders.new(Rails.application) }
    
  # This example points to a local file, however, on a real project with a continuous
  # integration box, you would use a [Pact Broker](https://github.com/pact-foundation/pact_broker)
  # or publish your pacts as artifacts, and point the pact_uri to the pact published by the last successful build.
  # honours_pact_with 'HCA Post' do
  #   pact_uri 'tmp/hca-va.gov_api.json'
  # end
  honours_pact_with 'Forms' do
    pact_uri 'spec/service_consumers/do_not_merge/forms.gov_api.json'
  end

  honours_pact_with 'Users' do
    pact_uri 'spec/service_consumers/do_not_merge/users_profile.gov_api.json'
  end

  app_version git_sha
  app_version_tags git_branch
  publish_verification_results publish_flag

  # honours_pacts_from_pact_broker do
  #   pact_broker_base_url 'https://vagov-pact-broker.herokuapp.com'
  # end
end
