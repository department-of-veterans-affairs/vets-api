# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Triage Teams Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }

  before(:each) do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }
    before(:each) { get '/v0/messaging/health/recipients' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }
    before(:each) { get '/v0/messaging/health/recipients' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before(:each) { get '/v0/messaging/health/recipients' }
      let(:va_patient) { false }

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
        get '/v0/messaging/health/recipients'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('triage_teams')
    end
  end
end
