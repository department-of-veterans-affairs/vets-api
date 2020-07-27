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
  config.include AuthenticatedSessionHelper
  config.define_derived_metadata do |metadata|
    metadata[:type] = :request
  end

  config.before do |example|

    user = FactoryBot.build(:user, :loa3)
    session_object = sign_in(user, nil, nil, true)
    allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session_object.to_hash)

    stub_mvi unless example.metadata[:skip_mvi]
    stub_emis unless example.metadata[:skip_emis]
    stub_vet360 unless example.metadata[:skip_vet360]
  end
end

Pact.service_provider 'VA.gov API' do
  # inject the auth headers via Rack reverse proxy
  # app { AddAuthenticationHeaders.new(Rails.application) }
    
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
  # publish_verification_results publish_flag

  # honours_pacts_from_pact_broker do
  #   pact_broker_base_url 'https://vagov-pact-broker.herokuapp.com'
  # end
end
