# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Triage Teams Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:mhv_account_type) { 'Premium' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    sign_in_as(current_user)
  end

  context 'when sm session policy is enabled' do
    before do
      Flipper.enable(:mhv_sm_session_policy)
      Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
    end

    after do
      Flipper.disable(:mhv_sm_session_policy)
      Timecop.return
    end

    context 'when NOT authorized' do
      before do
        VCR.insert_cassette('sm_client/session_error')
        get '/my_health/v1/messaging/recipients'
      end

      after do
        VCR.eject_cassette
      end

      include_examples 'for user account level', message: 'You do not have access to messaging'
    end

    context 'when authorized' do
      before do
        VCR.insert_cassette('sm_client/session')
      end

      after do
        VCR.eject_cassette
      end

      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
          get '/my_health/v1/messaging/recipients'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('triage_teams')
      end

      it 'responds to GET #index when camel-inflected' do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
          get '/my_health/v1/messaging/recipients', headers: { 'X-Key-Inflection' => 'camel' }
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('triage_teams')
      end
    end
  end

  context 'when legacy sm policy' do
    before do
      Flipper.disable(:mhv_sm_session_policy)
      allow(SM::Client).to receive(:new).and_return(authenticated_client)
    end

    context 'Basic User' do
      let(:mhv_account_type) { 'Basic' }

      before { get '/my_health/v1/messaging/recipients' }

      include_examples 'for user account level', message: 'You do not have access to messaging'
      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    context 'Premium User' do
      let(:mhv_account_type) { 'Premium' }

      context 'not a va patient' do
        before { get '/my_health/v1/messaging/recipients' }

        let(:va_patient) { false }
        let(:current_user) do
          build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
        end

        include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
      end
    end

    describe 'triage teams' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
          get '/my_health/v1/messaging/recipients'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('triage_teams')
      end
    end
  end
end
